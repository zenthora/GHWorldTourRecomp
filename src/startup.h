// ghworldtour - startup: game files, user data, launcher profiles and options.

#pragma once

#include <filesystem>

namespace ghworldtour {

// Game files when --game_data_root is not given: assets/ next to GHWorldTourRecomp.exe if it holds
// default.xex, otherwise the repository's assets/ (GHWORLDTOUR_DEFAULT_GAME_ROOT).
std::filesystem::path DefaultGameRoot();

// User data (shader cache, downloadable content; without a launcher profile, the saves too) in
// userdata/ next to the executable, so the game lives in one folder. Left as the SDK default
// (Documents\ghworldtour) when --user_data_root was given or that folder cannot be written.
void ConfigureUserData(std::filesystem::path& user_data_root, std::filesystem::path& cache_root);

// The launchers' profile the game runs with (RecompLauncher's profile_store.h): the current one's
// folder and name as the SDK's profile_root and profile_name, unless --profile_root was given.
void ConfigureProfile(const std::filesystem::path& user_data_root);

// GH World Tour Launcher's options (ghworldtour_options.toml), after the base config and before the
// window and the GPU are created.
void LoadLauncherOptions(const std::filesystem::path& options_path);

}  // namespace ghworldtour
