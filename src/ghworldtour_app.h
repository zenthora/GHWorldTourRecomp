// ghworldtour - the app: the SDK's virtual hooks (rex::ReXApp).

#pragma once

#include <rex/cvar.h>
#include <rex/filesystem.h>
#include <rex/logging.h>
#include <rex/rex_app.h>

#include <native_x_renderer/native_x_renderer.h>

#include "input_gates.h"
#include "native_x_renderer_ghworldtour.h"
#include "project.h"
#include "startup.h"

class GhworldtourApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<GhworldtourApp>(new GhworldtourApp(ctx, "ghworldtour", PPCImageConfig));
  }

  // Use the "xenos" GPU emulation (rexgpu-xenos.dll) unless another one was given, and report a
  // plain gamepad as a guitar: GHWT refuses a gamepad ("You must use a Guitar Controller to
  // continue"), and a guitar's whammy bar rests at -32768. Command-line options and the launcher's
  // options still win (the latter load in SetupEnvironment).
  void OnPreSetup(rex::RuntimeConfig& config) override {
    if (config.gpu_plugin.empty()) {
      config.gpu_plugin = "xenos";
    }
    if (rex::cvar::Query<int32_t>("gamepad_subtype") == 0) {
      rex::cvar::SetFlagByName("gamepad_subtype", "6");
    }
    if (!rex::cvar::Query<bool>("gamepad_whammy_rest")) {
      rex::cvar::SetFlagByName("gamepad_whammy_rest", "true");
    }
    // With FMOD mixing on the SDK's audio worker after each frame (src/fmod_mix.cpp), the 3 ms
    // callback spacing is no longer needed; if ghworldtour_fmod_on_audio_thread is off, keep the
    // 3 ms spacing so FMOD's two-block ring does not miss transitions. Command-line and config
    // values still win.
    const bool fmod_on_audio_thread = rex::cvar::Query<bool>("ghworldtour_fmod_on_audio_thread");
    if (rex::cvar::GetFlagSource("audio_callback_min_interval_us") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("audio_callback_min_interval_us",
                               fmod_on_audio_thread ? "0" : "3000");
    }
    if (rex::cvar::GetFlagSource("audio_maxqframes") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("audio_maxqframes", "4");
    }
    if (rex::cvar::GetFlagSource("audio_keep_time") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("audio_keep_time", "true");
    }
    // The audio worker and the XMA decoder in Windows' "Pro Audio" class: a busy PC holds them up
    // less.
    if (rex::cvar::GetFlagSource("audio_thread_priority") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("audio_thread_priority", "true");
    }
    if (rex::cvar::GetFlagSource("audio_wasapi_exclusive_buffer_ms") ==
        rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("audio_wasapi_exclusive_buffer_ms", "10");
    }
    if (rex::cvar::GetFlagSource("audio_wasapi_exclusive_queue") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("audio_wasapi_exclusive_queue", "2");
    }
    if (rex::cvar::GetFlagSource("vblank_timer_spin_us") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("vblank_timer_spin_us", "700");
    }
    if (rex::cvar::GetFlagSource("critical_section_spin_us") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("critical_section_spin_us", "20");
    }
    if (rex::cvar::GetFlagSource("clear_memory_page_state") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("clear_memory_page_state", "false");
    }
    REXLOG_INFO(
        "[audio] callback spacing {} us, maxqframes {}, keep_time {}, thread priority {}, "
        "fmod_on_audio_thread {}",
        rex::cvar::Query<int32_t>("audio_callback_min_interval_us"),
        rex::cvar::Query<int32_t>("audio_maxqframes"),
        rex::cvar::Query<bool>("audio_keep_time") ? "on" : "off",
        rex::cvar::Query<bool>("audio_thread_priority") ? "on" : "off",
        fmod_on_audio_thread ? "on" : "off");
    // The frets that "strum with the frets" presses (the launcher's switch writes the targets). On
    // by default: GHWT has no auto-strum, so a controller or the keyboard would have to strum and
    // fret at once. The strum is gated to songs (src/input_gates.cpp), so the menus' D-pad is
    // unaffected.
    if (rex::cvar::GetFlagSource("mnk_tap_sources") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("mnk_tap_sources", "a,b,y,x,lb");
    }
    if (rex::cvar::GetFlagSource("gamepad_tap_sources") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("gamepad_tap_sources", "a,b,y,x,lb");
    }
    if (rex::cvar::GetFlagSource("mnk_tap_target") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("mnk_tap_target", "dpad_down");
    }
    if (rex::cvar::GetFlagSource("gamepad_tap_target") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("gamepad_tap_target", "dpad_down");
    }
    // Second and subsequent controllers have no profile of their own. Cancel the system sign-in
    // UI cleanly instead of firing XN_SYS_SIGNINCHANGED/XN_SYS_UI with slot 1 still unsigned in
    // (which left GHWT waiting on an empty backdrop when slot 1 pressed a button past the
    // intros), and sign extra controllers in as local guests of the active profile.
    if (rex::cvar::GetFlagSource("signin_ui_cancel") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("signin_ui_cancel", "true");
    }
    if (rex::cvar::GetFlagSource("signin_guests") == rex::cvar::Source::kDefault) {
      rex::cvar::SetFlagByName("signin_guests", "true");
    }
  }

  // Game files: assets/ next to the executable or the repository's assets/. User data: userdata/
  // next to the executable; the saves, settings and achievements in the launchers' current profile.
  void OnConfigurePaths(rex::PathConfig& paths) override {
    if (paths.game_data_root.empty()) {
      paths.game_data_root = ghworldtour::DefaultGameRoot();
    }
    ghworldtour::ConfigureUserData(paths.user_data_root, paths.cache_root);
    ghworldtour::ConfigureProfile(paths.user_data_root);
  }

  // After the SDK loads the base config: GH World Tour Launcher's options, before the window and
  // the GPU are created.
  bool SetupEnvironment() override {
    if (!rex::ReXApp::SetupEnvironment()) {
      return false;
    }
    REXLOG_INFO("[startup] Game files: {}", game_data_root().string());
    REXLOG_INFO("[startup] User data: {}", user_data_root().string());
    REXLOG_INFO("[startup] {}", native_x_renderer::Describe());
    ghworldtour::LoadLauncherOptions(rex::filesystem::GetExecutableFolder() / GAME_OPTIONS);
    return true;
  }

  // NativeXRenderer's tool modes, run instead of the game (the launcher's "Compiling shaders" and
  // the developers' pipeline list builder).
  bool OnToolMode() override {
    if (!native_x_renderer::ToolModeRequested()) {
      return false;
    }
    native_x_renderer::RunToolMode(ghworldtour::NativeXRendererProfile(), game_data_root(),
                                   cache_root());
    return true;
  }

  // The window title (the SDK sets "<app name> <SDK build stamp>").
  void OnPostSetup() override {
    if (window()) {
      window()->SetTitle(GAME_TITLE);
    }
    // The renderer and the trace/observer; before the guest starts, with the window and the
    // graphics system up. The Xenos path draws while native_x_renderer is off.
    native_x_renderer::Initialize(ghworldtour::NativeXRendererProfile(),
                                  runtime() ? runtime()->graphics_system() : nullptr, window(),
                                  runtime() ? runtime()->cache_root() : std::filesystem::path());
    // The "strum with the frets" and controller layout gates: only in a song (src/input_gates.cpp).
    ghworldtour::InitializeInputGates();
  }
};
