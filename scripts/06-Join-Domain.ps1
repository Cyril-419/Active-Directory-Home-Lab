<#
.SYNOPSIS
    Step 6 (run on the Windows 10/11 CLIENT VM): point DNS at the DC and join the domain.

.DESCRIPTION
    Domain join fails most often because of DNS: the client has to find the domain
    controller through DNS SRV records, so its DNS server MUST be the DC's IP.

    This script:
      1. Sets the client's DNS server to the DC
      2. Verifies the domain name resolves
      3. Joins the domain, renames the PC, and places it directly into the
         Workstations OU (so workstation GPOs apply), then reboots

.NOTES
    Windows 10/11 HOME cannot join a domain - use Pro, Enterprise or Education
    (the free Windows 11 Enterprise evaluation ISO works).
    Run in an elevated PowerShell window. You'll be prompted for HOMELAB\Administrator.
#>
param(
    [string]$DCIPAddress = "10.0.2.10",
    [string]$DomainName  = "homelab.local",
    [string]$NewName     = "CLIENT01"
)

$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DCIPAddress
Clear-DnsClientCache

Write-Host "Testing DNS resolution of $DomainName ..." -ForegroundColor Cyan
try {
    Resolve-DnsName $DomainName -ErrorAction Stop | Format-Table -AutoSize
} catch {
    throw "Cannot resolve $DomainName. Check that the DC is on and that both VMs are on the same network."
}

$domainDN = ($DomainName.Split('.') | ForEach-Object { "DC=$_" }) -join ','
$ouPath   = "OU=Workstations,OU=_HOMELAB,$domainDN"
$netbios  = $DomainName.Split('.')[0].ToUpper()

Add-Computer -DomainName $DomainName `
    -NewName $NewName `
    -OUPath $ouPath `
    -Credential (Get-Credential "$netbios\Administrator") `
    -Restart
