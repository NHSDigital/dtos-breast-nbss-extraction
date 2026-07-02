# Creating a Caché User

Three options are available depending on your preference:

- [Option 1 — PowerShell script (recommended)](#option-1--powershell-script-recommended)
- [Option 2 — Caché Terminal](#option-2--caché-terminal)
- [Option 3 — Management Portal](#option-3--management-portal-only-backend-user)

## Prerequisites

For all options:

- Caché must be running
- You must know the admin username and password

---

## Option 1 — PowerShell script (recommended)

---

A PowerShell script is provided to create a user in one command without opening a terminal session.

### Step 1 — Execute the PowerShell script

From the repo root in PowerShell:

```powershell
    .\nbss\playcd\new_cache_user.ps1`
        -NewUsername "<username>" `
        -NewPassword "<password>" `
        -AdminUser "<admin_username>" `
        -AdminPassword "<admin_password>"
```

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-NewUsername` | Yes | — | Username to create |
| `-NewPassword` | Yes | — | Password for the new user |
| `-AdminPassword` | Yes | — | Password for the account specified by `-AdminUser` |
| `-CacheInstance` | No | `CACHE` | Caché instance name |
| `-AdminUser` | No | `_SYSTEM` | Admin account to authenticate with |
| `-CsessionPath` | No | `C:\InterSystems\Cache\bin\csession.exe` | Path to csession.exe |

---

### Step 2 — Reset Frontend password

You need to open NBSS Test. A box will appear where you enter `<username>` and for the password enter `PASSWORD` as the default. You will be requested to create a new password.

---

## Option 2 — Caché Terminal

---

## Step 1 — Open a Caché terminal session

In the Caché Terminal, you might be prompted for credentials (use a user with admin privileges).

---

## Step 2 — Create the user (Backend User)

Replace `username` and `password` before running this command in the terminal.

```Caché Terminal
    ZN "%SYS"
    SET sc = ##class(Security.Users).Create("<username>","%SYS","<password>")
    WRITE $SYSTEM.Status.GetErrorText(sc),!
    SET sc = ##class(Security.Users).AddRoles("<username>","%All")
    DO ##class(Security.Users).Get("<username>",.props)
    WRITE "Roles: ",props("Roles"),!
    WRITE "Enabled: ",props("Enabled"),!
```

---

## Step 3 — Create the user (Frontend User)

Replace `username` (the username from Step 1) before running this command in the terminal.

```Caché Terminal
    ZN "NBSS_DEM"
    SET obj = ##class(UTIL.Users).%New()
    SET obj.UserId = "<username>"
    SET obj.UserForename = "NBSS"
    SET obj.UserSurname = "Extraction"
    SET obj.UserGroupId             = "SOM"
    SET obj.UserSystemManager       = 1
    SET obj.UserDisabled            = 0
    SET obj.UserForcePasswordChange = 1
    SET obj.ResetPassword           = 1
    SET sc = obj.%Save()
    WRITE $SYSTEM.Status.GetErrorText(sc),!
```

## Step 4 — Reset Frontend password

You need to open NBSS Test. A box will appear where you enter `<username>` and for the password enter `PASSWORD` as the default. You will be requested to create a new password.

---

## Option 3 — Management Portal (Only Backend User)

### Step 1 — Open the Management Portal

Open the Management Portal

Log in with an existing admin account.

---

### Step 2 — Navigate to Users

Go to: **System Administration → Security → Users**

Click **Create New User**.

---

### Step 3 — Fill in user details

| Field | Value |
|-------|-------|
| **Name** | Enter the username |
| **Password** | Enter a strong password |
| **Confirm Password** | Re-enter the password |
| **Enabled** | Tick the checkbox |

---

### Step 4 — Grant admin privileges

On the same page, scroll to the **Roles** section and click **Add**:

- Type `%All` and click **Assign** — this grants full system admin access

To also grant access to specific databases/applications, add any of:

| Role | Access granted | Required |
|------|---------------|---------|
| `%All` | Full system admin | 1 |
| `%DB_..._` | database | 0 |
| `NBSSapp` | NBSS application | 0 |
| `BSSReporting` | BSS reporting | 0 |

---

### Step 5 — Save

Click **Save** at the bottom of the page.

You will be returned to the Users list where the new user will appear.

---

### Step 6 — Verify

Click the username in the list and confirm:

- **Enabled** is ticked
- **Roles** shows the roles you assigned

---

## Notes

- Always connect to `%SYS` namespace for user/security management
- The `%All` role grants full access including `%SYS` — only assign to trusted admin users
- `%DB_NBSS_DEM` is auto-generated when the NBSS_DEM database is created
