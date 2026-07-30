# 8. Verify database integrity

After the restore completes, run `run_integrity_check.ps1` to verify the structural integrity of the restored NBSS databases (`dem_app` and `dem_dat`).

This checks that all database blocks are self-consistent and all globals are traversable — confirming the backup wasn't corrupted during transfer or restoration.

## Usage

From `nbss/playcd/poc_backup_restore_pipeline/8_verify_integrity`:

```batch
.\run_integrity_check.bat
```

Or with custom parameters:

```batch
.\run_integrity_check.bat -CacheRoot "E:\InterSystems\CacheRestore" -TimeoutSeconds 900
```

## What happens

- The script calls `Do Silent^Integrity(logfile, dirlist)` in the `%SYS` namespace
- It runs in the background and writes results to `<CacheRoot>\mgr\integ_nbss.txt`
- The script polls the log file until it completes (default timeout: 10 minutes)
- A summary is printed showing totals per directory and whether errors were found

## Interpreting results

The output shows a summary per directory:

```output
---Total for directory C:\NBSS\Cache\dem_app\---
       128 Pointer Level blocks        1024kb (49% full)
    34,608 Data Level blocks            270MB (73% full)
     4,538 Big String blocks             35MB (85% full) # = 1,828
    39,289 Total blocks                 306MB (75% full)
     1,543 Free blocks                   12MB

Elapsed time = 0.6 seconds 07/22/2026 14:37:17

No Errors were found in this directory.
```

Exit codes: `0` = passed, `1` = timeout, `2` = errors found.

## Running interactively

If you need a more detailed check:

```Caché Terminal
ZN "%SYS"
DO ^Integrity
```

Follow the prompts to select the NBSS databases.

## Files

- `run_integrity_check.ps1` — The main PowerShell integrity check script
- `run_integrity_check.bat` — Wrapper batch file (enables running without execution policy issues)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Integrity check timeout | Check log manually at `<CacheRoot>\mgr\integ_nbss.txt` — large databases may take longer |
| Integrity errors found | Do NOT use the database. Re-download the backup zip, verify its hash, and re-run the restore |

## Reference

- [InterSystems: Verifying Structural Integrity](https://docs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_integrity#GCDI_integrity_verify)
