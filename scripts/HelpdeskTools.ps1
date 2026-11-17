<#
.SYNOPSIS
    Everyday tier-1 help desk functions for Active Directory.

.DESCRIPTION
    Load the functions into your session (dot-source), then call them:

        . .\HelpdeskTools.ps1
        Get-LockedUsers
        Get-UserStatus  -Username pkim
        Unlock-User     -Username pkim
        Reset-UserPassword -Username pkim
        Disable-DepartedUser -Username rmitchell

    Every action is appended to helpdesk-actions.log next to this script, the way a
    real ticket would record who did what and when.
#>
Import-Module ActiveDirectory

$script:LogFile = Join-Path $PSScriptRoot "helpdesk-actions.log"

function Write-ActionLog {
    param([string]$Message)
    $line = "{0}  {1}  {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $env:USERNAME, $Message
    Add-Content -Path $script:LogFile -Value $line
    Write-Host $line -ForegroundColor Green
}

function Get-LockedUsers {
    <# Lists every locked-out account in the domain. #>
    Search-ADAccount -LockedOut -UsersOnly |
        Get-ADUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt, Department |
        Select-Object SamAccountName, Name, Department, BadLogonCount, LastBadPasswordAttempt |
        Format-Table -AutoSize
}

function Get-UserStatus {
    <# First thing to check on any "I can't log in" ticket. #>
    param([Parameter(Mandatory)][string]$Username)
    Get-ADUser $Username -Properties Enabled, LockedOut, BadLogonCount, LastBadPasswordAttempt,
        PasswordLastSet, PasswordExpired, LastLogonDate, Department, Title, MemberOf |
        Select-Object SamAccountName, Name, Department, Title, Enabled, LockedOut, BadLogonCount,
            LastBadPasswordAttempt, PasswordLastSet, PasswordExpired, LastLogonDate,
            @{ n = 'Groups'; e = { ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace 'CN=' }) -join ', ' } }
}

function Unlock-User {
    param([Parameter(Mandatory)][string]$Username)
    $u = Get-ADUser $Username -Properties LockedOut
    if (-not $u.LockedOut) { Write-Host "$Username is not locked out." -ForegroundColor Yellow; return }
    Unlock-ADAccount -Identity $Username
    Write-ActionLog "UNLOCK   $Username"
}

function Reset-UserPassword {
    <# Resets to a temporary password and forces a change at next logon. Verify the caller's identity first! #>
    param([Parameter(Mandatory)][string]$Username)
    $newPw = Read-Host "New temporary password for $Username" -AsSecureString
    Set-ADAccountPassword -Identity $Username -Reset -NewPassword $newPw
    Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
    if ((Get-ADUser $Username -Properties LockedOut).LockedOut) { Unlock-ADAccount -Identity $Username }
    Write-ActionLog "PWRESET  $Username (must change at next logon)"
}

function Disable-DepartedUser {
    <# Offboarding: disable, strip group memberships, move to Disabled Users OU. #>
    param([Parameter(Mandatory)][string]$Username)
    $domainDN = (Get-ADDomain).DistinguishedName
    $user = Get-ADUser $Username -Properties MemberOf
    Disable-ADAccount -Identity $Username
    foreach ($g in $user.MemberOf) { Remove-ADGroupMember -Identity $g -Members $Username -Confirm:$false }
    Set-ADUser -Identity $Username -Description "Disabled $(Get-Date -Format yyyy-MM-dd) - offboarded"
    Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=Disabled Users,OU=_HOMELAB,$domainDN"
    Write-ActionLog "OFFBOARD $Username (disabled, removed from $($user.MemberOf.Count) groups, moved to Disabled Users)"
}
