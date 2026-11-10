// ghworldtour - startup (see startup.h).

#include "startup.h"

#include <rex/cvar.h>
#include <rex/filesystem.h>
#include <rex/logging.h>
#include <rex/system/flags.h>

#include <fstream>
#include <optional>
#include <string>

#include "profile_store.h"
#include "project.h"

namespace ghworldtour {

std::filesystem::path DefaultGameRoot() {
  std::filesystem::path next_to_exe = rex::filesystem::GetExecutableFolder() / "assets";
  if (std::filesystem::exists(next_to_exe / GAME_XEX)) {
    return next_to_exe;
  }
  std::filesystem::path repository = GHWORLDTOUR_DEFAULT_GAME_ROOT;
  if (std::filesystem::exists(repository / GAME_XEX)) {
    return repository;
  }
  return next_to_exe;
}

void ConfigureUserData(std::filesystem::path& user_data_root, std::filesystem::path& cache_root) {
  if (!rex::cvar::Query<std::string>("user_data_root").empty()) {
    return;  // chosen on the command line
  }
  std::filesystem::path portable = rex::filesystem::GetExecutableFolder() / "userdata";
  std::error_code ec;
  std::filesystem::create_directories(portable, ec);
  std::filesystem::path probe = portable / ".write_test";
  {
    std::ofstream f(probe, std::ios::binary);
    if (!f) {
      return;
    }
  }
  std::filesystem::remove(probe, ec);
  user_data_root = portable;
  if (rex::cvar::Query<std::string>("cache_root").empty()) {
    cache_root = portable / "cache";
  }
}

void ConfigureProfile(const std::filesystem::path& user_data_root) {
  if (!REXCVAR_GET(profile_root).empty()) {
    return;  // chosen on the command line
  }
  if (std::optional<launcher::profiles::GameProfile> profile =
          launcher::profiles::ForGame(user_data_root)) {
    std::u8string folder = profile->folder.u8string();
    REXCVAR_SET(profile_root, std::string(folder.begin(), folder.end()));
    if (REXCVAR_GET(profile_name).empty()) {
      REXCVAR_SET(profile_name, profile->name);
    }
  }
}

void LoadLauncherOptions(const std::filesystem::path& options_path) {
  if (std::filesystem::exists(options_path)) {
    rex::cvar::LoadConfig(options_path);
  } else {
    REXLOG_INFO("[options] {} does not exist: using " GAME_CONFIG, options_path.string());
  }
}

}  // namespace ghworldtour
