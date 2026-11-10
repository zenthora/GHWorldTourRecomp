// ghworldtour - the strum on each fret, only in a song.
//
// With mnk_tap_target = "dpad_down" (GH World Tour Launcher's switch) the SDK's keyboard pad
// presses the D-pad, a strum, when a fret key is pressed, the frets pressed within
// mnk_tap_window_ms of each other making one chord; gamepad_tap_target does the same for a
// controller playing guitar. The menus move their cursor with the D-pad, so every fret pressed to
// confirm (green) or go back (red) would move it too: the strum is allowed only while a song runs.
// A player's update in a song (sub_82131658, every frame for each player; the equivalent of GH
// Metallica's sub_82137F18) marks the time; the gate is open while that mark is recent.

#include "keyboard.h"

#include <rex/input/mnk/mnk_input_driver.h>

#include <atomic>
#include <chrono>
#include <cstdint>

namespace {

using Clock = std::chrono::steady_clock;

// When a song last updated its players (steady clock ticks), 0 if never.
std::atomic<int64_t> g_song_frame{0};

// A song's frames come at least 30 times a second; a quarter of a second without one is the menus
// (or the pause menu, where the players are not updated).
bool InSong() {
  int64_t last = g_song_frame.load(std::memory_order_relaxed);
  return last != 0 &&
         Clock::now().time_since_epoch().count() - last <
             std::chrono::duration_cast<Clock::duration>(std::chrono::milliseconds(250)).count();
}

}  // namespace

// [[midasm_hook]] 0x82131658: the entry of sub_82131658, a player's update in a song.
void GHWorldTourSongFrameHook() {
  g_song_frame.store(Clock::now().time_since_epoch().count(), std::memory_order_relaxed);
}

namespace ghworldtour {

void InitializeKeyboard() {
  rex::input::mnk::SetTapGate(InSong);
}

}  // namespace ghworldtour