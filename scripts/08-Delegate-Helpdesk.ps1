<#
.SYNOPSIS
    Step 8 (run on DC01, optional bonus): delegate password reset + unlock rights
    to the GG_Helpdesk group - without making them Domain Admins.

.DESCRIPTION
    Principle of least privilege: help desk techs need to reset passwords and unlock
    accounts, nothing more. This grants GG_Helpdesk, on all user objects under
    OU=Users,OU=_HOMELAB:
      - "Reset Password" extended right
      - Read/write pwdLastSet  (so they can tick "must change password at next logon")
      - Read/write lockoutTime (so they can unlock accounts)

    Equivalent GUI: ADUC -> right-click OU=Users -> Delegate Control...

    Test it: log in to CLIENT01 as jreyes (a GG_Helpdesk member), install RSAT AD tools
    or use PowerShell, then try to reset a Sales user's password (works) and try to
    delete a user (denied).
#>
Import-Module ActiveDirectory

$domain = Get-ADDomain
$ou     = "OU=Users,OU=_HOMELAB,$($domain.DistinguishedName)"
$group  = "$($domain.NetBIOSName)\GG_Helpdesk"

dsacls $ou /I:S /G "${group}:CA;Reset Password;user"
dsacls $ou /I:S /G "${group}:RPWP;pwdLastSet;user"
dsacls $ou /I:S /G "${group}:RPWP;lockoutTime;user"

Write-Host "`nDelegation applied. Current GG_Helpdesk entries on ${ou}:" -ForegroundColor Cyan
dsacls $ou | Select-String "GG_Helpdesk"
