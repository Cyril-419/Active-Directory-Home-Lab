<#
.SYNOPSIS
    Step 2 (run on DC01): install Active Directory Domain Services and promote the server
    to the first domain controller of a new forest.

.DESCRIPTION
    - Installs the AD DS role plus management tools (ADUC, GPMC, AD PowerShell module)
    - Creates a new forest/domain and installs DNS on the same server
    - Prompts for the DSRM (Directory Services Restore Mode) password - store it safely,
      it is the break-glass password for recovering AD
    - The server reboots automatically when promotion finishes. Afterwards, log in as
      HOMELAB\Administrator (same password as the local Administrator had).
#>
param(
    [string]$DomainName  = "homelab.local",
    [string]$NetbiosName = "HOMELAB"
)

Write-Host "Installing AD DS role..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$dsrm = Read-Host "Enter a DSRM (Safe Mode) password" -AsSecureString

Write-Host "Promoting to domain controller for $DomainName ..." -ForegroundColor Cyan
Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -InstallDns `
    -SafeModeAdministratorPassword $dsrm `
    -Force
# Server reboots automatically
