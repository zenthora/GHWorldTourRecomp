# GHWorldTourRecomp

Native Windows static recompilation of *Guitar Hero: World Tour* (Xbox 360), covering disc translation, native rendering, controller adaptation, audio/frame pacing, and launcher-managed configuration.

## Language

### Recompilation & Codegen

**Static Recompilation**:
Ahead-of-time translation of an Xbox 360 PowerPC executable into native host C++ code rather than dynamic instruction-by-instruction emulation.
_Avoid_: Emulation, JIT translation

**Codegen**:
The automated analysis and translation pass that converts the game's executable and correction inputs into buildable C++ source units.
_Avoid_: Compilation, build

**Codegen Manifest**:
The top-level project descriptor specifying the target game executable, game data location, generated output directory, and correction files.
_Avoid_: Config file, project manifest

**Analyzer Corrections**:
Manual and gap-discovered function boundaries, jump tables, and register-preservation overrides that repair incomplete automatic disassembly.
_Avoid_: Patches, overrides

**Mid-Assembly Hook**:
A targeted injection point at a specific guest instruction address that inspects or alters registers without replacing an entire function.
_Avoid_: Patch, detour, raw hook

### Rendering & Shaders

**Launcher Default Renderer**:
The primary host graphics path (`NativeXRenderer`) enabled by default for players through the launcher, translating game draw calls directly to Direct3D 12 or Vulkan with native upscaling and frame generation support.
_Avoid_: Default Xenos path, fallback renderer

**Diagnostic Fallback Renderer**:
The SDK's built-in Xenos GPU emulation path used as a compatibility fallback and as the required baseline for draw tracing and observer verification.
_Avoid_: Default renderer, native renderer

**Main 3D View**:
The primary perspective-projected 3D scene pass identified heuristically from game draws and isolated from post-processing, HUD, and note-highway layers.
_Avoid_: Framebuffer, full frame

**Scene Resolve**:
The fixed depth-copy boundary marking the end of the main 3D view, used as the anchor point for temporal upscaling and antialiasing.
_Avoid_: Present, swap, frame end

**Inline Draw Commit**:
A draw submission emitted directly into the command buffer by inlined engine code rather than through a hooked graphics API entry point.
_Avoid_: Tracked draw, API draw

**Pipeline Cache**:
The per-user runtime binary archive of compiled host shaders and pipelines accumulated locally during gameplay.
_Avoid_: Pipeline list, shipped shaders

**Pipeline List**:
The compact portable manifest enumerating observed shaders and pipeline states so a fresh installation can pre-compile shaders ahead of gameplay.
_Avoid_: Pipeline cache, shader binary

### Input & Gating

**Tap-Strum**:
An accessibility input mode ("Strum with the frets") that pairs each fret press on a keyboard or standard gamepad with a strum signal, active only during songs.
_Avoid_: Auto-strum, fret macro

**Device Remap**:
A per-controller button layout override (such as Guitar Hero III's trigger-based fret mapping) tied to a specific controller identifier rather than an entire controller family.
_Avoid_: Type remap, global keybind

**Song-Frame Gate**:
A time-bounded runtime predicate opened by per-frame song player updates so gameplay-only features like Tap-Strum and Device Remap disengage automatically in menus and pause screens.
_Avoid_: Menu detector, state hook

**Whammy Rest**:
Calibration handling that treats a standard controller's centered right stick or an uninitialized guitar bar as a fully released whammy axis until deliberately moved.
_Avoid_: Deadzone, stick drift fix

### Audio, Timing & Storage

**Audio-Worker Mixing**:
Synchronized execution of the game's audio mixer directly on the host audio worker after each submitted sound frame to prevent ring-buffer underruns and music-to-chart drift.
_Avoid_: Polled audio, callback throttling

**Console Timebase**:
The original Xbox 360 hardware clock rate emulated for song timing so note charts stay synchronized with audio tracks over long songs.
_Avoid_: Host clock, wall clock

**Game Data Root**:
The read-only folder containing the user-supplied extracted Xbox 360 disc content required for code generation and runtime asset loading.
_Avoid_: User data, assets repo

**Runtime User Data**:
The per-installation storage folder holding shared caches, installed downloadable content, and title metadata outside individual player saves.
_Avoid_: Profile folder, game data

**Launcher Profile**:
An isolated player identity space managed by the launcher that stores saves, title settings, and achievement unlocks independently of runtime caches.
_Avoid_: User data, system account

**Configuration Precedence**:
The strict override hierarchy from lowest to highest priority: application defaults, base config file, launcher options file, and command-line flags.
_Avoid_: Settings merge, config order
