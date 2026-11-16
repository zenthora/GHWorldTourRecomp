# 0005: Song-Frame 250 ms Heuristic Input Gate

Status: accepted

## Context

Two accessibility/layout features—`Tap-Strum` ("Strum with the frets") and Guitar Hero III-style trigger `Device Remap`—are essential during active songs, but break menu navigation if left enabled outside songs (fret presses move D-pad menu cursors, and trigger remaps move A/B confirm/cancel onto LT/LB).

## Decision

Hook a single per-player song-frame update (`sub_82131658`) via `[[midasm_hook]]` in `src/input_gates.cpp` and keep both `SetTapGate` and `SetRemapGate` open only while a song-frame tick occurred within the last 250 ms.

## Considered Options

- **Reverse-engineer the game's full UI/pause state machine**: gives zero-latency state transitions, but requires finding and maintaining fragile global state offsets across menus, lobbies, and pause screens.
- **250 ms song-frame heartbeat (`InSong()`)**: requires only one verified hook (`sub_82131658`), handles pause screens and menu exits automatically once frames stop for a quarter second, and shares one gate across both keyboard tap-strum and controller remap.

## Consequences

- Exiting a song or opening the pause menu has up to a 250 ms window before controls revert to standard menu navigation.
- Any gameplay mode that updates players through a different routine than `sub_82131658` would fail to open the gates until hooked.
