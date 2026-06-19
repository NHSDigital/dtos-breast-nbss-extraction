[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$NewUsername,
    [Parameter(Mandatory)][string]$NewPassword,
    [string]$CacheInstance = "CACHE",
    [string]$AdminUser     = "_SYSTEM",
    [Parameter(Mandatory)][string]$AdminPassword,
    [string]$CsessionPath  = "C:\InterSystems\Cache\bin\csession.exe"
)

# csession does not support -P for password.
# We pipe the username and password as interactive input, followed by the COS commands.
$script = @"
$AdminUser
$AdminPassword
ZN ""%SYS""
SET sc = ##class(Security.Users).Create("$NewUsername","%SYS","$NewPassword")
WRITE `$SYSTEM.Status.GetErrorText(sc),!
SET sc = ##class(Security.Users).AddRoles("$NewUsername","%All")
WRITE `$SYSTEM.Status.GetErrorText(sc),!
SET sc = ##class(Security.Users).AddRoles("$NewUsername","%DB_NBSS_DEM")
WRITE `$SYSTEM.Status.GetErrorText(sc),!
SET sc = ##class(Security.Users).AddRoles("$NewUsername","NBSSapp")
WRITE `$SYSTEM.Status.GetErrorText(sc),!
SET sc = ##class(Security.Users).AddRoles("$NewUsername","BSSReporting")
WRITE `$SYSTEM.Status.GetErrorText(sc),!
DO ##class(Security.Users).Get("$NewUsername",.props)
WRITE "Roles: ",props("Roles"),!
WRITE "Enabled: ",props("Enabled"),!
HALT
"@

$script | & $CsessionPath $CacheInstance -U "%SYS"
