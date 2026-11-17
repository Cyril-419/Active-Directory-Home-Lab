<#
.SYNOPSIS
    Step 5 (run on DC01): bulk-create user accounts from users.csv.

.DESCRIPTION
    For each row in users.csv:
      - Username = first initial + last name, lowercase (e.g. Alex Turner -> aturner)
      - Account goes into OU=<Department>,OU=Users,OU=_HOMELAB
      - Added to its department group (GG_<Department>) plus any ExtraGroups (separated by ;)
      - Must change password at first logon

    You'll be prompted once for the temporary password used for every new account.
    It must meet the domain complexity rules (8+ chars, 3 of: upper, lower, number, symbol).
    Safe to run more than once - existing users are skipped.
#>
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot "users.csv")
)
Import-Module ActiveDirectory

$domain   = Get-ADDomain
$domainDN = $domain.DistinguishedName
$dnsRoot  = $domain.DNSRoot

$tempPassword = Read-Host "Temporary password for all new users" -AsSecureString

foreach ($u in Import-Csv $CsvPath) {
    $sam  = ($u.FirstName.Substring(0,1) + $u.LastName).ToLower()
    $name = "$($u.FirstName) $($u.LastName)"
    $ou   = "OU=$($u.Department),OU=Users,OU=_HOMELAB,$domainDN"

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists : $sam" -ForegroundColor DarkGray
        continue
    }

    New-ADUser `
        -Name $name -DisplayName $name `
        -GivenName $u.FirstName -Surname $u.LastName `
        -SamAccountName $sam -UserPrincipalName "$sam@$dnsRoot" `
        -Title $u.Title -Department $u.Department `
        -Path $ou `
        -AccountPassword $tempPassword `
        -ChangePasswordAtLogon $true `
        -Enabled $true

    $groups = @("GG_$($u.Department)")
    if ($u.ExtraGroups) { $groups += $u.ExtraGroups -split ';' | Where-Object { $_ } }
    foreach ($g in $groups) { Add-ADGroupMember -Identity $g -Members $sam }

    Write-Host ("Created: {0,-10} {1,-18} {2,-8} groups: {3}" -f $sam, $name, $u.Department, ($groups -join ', ')) -ForegroundColor Green
}

Write-Host "`nUsers in lab:" -ForegroundColor Cyan
Get-ADUser -SearchBase "OU=Users,OU=_HOMELAB,$domainDN" -Filter * -Properties Department, Title |
    Sort-Object Department, SamAccountName |
    Select-Object SamAccountName, Name, Department, Title, Enabled |
    Format-Table -AutoSize
