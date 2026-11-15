// ghworldtour - the names and the frame size the game executable (src/) uses.

#pragma once

#define GAME_TITLE "Guitar Hero: World Tour"
#define GAME_EXE "GHWorldTourRecomp.exe"
#define GAME_LAUNCHER "GH World Tour Launcher"
// The game's executable in the game files (assets/): the code is recompiled from it.
#define GAME_XEX "default.xex"
// Next to GAME_EXE: the base settings.
#define GAME_CONFIG "ghworldtour.toml"
// The launcher's settings, loaded after GAME_CONFIG.
#define GAME_OPTIONS "ghworldtour_options.toml"

// The features this recomp does not have (the launcher hides their rows).
#define GAME_HAS_NATIVE_X_RENDERER true
#define GAME_FRAME_RATE_CVAR "ghworldtour_frame_rate"
#define GAME_ULTRAWIDE_CVAR ""

// The game's frame: most Xbox 360 games draw 1280x720; check it in a RenderDoc capture or the SDK's
// log before relying on it.
#define GAME_FRAME_WIDTH 1280
#define GAME_FRAME_HEIGHT 720
