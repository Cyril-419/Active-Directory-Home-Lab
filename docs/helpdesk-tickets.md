# Help Desk Ticket Scenarios

Practice tickets worked in the lab, written the way they'd be documented in a ticketing system.
Load the tools first on DC01:

```powershell
cd C:\Lab\scripts
. .\HelpdeskTools.ps1
```

---

## TKT-1001 — "I'm locked out of my computer"

**User:** Parker Kim (`pkim`), Sales
**Setup:** On CLIENT01, sign in as `HOMELAB\pkim` with the wrong password 5 times.

**Troubleshooting**
1. Verified the caller's identity (name, department, manager).
2. Checked the account:
   ```powershell
   Get-UserStatus -Username pkim     # LockedOut : True, BadLogonCount : 5
   Get-LockedUsers
   ```
3. Confirmed the account was locked by the domain lockout policy (5 attempts / 15 min), not disabled.

**Resolution**
```powershell
Unlock-User -Username pkim
```
GUI: ADUC → find user → Properties → **Account** tab → tick *Unlock account*.

User signed in successfully. Reminded them the lockout clears itself after 15 minutes.

---

## TKT-1002 — "I forgot my password"

**User:** Avery Collins (`acollins`), Finance

**Troubleshooting**
1. Verified identity **before** resetting — never reset a password for an unverified caller (social engineering risk).
2. Checked `Get-UserStatus -Username acollins` — account enabled, not expired.

**Resolution**
```powershell
Reset-UserPassword -Username acollins
```
GUI: ADUC → right-click user → **Reset Password…** → tick *User must change password at next logon*.

Gave the user the temporary password over a verified channel; they set their own password at sign-in.

---

## TKT-1003 — "Control Panel won't open"

**User:** Rowan Mitchell (`rmitchell`), Sales

**Troubleshooting**
1. On CLIENT01 as `rmitchell`: `gpresult /r` → *Applied Group Policy Objects* lists `USR - Block Control Panel`.
2. Confirmed in GPMC that the GPO is linked to `_HOMELAB\Users\Sales` — working as designed.

**Resolution**
Explained the restriction is company policy for Sales workstations. Escalated the request to the manager for approval if access is truly needed. **No change made** — not every ticket is a fix.

---

## TKT-1004 — New hire

**Request:** HR asks for an account for a new Sales Representative, *Sam Lee*, starting Monday.

**Resolution**
1. Added a row to `users.csv`: `Sam,Lee,Sales,Sales Representative,`
2. Ran `.\05-Create-Users.ps1` → created `slee` in `Users\Sales`, added to `GG_Sales`, must change password at first logon.
3. Signed in on CLIENT01 as `slee` to confirm the logon banner, password change prompt, and Sales GPOs all applied.

---

## TKT-1005 — Employee offboarding

**Request:** HR reports Rowan Mitchell (`rmitchell`) left the company today.

**Resolution**
```powershell
Disable-DepartedUser -Username rmitchell
```
- Account disabled (not deleted — kept for audit/records)
- Removed from all groups
- Description stamped with the date
- Moved to `_HOMELAB\Disabled Users`

Verified the user can no longer sign in on CLIENT01.

---

## TKT-1006 — Least privilege check

**Request:** Help desk tech Jordan Reyes (`jreyes`) needs to reset passwords without being a Domain Admin.

**Resolution**
1. Ran `.\08-Delegate-Helpdesk.ps1` — grants `GG_Helpdesk` *Reset Password*, *pwdLastSet* and *lockoutTime* on `Users` OU only.
2. Tested as `jreyes`:
   - Reset a Sales user's password → ✅ allowed
   - Delete a user / create an OU → ❌ access denied

---

## Action log

All tool actions are written to `scripts/helpdesk-actions.log`, e.g.:

```
2026-11-17 10:42:13  Administrator  UNLOCK   pkim
2026-11-17 10:48:55  Administrator  PWRESET  acollins (must change at next logon)
2026-11-17 11:05:20  Administrator  OFFBOARD rmitchell (disabled, removed from 1 groups, moved to Disabled Users)
```
