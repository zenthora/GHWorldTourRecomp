// This game's palette: every color the launcher draws, by name (ui.h, the pages). The names are the
// same in every game. Guitar Hero: World Tour's: neutral blacks with the stage's orange accent.

#pragma once

#include "ui/color.h"

namespace ui::col {

inline constexpr ImU32 kBackground = Hex(0x0E0D0C);
inline constexpr ImU32 kCard = Hex(0x171513);
inline constexpr ImU32 kCardRaised = Hex(0x1D1A17);
inline constexpr ImU32 kChip = Hex(0x22201D);
inline constexpr ImU32 kField = Hex(0x22201D);
inline constexpr ImU32 kFieldBorder = Hex(0x2E2A26);
inline constexpr ImU32 kTrack = Hex(0x2A2723);
inline constexpr ImU32 kOutline = Hex(0x2E2A26);
inline constexpr ImU32 kDashed = Hex(0x3A3530);
inline constexpr ImU32 kGlyph = Hex(0x1D1A17);
inline constexpr ImU32 kText = Hex(0xEFEDEA);
inline constexpr ImU32 kTextSoft = Hex(0xD0CBC5);
inline constexpr ImU32 kTextMuted = Hex(0xB2ACA6);
inline constexpr ImU32 kLabel = Hex(0x9C968F);
inline constexpr ImU32 kTextDim = Hex(0x8A847D);
inline constexpr ImU32 kAccent = Hex(0xF26A1B);
inline constexpr ImU32 kAccentLight = Hex(0xFF9B4D);
inline constexpr ImU32 kOnAccent = Hex(0x1A0B02);
inline constexpr ImU32 kGlyphOnAccent = kOnAccent;
inline constexpr ImU32 kAccentTint = Hex(0x2E1A0E);
inline constexpr ImU32 kDonate = Hex(0xEF5B4C);
inline constexpr ImU32 kOnDonate = Hex(0x1F0605);
inline constexpr ImU32 kDonateIcon = kOnDonate;
inline constexpr ImU32 kSuccess = Hex(0x5BC489);
inline constexpr ImU32 kSuccessTint = Hex(0x1B3A2A);
inline constexpr ImU32 kError = Hex(0xF07B6B);
inline constexpr ImU32 kErrorTint = Hex(0x3A1F1C);
inline constexpr ImU32 kGlyphA = Hex(0x5BC489);
inline constexpr ImU32 kGlyphB = Hex(0xF07B6B);
inline constexpr ImU32 kGlyphX = Hex(0x6AA6F2);
inline constexpr ImU32 kGlyphY = Hex(0xE8C547);

inline constexpr ImU32 kNoticeTint = Hex(0x2A1C10);
inline constexpr ImU32 kScrollbarActive = Hex(0x544C45);

inline constexpr ImU32 kHeader = Hex(0x0B0908, 224);
inline constexpr ImU32 kFooter = Hex(0x0B0908, 240);
inline constexpr ImU32 kHairline = Hex(0xFFFFFF, 20);
inline constexpr ImU32 kPanel = Hex(0x14110F, 237);
inline constexpr ImU32 kPanelChip = Hex(0xFFFFFF, 26);
inline constexpr ImU32 kPanelTrack = Hex(0xFFFFFF, 31);
inline constexpr ImU32 kBumper = Hex(0xFFFFFF, 31);
inline constexpr ImU32 kOnBumper = Hex(0xD0CBC5);
inline constexpr ImU32 kTabText = Hex(0xB2ACA6);
inline constexpr ImU32 kTabActive = Hex(0xFFFFFF);
inline constexpr ImU32 kFocus = Hex(0xFFFFFF);
inline constexpr ImU32 kDim = Hex(0x080706);
inline constexpr ImU32 kHintBumper = Hex(0xFFFFFF, 36);
inline constexpr ImU32 kOnHintBumper = Hex(0xE6E2DE);
inline constexpr ImU32 kOnGlyphA = Hex(0x06210F);
inline constexpr ImU32 kOnGlyphB = Hex(0x2A0B06);
inline constexpr ImU32 kOnGlyphX = Hex(0x061A33);
inline constexpr ImU32 kOnGlyphY = Hex(0x2A2205);
inline constexpr ImU32 kGhostFill = Hex(0x0B0908, 179);
inline constexpr ImU32 kGhostBorder = Hex(0xFFFFFF, 46);

inline constexpr float kRoundness = 1.0f;

}  // namespace ui::col
