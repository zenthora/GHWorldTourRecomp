# 0006: Inline FMOD Mixing on the SDK Audio Worker

Status: accepted

## Context

*Guitar Hero: World Tour*'s FMOD engine mixes 256-sample blocks into a two-block ring buffer and polls the read cursor from FMOD's own mixer thread. On Windows, host audio backends drain frames in bursts; if FMOD's thread wakes more than one block (~5.3 ms) late, the reader wraps the ring, blocks are skipped, and song stems play as noise or drift out of sync with the note highway.

## Decision

Hook the game's render client (`sub_8221BA10`) and FMOD's polled update (`sub_82273560`) in `src/fmod_mix.cpp` (enabled by default via `ghworldtour_fmod_on_audio_thread = true`) so FMOD mixes synchronously on the SDK's high-priority audio worker immediately after each submitted audio frame, guarded by a mutex while FMOD's own thread becomes a no-op poll.

## Considered Options

- **Rely solely on `audio_callback_min_interval_us = 3000`**: spaces out host callbacks to emulate console cadence, but adds callback throttling latency and remains vulnerable to FMOD thread scheduling delays.
- **Inline FMOD mixing on the SDK audio worker**: eliminates ring-buffer skips regardless of FMOD thread jitter, lowers callback spacing to `0 us` by default, and remains reversible at runtime via `--ghworldtour_fmod_on_audio_thread=false` (which restores `3000 us` spacing).

## Consequences

- `sub_8221BA10` and `sub_82273560` are coupled via a shared atomic output pointer and mutex; removing or altering either hook requires checking `src/ghworldtour_app.h`'s `audio_callback_min_interval_us` fallback logic.
