# Game files

Put the files of your own **USA** copy of **Guitar Hero: World Tour (Xbox 360)** here, so that this file exists:

```
assets/default.xex
```

The whole disc content goes in this folder. Extract it from your disc or ISO with
[extract-xiso](https://github.com/XboxDev/extract-xiso/releases):

```powershell
extract-xiso.exe -x -d assets "Guitar Hero World Tour.iso"
```

The build needs `default.xex` (the code is recompiled from it); the game needs everything else.
This build targets the **USA disc** (title ID `4156081A`): `default.xex` is 10,301,440 bytes, CRC32 `A5058079`. Other
regions or revisions are not supported.

If you are playing a prebuilt release rather than building from source, you do not need to run `extract-xiso` manually:
**`GH World Tour Launcher.exe`** verifies and extracts your USA Xbox 360 ISO into `assets/` automatically on first
launch.

Nothing in this folder is tracked by git.
