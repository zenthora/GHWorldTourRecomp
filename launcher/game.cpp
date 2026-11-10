// This game's own texts (game.h): the first run's screens and the two parts of a controller in the
// game's words. English is used for every launcher language for now.

#include "game.h"

namespace launcher::game {

const GameTexts& GameTextsFor(uint32_t language) {
  (void)language;
  static const GameTexts kTexts{
      .welcome_title = "Welcome to the show",
      .welcome_text =
          "Before the encore, the game has to be installed. The launcher extracts its files from "
          "your "
          "Xbox 360 ISO; you only have to do this once.",
      .toggles = {},
      .done_title = "The stage is set!",
      .done_text =
          "The game was installed. Go play now, or review the video, graphics and instrument "
          "settings "
          "first; you can always change them in the launcher.",
      .extracting_title = "Setting up the stage",
      .extracting_text =
          "The game is being extracted. It can take a few minutes; do not close the launcher.",
      .keyboard_tap_title = "Strum with the frets",
      .keyboard_tap_hint = "A fret press strums too, in a song: play without a guitar's strum bar.",
      .part_instrument = "Guitar",
      .part_vocals = "Vocals",
  };
  return kTexts;
}

const std::vector<GameControlGroup>& GameControlsFor(uint32_t language) {
  (void)language;
  static const std::vector<GameControlGroup> kNone;
  return kNone;
}

}  // namespace launcher::game
