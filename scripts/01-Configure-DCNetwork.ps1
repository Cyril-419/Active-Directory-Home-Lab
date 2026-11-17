<#
.SYNOPSIS
    Step 1 (run on the server VM): give the future domain controller a static IP and a proper name.

.DESCRIPTION
    A domain controller needs a static IP address because every domain-joined machine
    points its DNS at it. This script:
      1. Disables DHCP on the active network adapter
      2. Assigns a static IPv4 address, subnet and default gateway
      3. Points DNS at itself (127.0.0.1) - AD DS will install the DNS role in step 2
      4. Renames the computer and reboots

.NOTES
    Run in an elevated PowerShell window on the Windows Server VM.
    Defaults match a VirtualBox "NAT Network" using 10.0.2.0/24.
#>
param(
    [string]$ComputerName = "DC01",
    [string]$IPAddress    = "10.0.2.10",
    [int]   $PrefixLength = 24,
    [string]$Gateway      = "10.0.2.1"
)

$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not $adapter) { throw "No active network adapter found." }
$idx = $adapter.ifIndex
Write-Host "Configuring adapter '$($adapter.Name)' (ifIndex $idx)" -ForegroundColor Cyan

# Clear the DHCP-assigned address and route so the static ones can be added cleanly
Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled
Remove-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute     -InterfaceIndex $idx -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceIndex $idx -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses 127.0.0.1

Get-NetIPConfiguration -InterfaceIndex $idx

Write-Host "Renaming computer to $ComputerName and restarting..." -ForegroundColor Yellow
Rename-Computer -NewName $ComputerName -Restart
