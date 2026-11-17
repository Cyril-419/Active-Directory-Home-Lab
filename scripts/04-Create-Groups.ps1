<#
.SYNOPSIS
    Step 4 (run on DC01): create security groups.

.DESCRIPTION
    Permissions should be granted to groups, not to individual users. When someone
    changes departments you move them between groups instead of re-doing permissions.

    Naming: GG_ = Global security Group.
      GG_IT, GG_HR, GG_Finance, GG_Sales  - one per department
      GG_Helpdesk                          - tier-1 support staff (used for delegation in step 8)

    Safe to run more than once.
#>
Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName
$groupOU  = "OU=Groups,OU=_HOMELAB,$domainDN"

$groups = @(
    @{ Name = "GG_IT";       Description = "All IT department staff" },
    @{ Name = "GG_HR";       Description = "All HR department staff" },
    @{ Name = "GG_Finance";  Description = "All Finance department staff" },
    @{ Name = "GG_Sales";    Description = "All Sales department staff" },
    @{ Name = "GG_Helpdesk"; Description = "Tier-1 help desk - can unlock accounts and reset passwords" }
)

foreach ($g in $groups) {
    if (Get-ADGroup -Filter "Name -eq '$($g.Name)'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists : $($g.Name)" -ForegroundColor DarkGray
        continue
    }
    New-ADGroup -Name $g.Name -SamAccountName $g.Name `
        -GroupCategory Security -GroupScope Global `
        -Path $groupOU -Description $g.Description
    Write-Host "Created: $($g.Name)" -ForegroundColor Green
}

Get-ADGroup -SearchBase $groupOU -Filter * | Select-Object Name, GroupScope, GroupCategory | Format-Table -AutoSize
