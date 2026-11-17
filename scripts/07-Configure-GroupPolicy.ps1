<#
.SYNOPSIS
    Step 7 (run on DC01): set the domain lockout policy and push out three GPOs.

.DESCRIPTION
    1. Account lockout policy (domain-wide)
       By default a new domain has NO lockout threshold, so accounts never lock out
       and there's nothing to practice unlocking. This sets: lock after 5 bad
       passwords, stay locked 15 minutes, counter resets after 15 minutes.

    2. GPO "USR - Screen Lock 10 Min"       -> linked to OU=Users
       Locks idle sessions after 10 minutes and requires a password to unlock.

    3. GPO "USR - Block Control Panel"      -> linked to OU=Sales only
       Shows GPO scoping: Sales users lose Control Panel/Settings, IT users don't.

    4. GPO "CMP - Logon Legal Banner"       -> linked to OU=Workstations
       Computer policy that shows an authorized-use warning before sign-in
       (a common compliance control).

    Verify on the client with:  gpupdate /force   then   gpresult /r
#>
param(
    [int]$LockoutThreshold = 5,
    [timespan]$LockoutDuration = "00:15:00"
)
Import-Module ActiveDirectory
Import-Module GroupPolicy

$domain   = Get-ADDomain
$domainDN = $domain.DistinguishedName
$labRoot  = "OU=_HOMELAB,$domainDN"

# --- 1. Account lockout policy -------------------------------------------------
Set-ADDefaultDomainPasswordPolicy -Identity $domain.DNSRoot `
    -LockoutThreshold $LockoutThreshold `
    -LockoutDuration $LockoutDuration `
    -LockoutObservationWindow $LockoutDuration
Write-Host "Lockout policy set:" -ForegroundColor Green
Get-ADDefaultDomainPasswordPolicy | Select-Object LockoutThreshold, LockoutDuration, LockoutObservationWindow, MinPasswordLength, ComplexityEnabled | Format-List

function New-LinkedGPO {
    param([string]$Name, [string]$Comment, [string]$Target)
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $Name -Comment $Comment
        Write-Host "Created GPO: $Name" -ForegroundColor Green
    }
    if (-not ((Get-GPInheritance -Target $Target).GpoLinks | Where-Object DisplayName -eq $Name)) {
        New-GPLink -Name $Name -Target $Target -LinkEnabled Yes | Out-Null
        Write-Host "  Linked to: $Target" -ForegroundColor Green
    }
    return $gpo
}

# --- 2. Screen lock after 10 minutes (User Configuration) ---------------------
$name = "USR - Screen Lock 10 Min"
New-LinkedGPO -Name $name -Comment "Lock idle sessions after 10 min" -Target "OU=Users,$labRoot" | Out-Null
$key = "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
Set-GPRegistryValue -Name $name -Key $key -ValueName "ScreenSaveActive"    -Type String -Value "1"   | Out-Null
Set-GPRegistryValue -Name $name -Key $key -ValueName "ScreenSaverIsSecure" -Type String -Value "1"   | Out-Null
Set-GPRegistryValue -Name $name -Key $key -ValueName "ScreenSaveTimeOut"   -Type String -Value "600" | Out-Null

# --- 3. Block Control Panel for Sales only (User Configuration) ---------------
$name = "USR - Block Control Panel"
New-LinkedGPO -Name $name -Comment "Prohibit access to Control Panel and PC settings" -Target "OU=Sales,OU=Users,$labRoot" | Out-Null
Set-GPRegistryValue -Name $name `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoControlPanel" -Type DWord -Value 1 | Out-Null

# --- 4. Logon legal banner (Computer Configuration) ---------------------------
$name = "CMP - Logon Legal Banner"
New-LinkedGPO -Name $name -Comment "Authorized-use notice before sign-in" -Target "OU=Workstations,$labRoot" | Out-Null
$key = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-GPRegistryValue -Name $name -Key $key -ValueName "legalnoticecaption" -Type String -Value "Authorized Use Only" | Out-Null
Set-GPRegistryValue -Name $name -Key $key -ValueName "legalnoticetext"    -Type String `
    -Value "This system is for authorized HOMELAB users only. Activity may be monitored and logged." | Out-Null

Write-Host "`nGPOs in domain:" -ForegroundColor Cyan
Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime | Format-Table -AutoSize
