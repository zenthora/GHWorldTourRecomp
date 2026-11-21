# 0002: NativeXRenderer as Launcher Default Renderer

Status: accepted

## Context

The game can render through either the SDK's Xenos GPU emulation (`rexgpu-xenos`, Direct3D 12 by default or Vulkan) or `NativeXRenderer` (Vulkan via DiligentCore). Standalone executable defaults still initialize Xenos unless overridden, whereas the launcher configures the player-facing experience via `ghworldtour_options.toml`.

## Decision

Set `kNativeXRendererDefault = true` in `launcher/game.h` so fresh launcher installations default to `NativeXRenderer`, while retaining Xenos emulation as the fallback and diagnostic baseline (`--native_x_renderer=false`).

## Considered Options

- **Default to Xenos GPU emulation**: preserves draw-observer and trace tooling out of the box, but gives up native host rendering, temporal upscaling (DLSS / FSR 3.1), DLAA, and frame generation by default.
- **Default to `NativeXRenderer` in the launcher**: delivers better visual quality, upscaling, and frame-pacing options for players out of the box while keeping Xenos one toggle or flag away.

## Consequences

- Developers running trace or draw-observer diagnostics must explicitly disable `NativeXRenderer` (`--native_x_renderer=false`).
- Documentation and standalone-app defaults must clearly distinguish the launcher default (`NativeXRenderer`) from the diagnostic/standalone fallback (`Xenos`).
