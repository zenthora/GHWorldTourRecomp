// ghworldtour - the SDK's input features that apply only in a song.

#pragma once

namespace ghworldtour {

// Before the guest starts: the SDK's strum on each fret and the controllers' layout
// (gamepad_remap, gamepad_device_remap) apply only while a song runs.
void InitializeInputGates();

}  // namespace ghworldtour
