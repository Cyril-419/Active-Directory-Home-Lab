# Lab Guide — Step by Step

Approx. time: 3–5 hours (most of it is Windows installing).

## What you need

| Item | Notes |
|---|---|
| Host PC | 16 GB RAM recommended (8 GB minimum), ~100 GB free disk, virtualization enabled in BIOS |
| [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads) | Free. Hyper-V also works. |
| Windows Server 2022 or 2025 evaluation ISO | Free 180-day eval — Microsoft Evaluation Center |
| Windows 11 Enterprise evaluation ISO | Free 90-day eval. **Home edition can't join a domain.** |

---

## Step 0 — Build the VMs

1. **VirtualBox → File → Tools → Network Manager → NAT Networks → Create**
   - Name `ADLab`, IPv4 prefix `10.0.2.0/24`, DHCP **on**
2. **DC01 VM:** Windows Server 2022, 2 CPU, 4096 MB RAM, 50 GB disk, Network: *NAT Network → ADLab*
   - Install choosing **Standard Evaluation (Desktop Experience)** — otherwise you get no GUI.
   - Set a local Administrator password.
3. **CLIENT01 VM:** Windows 11, 2 CPU, 4096 MB RAM, 64 GB disk, TPM 2.0 + EFI/Secure Boot on, Network: *NAT Network → ADLab*
   - During setup, choose **"Sign-in options → Domain join instead"** (or "I don't have internet") to create a local account.
4. Install **Guest Additions** on both (Devices → Insert Guest Additions CD) for clipboard + resizing.
5. Copy the `scripts` folder to `C:\Lab\scripts` on both VMs (shared folder or drag-and-drop).

📸 *Screenshot: both VMs in VirtualBox Manager*

> Script execution is blocked by default. In an **elevated** PowerShell on each VM:
> `Set-ExecutionPolicy -Scope Process Bypass`

---

## Step 1 — Static IP & rename (DC01)

```powershell
.\01-Configure-DCNetwork.ps1
```
**GUI way:** `ncpa.cpl` → adapter → IPv4 → IP `10.0.2.10`, mask `255.255.255.0`, gateway `10.0.2.1`, DNS `127.0.0.1`. Then Settings → System → About → *Rename this PC* → `DC01`.

✅ Check: `ipconfig /all` shows 10.0.2.10, hostname is DC01.

---

## Step 2 — Install AD DS and promote (DC01)

```powershell
.\02-Install-ADDS.ps1
```
**GUI way:** Server Manager → *Add roles and features* → **Active Directory Domain Services** → finish → flag icon → *Promote this server to a domain controller* → **Add a new forest** → `homelab.local` → set DSRM password → Next through → Install.

Server reboots. Log in as **HOMELAB\Administrator**.

✅ Check:
```powershell
Get-ADDomain | Select DNSRoot, NetBIOSName, PDCEmulator
Get-Service adws, kdc, netlogon, dns | Select Name, Status
```
📸 *Screenshot: Server Manager dashboard showing AD DS and DNS*

---

## Step 3–5 — OUs, groups, users (DC01)

```powershell
.\03-Create-OUs.ps1
.\04-Create-Groups.ps1
.\05-Create-Users.ps1
```
**GUI way (do at least one of each by hand!):** `dsa.msc` (Active Directory Users and Computers)
- Right-click domain → New → **Organizational Unit**
- Right-click `Groups` OU → New → **Group** (Global, Security)
- Right-click a department OU → New → **User** → set password, tick *must change at next logon*
- User Properties → **Member Of** → Add group

✅ Check: ADUC shows the `_HOMELAB` tree with 12 users.
📸 *Screenshot: ADUC with OU tree expanded*

---

## Step 6 — Join CLIENT01 to the domain (CLIENT01)

```powershell
.\06-Join-Domain.ps1
```
**GUI way:**
1. `ncpa.cpl` → adapter → IPv4 → *Use the following DNS server* → `10.0.2.10`
2. `nslookup homelab.local` — must return 10.0.2.10
3. `sysdm.cpl` → **Change…** → Member of **Domain**: `homelab.local` → enter `HOMELAB\Administrator` → reboot
4. On DC01, in ADUC, drag `CLIENT01` from `Computers` into `_HOMELAB\Workstations` (the script does this for you).

At the sign-in screen choose **Other user** and log in as `HOMELAB\pkim` (temp password → forced to change).

✅ Check: `whoami` → `homelab\pkim`; `systeminfo | findstr Domain`
📸 *Screenshot: System → About showing domain homelab.local*

---

## Step 7 — Group Policy (DC01)

```powershell
.\07-Configure-GroupPolicy.ps1
```
**GUI way:** `gpmc.msc`
- **Lockout:** Default Domain Policy → Edit → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → **Account Lockout Policy** → threshold 5, duration 15
- **New GPO:** right-click the `Sales` OU → *Create a GPO in this domain, and Link it here…* → Edit → User Configuration → Policies → Administrative Templates → Control Panel → **Prohibit access to Control Panel and PC settings** → Enabled

On CLIENT01:
```cmd
gpupdate /force
gpresult /r
```
Sign in as `pkim` (Sales) — Control Panel blocked. Sign in as `aturner` (IT) — works. That's GPO scoping.

📸 *Screenshots: GPMC with linked GPOs; `gpresult /r` output; logon banner at boot*

---

## Step 8 — Help desk practice

Work through **[helpdesk-tickets.md](helpdesk-tickets.md)**. Do each ticket **in the GUI first**, then with `HelpdeskTools.ps1` — interviewers ask about ADUC, real tickets get closed faster in PowerShell.

---

## Useful commands cheat sheet

| Task | Command |
|---|---|
| Find locked users | `Search-ADAccount -LockedOut` |
| Unlock | `Unlock-ADAccount pkim` |
| Reset password | `Set-ADAccountPassword pkim -Reset -NewPassword (Read-Host -AsSecureString)` |
| Force change at logon | `Set-ADUser pkim -ChangePasswordAtLogon $true` |
| Disable | `Disable-ADAccount pkim` |
| Group members | `Get-ADGroupMember GG_Sales` |
| User's groups | `Get-ADPrincipalGroupMembership pkim \| Select Name` |
| Refresh policy (client) | `gpupdate /force` |
| Applied policy (client) | `gpresult /r` or `gpresult /h report.html` |
| Test DC connectivity (client) | `nltest /dsgetdc:homelab.local` |
| Verify trust (client) | `Test-ComputerSecureChannel` |
