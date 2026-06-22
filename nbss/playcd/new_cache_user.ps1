.DESCRIPTION
Creates a new user in both the Caché backend (%SYS) and the NBSS frontend application (NBSS_DEM).
    Step 1 — Registers the user as a Caché system user in %SYS with the roles needed
             to connect to the NBSS_DEM database.
    Step 2 — Creates the corresponding NBSS application user in the UTIL.Users table
             so the user can log in to the NBSS frontend. On first login, NBSS will
             prompt the user to set a new password.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$NewUsername,
    [Parameter(Mandatory)][string]$NewPassword,
    [string]$CacheInstance = "CACHE",
    [string]$AdminUser     = "_SYSTEM",
    [Parameter(Mandatory)][string]$AdminPassword,
    [string]$CsessionPath  = "C:\InterSystems\Cache\bin\csession.exe"
)

# Step 1
# csession does not support -P for password.
# We pipe the username and password as interactive input, followed by the COS commands.
$sysScript = @"
$AdminUser
$AdminPassword
ZN ""%SYS""
SET sc = ##class(Security.Users).Create("$NewUsername","%SYS","$NewPassword")
WRITE `$SYSTEM.Status.GetErrorText(sc),!
SET sc = ##class(Security.Users).AddRoles("$NewUsername","%All")
DO ##class(Security.Users).Get("$NewUsername",.props)
WRITE "Roles: ",props("Roles"),!
WRITE "Enabled: ",props("Enabled"),!
HALT
"@

Write-Host "--- Creating Cache system user in %SYS ---"
$sysScript | & $CsessionPath $CacheInstance -U "%SYS"


# Step 2
$nbssScript = @"
$AdminUser
$AdminPassword
ZN "NBSS_DEM"
SET obj = ##class(UTIL.Users).%New()
SET obj.UserId = "$NewUsername"
SET obj.UserForename = "NBSS"
SET obj.UserSurname = "Extraction"
SET obj.UserGroupId             = "SOM"
SET obj.UserSystemManager       = 1
SET obj.UserDisabled            = 0
SET obj.UserForcePasswordChange = 1
SET obj.ResetPassword           = 1
SET sc = obj.%Save()
WRITE `$SYSTEM.Status.GetErrorText(sc),!
HALT
"@

Write-Host "--- Creating NBSS application user in NBSS_DEM ---"
$nbssScript | & $CsessionPath $CacheInstance -U "NBSS_DEM"
