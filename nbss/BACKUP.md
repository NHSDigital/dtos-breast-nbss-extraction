# NBSS Caché Back Up

PowerShell script (`create_nbss_back_up.ps1`) to create a timestamped zip backup of NBSS folders and InterSystems Caché database files.

---

## What It Does

1. **Stops** the running InterSystems Caché instance
2. **Creates a zip archive** containing:
   - `NBSS\Attachments` — all contents
   - `NBSS\Letters` — all contents
   - `NBSS\Labels` — all contents
   - All `CACHE.DAT` database files found recursively under `InterSystems\Cache`
   - `InterSystems\Cache\mgr\BACKUP_CACHE.DAT` — the latest backup file only (numbered variants such as `BACKUP_CACHE_1.DAT` are excluded)
3. **Saves the zip** to the same folder the script is run from, named `NBSS_Backup_YYYYMMDD_HHmm.zip`
4. **Restarts** the Caché instance once the zip is complete

---

## Requirements

- Must be run as **Administrator**
- InterSystems Caché must be installed and running before the script is executed

---

## Parameters

| Parameter | Description | Default |
|---|---|---|
| `-NbssRoot` | Root folder where NBSS is installed | `C:\NBSS` |
| `-CacheRoot` | Root folder where InterSystems is installed | `C:\InterSystems` |

---

## Usage

### Run with defaults (both on C:\)

```powershell
.\create_nbss_back_up.ps1
```

### NBSS on D:\ and InterSystems on E:\

```powershell
.\create_nbss_back_up.ps1 -NbssRoot "D:\NBSS" -CacheRoot "E:\InterSystems"
```

### Only NBSS is on a different drive

```powershell
.\create_nbss_back_up.ps1 -NbssRoot "D:\NBSS"
```

### Only InterSystems is on a different drive

```powershell
.\create_nbss_back_up.ps1 -CacheRoot "E:\InterSystems"
```

---

## Output

The zip file is saved alongside the script `NBSS_Backup_20260703_1430.zip`

### Folder structure inside the zip

```directory
Attachments/
    PLAY_CD/
    ...
Letters/
    ASSRR Automatic Recall After Assessment.rpt
    ...
Labels/
    ...
Cache/
    mgr/
        CACHE.DAT
        BACKUP_CACHE.DAT
    mgr/user/
        CACHE.DAT
    mgr/samples/
        CACHE.DAT
    ...
```

---

## Notes

- Caché will be **stopped during the backup** and restarted automatically on completion
- If Caché fails to restart within 60 seconds, the script will throw an error — start Caché manually via the Management Portal or Services if this occurs
- Numbered backup variants (`BACKUP_CACHE_1.DAT`, `BACKUP_CACHE_2.DAT`, etc.) are intentionally excluded — only `BACKUP_CACHE.DAT` is included as it represents the latest backup
- To view the built-in help from PowerShell:

  ```powershell
  Get-Help .\create_nbss_back_up.ps1 -Full
  ```
