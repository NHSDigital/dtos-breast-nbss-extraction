# 6. Set up a clean Caché DB

## Manual Approach

Using the PlayCD, follow these steps to set up a clean Caché install:

- Open PlayCD zip and open the `Cache` folder
- Run installer (cache-2018.1.4.505.1-win_x64.exe)
- Select 'Install New Instance'
- Name = CACHERESTORE (this can be whatever you want as long as it doesn't match the name of any existing Caché install)
- Install Folder = C:\InterSystems\CacheRestore\
- Click through remaining windows using the default options
- Once installed Cache services are available here: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Caché\CACHERESTORE

Note: Cache allows multiple installs on the same machine (and same drive). Once the service is running, the preferred Cache instance can be selected from the system tray (cube icon) in Windows.

## Using a Script

A PowerShell script is provided to automate the Caché installation silently — no manual clicking through the installer UI.

### Step 1 — Extract the Caché installer

The installer `.exe` must be extracted from the PlayCD zip before it can be run:

```powershell
Expand-Archive "<path-to-zip-file>" -DestinationPath "C:\Temp\CacheInstaller"
```

The installer will be at `C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe`.

### Step 2 — Run the silent install script

From `nbss/playcd/poc_backup_restore_pipeline/6_setup_clean_cache`:

```powershell
.\install_cache_silent.bat -InstallerPath "C:\Temp\CacheInstaller\Setup\cache setup\cache-2018.1.4.505.1-win_x64.exe"
```

- The installer also starts the Caché instance.
- Once installed Cache services are available here: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Caché\CACHERESTORE

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-InstallerPath` | *(required)* | Path to the extracted `cache-2018.1.4.505.1-win_x64.exe` |
| `-InstallDir` | `C:\InterSystems\CacheRestore` | Target installation directory |
| `-InstanceName` | `CACHERESTORE` | Name for the new Caché instance |
| `-SuperServerPort` | `1973` | TCP port for Caché SuperServer |
| `-WebServerPort` | `57773` | TCP port for Caché private web server |

### Port conflicts

The script checks that the SuperServer and Web Server ports are free before installing. If your existing NBSS instance is already using a port, the script will fail with an error message telling you which process holds the port and suggesting an alternative:

```batch
.\install_cache_silent.bat -InstallerPath "..." -SuperServerPort 1974 -WebServerPort 57774
```

The default NBSS instance typically uses ports 1972/57772, so the defaults (1973/57773) should not conflict even with an existing NBSS/Caché install.

### Files

- `install_cache_silent.ps1` — The main PowerShell script (handles install and port checks)
- `install_cache_silent.bat` — Wrapper batch file (enables running without execution policy issues)
