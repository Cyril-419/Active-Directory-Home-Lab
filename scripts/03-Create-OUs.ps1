<#
.SYNOPSIS
    Step 3 (run on DC01): build the Organizational Unit (OU) structure.

.DESCRIPTION
    OUs are containers for organizing users, groups and computers. They matter because
    Group Policy is linked to OUs and admin rights can be delegated per OU.

    Resulting structure:
      _HOMELAB
      ├── Users
      │   ├── IT
      │   ├── HR
      │   ├── Finance
      │   └── Sales
      ├── Groups
      ├── Workstations
      ├── Servers
      ├── Service Accounts
      └── Disabled Users

    The leading underscore keeps the lab OU at the top of the list in ADUC.
    Safe to run more than once - existing OUs are skipped.
#>
Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName

function New-OUIfMissing {
    param([string]$Name, [string]$Path)
    $dn = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists : $dn" -ForegroundColor DarkGray
    } else {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "Created: $dn" -ForegroundColor Green
    }
    return $dn
}

$root  = New-OUIfMissing -Name "_HOMELAB" -Path $domainDN
$users = New-OUIfMissing -Name "Users"    -Path $root

foreach ($dept in "IT", "HR", "Finance", "Sales") {
    New-OUIfMissing -Name $dept -Path $users | Out-Null
}
foreach ($ou in "Groups", "Workstations", "Servers", "Service Accounts", "Disabled Users") {
    New-OUIfMissing -Name $ou -Path $root | Out-Null
}

Write-Host "`nOU tree:" -ForegroundColor Cyan
Get-ADOrganizationalUnit -SearchBase $root -Filter * |
    Sort-Object DistinguishedName |
    Select-Object Name, DistinguishedName |
    Format-Table -AutoSize
