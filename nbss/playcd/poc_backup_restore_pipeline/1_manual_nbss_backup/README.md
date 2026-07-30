## 1. Manual NBSS backup

This section describes how to manually trigger a backup via the Caché Terminal. This should be run if the overnight backup has not completed before taking the [NBSS Zip Back Up](../2_zip_backup_files/README.md).

Open the Caché Terminal and run:

```Caché Terminal
ZN "%SYS"
DO ^BACKUP
```

The following menu will appear:

```OUTPUT
1) Backup
2) Restore ALL
3) Restore Selected or Renamed Directories
4) Edit/Display List of Directories for Backups
5) Abort Backup
6) Display Backup volume information
7) Monitor progress of backup or restore
```

Select `1`.

```OUTPUT
                 Cache Backup Utility
              --------------------------
What kind of backup:
   1. Full backup of all in-use blocks
   2. Incremental since last backup
   3. Cumulative incremental since last full backup
   4. Exit the backup program
1 =>
```

Select `1` — a full backup is currently used to capture everything.

```OUTPUT
Specify output device (type STOP to exit)
Device: c:\intersystems\cache\mgr\n =>
```

Type `BACKUP_CACHE.DAT`.

```OUTPUT
File exists, do you want to overwrite it <N>?Y
Backing up to device: c:\intersystems\cache\mgr\BACKUP_CACHE.DAT
Description:
```

Follow the remaining prompts as shown and the backup will commence.

```OUTPUT
Backing up the following directories:
 c:\intersystems\cache\mgr\
 c:\intersystems\cache\mgr\cache\
 c:\intersystems\cache\mgr\cacheaudit\
 c:\intersystems\cache\mgr\user\
 c:\nbss\cache\dem_app\
 c:\nbss\cache\dem_dat\

Start the Backup (y/n)? =>
```

Select `y` and the backup process will begin.
