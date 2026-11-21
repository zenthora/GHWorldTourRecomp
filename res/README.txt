GHWorldTourRecomp {VERSION} - Guitar Hero: World Tour (Xbox 360), for Windows
===========================================================================

A static recompilation of the Xbox 360 game to native Windows. The game's code is already translated and
compiled into GHWorldTourRecomp.exe: you do not need to compile anything. You do need your own copy of the
game, because this package contains no game files.

Not affiliated with Microsoft, Activision or Neversoft.


REQUIREMENTS

- Windows 10 or 11, 64-bit.
- A GPU with up-to-date drivers that support Vulkan (NativeXRenderer, the default renderer in the launcher)
  or Direct3D 12 (the Xenos renderer).
- A CPU with SSE4.2 (practically any 64-bit CPU from 2009 on).
- Microsoft Visual C++ Redistributable 2015-2022 (x64). Most PCs already have it. If Windows says that
  MSVCP140.dll or VCRUNTIME140.dll is missing, install it from:
  https://aka.ms/vs/17/release/vc_redist.x64.exe
- Your Guitar Hero: World Tour disc as an ISO file (the USA disc; about 6.3 GB once installed).
- An Xbox 360 guitar. Any other controller works as a guitar too, and so does the keyboard.
- To sing (experimental): a microphone connected to the PC, and a controller for the singer.


INSTALLATION

1. Either run the installer (GHWorldTourRecomp-{VERSION}-setup.exe: it installs for your Windows user,
   without administrator rights), or extract this zip to any writable folder, for example
   C:\Games\GHWorldTourRecomp (do not put the portable zip in Program Files).

2. Run "GH World Tour Launcher.exe". The first time, it asks for your Xbox 360 ISO, checks that it is the
   right game and extracts its files into assets\ next to the launcher, then asks you to create your profile
   (your saves, achievements and playtime, shared with other RecompLauncher games under
   %APPDATA%\ElGuslml Recomps). You only do this once.

   You can also copy the game files yourself instead: put the contents of the disc into the "assets"
   folder, so that assets\default.xex exists (extract-xiso, https://github.com/XboxDev/extract-xiso/releases,
   extracts them from an ISO).

3. Choose your options and press PLAY. Next time you can start GHWorldTourRecomp.exe directly: it uses the
   options saved by the launcher (if launching directly without having run the launcher first, pass
   --native_x_renderer=true or set it in ghworldtour.toml to use NativeXRenderer).

4. Calibrate: in the game's options, run the audio and video calibration once, so that the notes match what
   you hear on your speakers or headphones.

If your default.xex is not the version this build was made from (title ID 4156081A, CRC32 A5058079), the
game warns you: a different version will most likely crash.


"WINDOWS PROTECTED YOUR PC" / UNKNOWN PUBLISHER

The executables are not code-signed, so Windows SmartScreen warns about an unknown publisher the first time
you run them. To avoid it with the zip, unblock it before you extract it: right-click it, Properties, tick
"Unblock" at the bottom of the General tab, OK, and then extract it. Otherwise click "More info" and then
"Run anyway" in the warning (once for each program).


GH WORLD TOUR LAUNCHER

The launcher works with the mouse, the keyboard or a controller. Changes are saved automatically and apply
when you press PLAY.

- Play: starts the game, with your current settings, achievements and updates at a glance. The first time,
  and after an update of the game or of your graphics driver, it first shows "Compiling shaders" for a
  moment: it prepares the game's graphics for your graphics card from 4156081A.pipelines.list, so the game
  does not stutter on first encounter (with NativeXRenderer). Skip starts the game right away and compiles
  shaders as you play.
- Your profile (your picture at the top right): hours played, streaks, the week's activity, your games and
  your favorite achievements; edit your name, picture and color, or switch profiles.
- Achievements: the game's achievements, unlocked or not. In the game, F7 shows the same list.
- Controls: your guitars, controllers, the keyboard and the microphone.
  - A guitar or a controller: what each of its buttons does. A plain gamepad is reported as a guitar, and
    "Strum with the frets" is enabled by default so frets also strum during songs (menus keep D-pad
    navigation). Each controller keeps its own assignments, including Guitar Hero III-style trigger
    mappings gated to songs.
  - Keyboard: frets default to D F J K L, Up/Down strum, Space/Backspace Star Power, Return/X Start.
  - Multiple controllers: controller slot 0 owns the active profile and saves; extra controllers join as
    local guests.
  - Microphone: select a PC microphone for Vocals (experimental).
- Video / Graphics: choose NativeXRenderer (default in the launcher) or Xenos fallback, upscaling (AMD FSR
  3.1, NVIDIA DLSS/DLAA on RTX GPUs), antialiasing (SMAA/FXAA when upscaler is off), and target frame
  rate (60, 120, 144, 160, 165 or 240 FPS). V-Sync defaults off to avoid present-queue input lag on
  non-60 Hz displays.
- Updates: the launcher checks GitHub releases for a new version when it starts (you can turn that off)
  and installs updates in place while preserving assets\, userdata\, and .toml configuration files.


STEAM BIG PICTURE

Add GHWorldTourRecomp.exe as a non-Steam game (pass --native_x_renderer=true if launching directly without
having run the launcher first) to launch straight into the game, or add "GH World Tour Launcher.exe" to
change options with a controller before playing.


FILES

- ghworldtour.toml           Base settings. Created or edited by you for persistent overrides.
- ghworldtour_options.toml   What GH World Tour Launcher saves. Loaded after ghworldtour.toml.
- logs\                      Log files: the game's (ghworldtour_NNN.log) and the launcher's
                             (launcher_NNN.log). Attach the latest ones when reporting a problem.
- userdata\                  The shader/pipeline caches. Keep this folder if you move the game.
- %APPDATA%\ElGuslml Recomps Shared profile storage (saves, achievements, playtime).

Command line options (--name=value, for example in Steam launch options) override both .toml files, e.g.
--user_language=1 (English), --ghworldtour_frame_rate=120 or --native_x_renderer=false (Xenos fallback).


REPORTING A PROBLEM

Open an issue on the project's page with where in the game it happened, a screenshot if you can, and the
latest files in the logs\ folder.


MORE INFORMATION

{MORE_INFO}

GHWorldTourRecomp's own code is under the MIT license (LICENSE.txt). It is built on the ReXGlue SDK,
NativeXRenderer, RecompLauncher and other components under their own licenses: see THIRD_PARTY_NOTICES.md
and the "licenses" folder.
