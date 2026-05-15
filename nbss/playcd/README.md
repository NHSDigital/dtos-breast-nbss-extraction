# NBSS Cache Export

## Exporting from Cache

In the Cache terminal, switch to the NBSS_DEM namespace:

```ObjectScript
ZN "NBSS_DEM"
```

Then export all classes, routines, and includes:

```ObjectScript
Set localFolder = "<INSERT LOCAL FOLDER>"
Do ##class(%SYSTEM.OBJ).Export("*.cls,*.mac,*.inc,",localFolder_"/all_files_export.xml")
```

NB: use '/' not '\' in filepaths.

## Unpacking

1. Move the exported XML file to `cache_export`
2. Run `python unpack.py`

This splits the large export into individual XML files organised by type (`cls/`, `mac/`, `inc/`).
