// This game's profile: everything the launcher knows about the game it belongs to. RecompLauncher's
// code is the same for every game; game.h, game.cpp (the game's texts) and palette.h (its colors)
// are each game's, with the art (launcher/art), the icon (res/icon.ico), the resource script
// (res/launcher.rc) and the version (res/version.h). The names and options the game executable
// shares are src/project.h's.

#pragma once

#include <array>
#include <cstdint>
#include <vector>

#include "game_types.h"
#include "project.h"
#include "version.h"

namespace launcher::game {

// --- Names ---

inline constexpr const char* kName = GAME_TITLE;
inline constexpr const char* kRecompExecutable = GAME_EXE;
inline constexpr const char* kLauncherExecutable = GAME_LAUNCHER ".exe";
inline constexpr const char* kLauncherName = GAME_LAUNCHER;
inline constexpr const char* kConfigFile = GAME_CONFIG;
inline constexpr const char* kOptionsFile = GAME_OPTIONS;
inline constexpr const char* kDocumentsFolder = "ghworldtour";
inline constexpr const char* kVersion = RECOMP_VERSION_STR;

// --- The look ---

inline constexpr const char* kArtKicker = "GUITAR HERO";
inline constexpr const char* kArtTitle = "World Tour";
// A guitar pick with a lightning bolt, in a 24-unit box, stroked as the launcher's icons are.
inline constexpr const char* kBrandIcon =
    "<path d='M12 21c-4-4-8-9-8-13 0-3 4-5 8-5s8 2 8 5c0 4-4 9-8 13z'/><path d='M13 6l-3 5h4l-3 "
    "5'/>";
inline constexpr const char* kBrandTitle = "Guitar Hero";
inline constexpr const char* kBrandSubtitle = "World Tour";
// The stage in launcher/art/background.svg (1280 x 760), cropped around its centre.
inline constexpr float kArtFocusX = 0.5f;
inline constexpr float kArtFocusY = 0.5f;
inline constexpr bool kBrandRound = false;
inline constexpr bool kUppercaseTitles = true;

// --- The disc ---

inline constexpr const char* kDiscExecutable = GAME_XEX;
inline constexpr uint32_t kTitleId = 0x4156081A;
inline constexpr uint32_t kExecutableCrc32 = 0xA5058079;
inline constexpr const char* kRegion = "USA";
// The disc's files (6636) as extracted from this ISO.
inline constexpr uint64_t kInstalledBytes = 6299848807ULL;
inline constexpr int kFrameWidth = GAME_FRAME_WIDTH;
inline constexpr int kFrameHeight = GAME_FRAME_HEIGHT;

// --- Updates ---

// Empty: no update checks until this project has a public repository and releases.
inline constexpr const char* kReleasesApi = "";
inline constexpr const char* kReleasesPage = "";

// --- The game's own options (empty: the game has no such option, and the launcher no row) ---

inline constexpr bool kHasNativeXRenderer = GAME_HAS_NATIVE_X_RENDERER;
inline constexpr bool kNativeXRendererDefault = false;
inline constexpr bool kHasDlaa = false;
inline constexpr bool kShadowQuality = false;
inline constexpr const char* kFrameRateCvar = GAME_FRAME_RATE_CVAR;
inline constexpr bool kFrameRateIsBool = false;
inline constexpr std::array<FrameRate, 0> kFrameRates{};
inline constexpr int kFrameRateDefault = 60;
inline constexpr const char* kNoMsaaCvar = "";
inline constexpr const char* kMsaaLabel = "";
inline constexpr const char* kUltrawideCvar = GAME_ULTRAWIDE_CVAR;

// The disc's languages (English, French, German, Italian, Spanish), picked with user_language.
inline constexpr std::array<Language, 5> kLanguages{{
    {3, "Deutsch", nullptr, nullptr},
    {1, "English", nullptr, nullptr},
    {5, "Español", nullptr, nullptr},
    {4, "Français", nullptr, nullptr},
    {6, "Italiano", nullptr, nullptr},
}};

// No switches of this recomp's own yet.
inline constexpr std::array<Toggle, 0> kToggles{{}};

// --- Downloadable content and pipelines ---

inline constexpr bool kHasDlcPage = false;
inline constexpr bool kHasPipelineList = false;

// --- The keyboard ---

// The keyboard as a guitar: frets D F J K L, the arrows strum, Space/Backspace Star Power.
inline constexpr std::array<KeyDefault, 19> kKeyboardDefaults{{
    {"keybind_a", "D"},
    {"keybind_b", "F"},
    {"keybind_y", "J"},
    {"keybind_x", "K"},
    {"keybind_left_shoulder", "L"},
    {"keybind_dpad_up", "Up"},
    {"keybind_dpad_down", "Down"},
    {"keybind_back", "Space,Backspace"},
    {"keybind_start", "Return,X"},
    {"keybind_rstick_right", "Right"},
    {"keybind_rstick_up", ""},
    {"keybind_rstick_down", ""},
    {"keybind_rstick_left", ""},
    {"keybind_rstick_press", ""},
    {"keybind_lstick_up", ""},
    {"keybind_lstick_down", ""},
    {"keybind_lstick_left", ""},
    {"keybind_lstick_right", ""},
    {"keybind_lstick_press", ""},
}};
// The launcher's switch that makes the frets (and a controller's) strum as they are pressed: the
// control it presses when on, the D-pad (strumming). "": no switch. The game allows the strum only
// in a song (src/keyboard.cpp), so menus keep their D-pad.
inline constexpr const char* kKeyboardTapTarget = "dpad_down";
// A fresh install has it on: GHWT has no auto-strum (Beginner still asks for a strum), and playing
// with a controller or the keyboard otherwise means strumming and fretting at once.
inline constexpr bool kKeyboardTapDefault = true;
inline constexpr bool kGamepadTapDefault = true;
// A fresh install has V-Sync off: GHWT runs at 60 FPS only, and on a display whose refresh rate is
// not a whole multiple of 60 (144, 165 Hz) V-Sync makes each frame wait in the present queue, which
// is input lag the player cannot calibrate away. Off, each frame is presented as it is ready.
inline constexpr bool kVsyncDefault = false;
// A guitar's whammy bar on the right stick.
inline constexpr bool kHasWhammy = true;

// --- Singing ---

// The SDK's two USB microphones can be recording devices of the PC (Game Settings > Microphone).
inline constexpr bool kHasMicrophones = true;
inline constexpr int kMicrophoneGainDefault = -12;

// --- The controls in the game's words ---

const std::vector<GameControlGroup>& GameControlsFor(uint32_t language);

// --- Texts of the game's own (game.cpp) ---

struct GameTexts {
  const char* welcome_title;
  const char* welcome_text;
  std::array<const char*, kToggles.size() * 2> toggles;
  std::array<const char*, kToggles.size()> toggle_help{};
  const char* done_title = nullptr;
  const char* done_text = nullptr;
  const char* dlc_where = nullptr;
  const char* extracting_title = nullptr;
  const char* extracting_text = nullptr;
  const char* keyboard_tap_title = nullptr;
  const char* keyboard_tap_hint = nullptr;
  const char* part_instrument = nullptr;
  const char* part_vocals = nullptr;
};
const GameTexts& GameTextsFor(uint32_t language);

}  // namespace launcher::game
