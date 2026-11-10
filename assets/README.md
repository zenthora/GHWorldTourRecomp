# Game files

Put the files of your own copy of **Guitar Hero: World Tour (Xbox 360)** here, so that this file exists:

```
assets/default.xex
```

The whole disc content goes in this folder. Extract it from your disc or ISO with
[extract-xiso](https://github.com/XboxDev/extract-xiso/releases):

```powershell
extract-xiso.exe -x -d assets "Guitar Hero World Tour.iso"
```

The build needs `default.xex` (the code is recompiled from it); the game needs everything else.
This disc's executable is 10,301,440 bytes, CRC32 `A5058079`.

Nothing in this folder is tracked by git.
