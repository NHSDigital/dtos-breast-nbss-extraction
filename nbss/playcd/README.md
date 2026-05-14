# NBSS Cache Export

## Exporting from Cache

In the Cache terminal, switch to the NBSS_DEM namespace:

```ObjectScript
ZN "NBSS_DEM"
```

Then export all classes, routines, and includes:

```ObjectScript
Do ##class(%SYSTEM.OBJ).Export("*.cls,*.mac,*.inc,","<INSERT LOCAL FOLDER>/all_files_export.xml")
```

## Unpacking

1. Move the exported XML file to `cache_export/all_files_export.xml`
2. Run `python unpack.py`

This splits the large export into individual XML files organised by type (`cls/`, `mac/`, `inc/`).
