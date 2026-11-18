# NativeXRenderer in GHWorldTourRecomp

The game's D3D library is replaced by [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer) when
`native_x_renderer = true`. It is the launcher default (`kNativeXRendererDefault = true` in `launcher/game.h`, passed
via `ghworldtour_options.toml`), while standalone `GHWorldTourRecomp.exe` (`GhworldtourApp` in `src/ghworldtour_app.h`)
defaults to the SDK's Xenos emulation unless `--native_x_renderer=true` is passed; Xenos remains the fallback and the
diagnostic trace/observer path. The game side is `src/native_x_renderer_ghworldtour.cpp`: one hook per D3D entry point
and a `Profile` with the XDK 2.0.7645 device layout. The library is the `native_x_renderer/` submodule.

## Where the library is

GHWT was built with XDK **2.0.7645**. Its D3D library is linked from **0x821B06F0** (the XGraphics cache
helpers) to **0x821C4040** (Present); the game engine follows. Each function has the same body as in GH
Metallica's XDK 2.0.7978 library (the closest public recomp), so
the entry points were found with `tools/find_equivalent.py` against a reference codegen of that disc and
checked by reading the generated code. The whole library sits about `0xD300` higher than Metallica's, and
the current objects (index buffer, render targets, depth, vertex buffers, textures, viewport) another
8 bytes lower in the device; everything else (dirty masks, constants, register groups, tiling, command
buffer, inline draw end) is at Metallica's offsets.

Reference codegen (not tracked):

```powershell
# out/ref-ghm/ghm_manifest.toml points at <ghm-assets>/default.xex
rexglue codegen out/ref-ghm/ghm_manifest.toml
python tools/find_equivalent.py --reference-dir out/ref-ghm/generated --func sub_821C1E30 --top 10
```

## The device layout (XDK 2.0.7645)

| What | Offset |
|---|---|
| dirty masks (VS, PS, fetch, pipeline) | +0, +8, +24, +32 |
| fetch constants | +1152 |
| vertex shader float constants | +1920 |
| pixel shader float constants | +6016 |
| bool/loop constants | +10112 |
| register shadow | +10368 (0x2000), +10444 (0x2100), +10528 (0x2180), +10548 (0x2200), +10596 (0x2280), +10680 (0x2300), +10832 (0x2380) |
| write-back block / fence counter / flags | +10896 / +10908 / +10940 |
| vertex declaration | +11820 |
| flagged stream strides | +11832 + stream |
| index buffer | +12436 |
| render targets (4) | +12440 |
| depth stencil | +12456 |
| vertex buffers | +12460 + stream |
| stream strides | +12528 + stream |
| textures | +12544 |
| viewport (x, y, w, h, min z, max z) | +12648 |
| scissor rectangle | +12676 |
| pixel shader / vertex shader | +12692 / +12696 |
| predication mask | +12708 |
| tile count / tile rectangles | +12748 / +12752 |
| inline draw end | +13444 |

Objects: a texture's fetch constant at +28; a surface's `RB_SURFACE_INFO` at +24, color/depth info at +28,
size at +36 (width in bits 18..31, height in bits 3..17); a buffer's address at +24 and size at +28.

The scene resolve is the `Resolve` whose return address is **0x824AE0D0** (in `sub_824ADED0`): it copies the
finished 1280x720 scene into the guest texture bound at `0xABA26C00`. The 320x180 glow passes then sample that
copy, the composite draws it back, and the HUD and the note highway come after it, so the same address is the
antialiasing and upscaling boundary. Look for `Resolve flags=… [rect 0 0 1280 720]` in a trace: it is the only
1280x720-to-texture copy in a frame.

## The entry points

| Call | Address | Call | Address |
|---|---|---|---|
| DrawIndexedVertices | 0x821B4B28 | SetVertexShader | 0x821B3778 |
| DrawVertices | 0x821B4738 | SetPixelShader | 0x821B34C0 |
| DrawVerticesUP | 0x821B4130 | SetVertexDeclaration | 0x821B3948 |
| BeginVertices | 0x821B3C88 | SetStreamSource | 0x821B76A8 |
| BeginIndexedVertices | 0x821B4178 | SetIndices | 0x821B7850 |
| SetRenderTarget | 0x821B8008 | SetTexture | 0x821B26D8 |
| SetDepthStencilSurface | 0x821B8350 | SetVertexShaderConstantF | 0x821B3220 |
| Clear | 0x821CEE18 | SetPixelShaderConstantF | 0x821B3300 |
| ClearF | 0x821CECF0 | VertexBufferLock | 0x821B9720 |
| Resolve | 0x821CF658 | VertexBufferUnlock | 0x821B9770 |
| BeginTiling | 0x821C2FE0 | IndexBufferLock | 0x821B9780 |
| EndTiling | 0x821C3360 | IndexBufferUnlock | 0x821B97C8 |
| SetPredication | 0x821C2E70 | TextureUnlock | 0x821B06F0 |
| SetViewport | 0x821B7ED8 | FlushCpuRange | 0x821C2C98 |
| SetScissorRect | 0x821B7538 | KickSegment | 0x821BBE50 |
| NewSegment | 0x821BBB70 | SetShaderGPRAllocation | 0x821B3AD8 |
| QueryIssue | 0x821BF150 | QueryGetData | 0x821BF3D8 |
| Swap | 0x821C3B50 | Present | 0x821C4040 |

`EndVertices` (0x821B4120) is not hooked: the engine inlines it as the store of +13444 into the write
pointer, which the profile's `inline_draw_end` models. `DrawIndexedVerticesUP` (0x821B4698) is not hooked
either; its commit is the same inline store. Every draw in a trace is a `DrawVerticesUP` or a
`DrawIndexedVertices` coming from `BeginVertices`/`BeginIndexedVertices`, so the two are the ones that matter.

## Shaders and pipelines

The compiled shaders are in the CHNK-compressed `DATA/COMPRESSED/FXFILES/MaterialLibrary.bin.xen` (World Tour
keeps only this copy; the uncompressed `DATA/FXFILES/MaterialLibrary.bin.xen` is the material table). The
profile names the compressed file for the pipeline list (`res/4156081A.pipelines.list`, tracked in git since `a8925aa` and
staged beside the binary by `tools/package-release.ps1`). `kHasPipelineList = true` in `launcher/game.h` enables the
launcher's "Compiling shaders" pre-compilation flow for that list (regenerate with `--native_x_renderer_make_pipeline_list`;
if absent, shaders compile on first use and cache in `<user data>/cache/native_x_renderer`).

## Turning it on and verifying

1. Build (the SDK comes from its source tree, which NativeXRenderer compiles graphics sources from):

   ```powershell
   git submodule update --init --recursive
   cmake --preset win-amd64-release
   .\tools\build.ps1
   ```

2. Trace, on the Xenos path: `--native_x_renderer_trace=true` (F9 dumps a frame; the receiver also takes
   `--native_x_renderer_trace_interval=` and `--native_x_renderer_trace_dump_at=<frame>`). Check that every
   draw has a shader, a declaration, a target, and a plausible vertex format and stride.

3. Turn the renderer on: `--native_x_renderer=true`, or the launcher's Graphics page ("Renderer"). Antialiasing
   is `native_x_renderer_antialiasing=smaa|fxaa`; the temporal upscalers take the view boundary above and are
   chosen by the same cvar (`dlaa|dlss_quality|dlss_balanced|dlss_performance|dlss_ultra_performance` and
   `fsr_native|fsr_quality|fsr_balanced|fsr_performance|fsr_ultra_performance`; there is no `native_x_renderer_upscaling`
   cvar). The launcher drives all of it through `ghworldtour_options.toml`.

4. Run the scenarios: `tools/scenario.ps1 -Scenario boot|quickplay|song`. It takes the renderer's own
   options, so no copy of it is needed: `-NativeXRenderer`, `-Scaling bilinear|fsr|nis`, `-Sharpness`,
   `-RenderScale`, `-Width`, `-Height`, and `-ExtraArgs` for anything else (for example
   `-NativeXRenderer -Scaling fsr -Width 1600 -Height 900 -RenderScale 1`, where `-RenderScale 1` keeps the
   game's 1280x720 image so the filter has something to upscale). It prints the effective `swap chain`,
   `render scale` and `scaling` lines from the log, and fails when the command line was rejected or a
   screenshot is not the game.

### State of the integration

Verified on this machine (RTX 4070 Ti, Vulkan 1.4):

- Boot, title, setlist and quickplay render correctly: menus, cover art, per-song art, the note highway, the
  band, the crowd, the HUD and the fret buttons all match the Xenos path.
- In a song the renderer draws 294-658 calls a frame with 0 failed draws, 0 draws without a target, and
  0 draws waiting for a pipeline; SMAA is applied on 100 % of frames. SMAA and FXAA act on that copy of the
  view's depth (there is no output-sized color copy, see "Temporal upscaling and DLAA" below); the game's own
  4x MSAA is what antialiases the scene itself.
- With `--native_x_renderer_antialiasing=dlaa` in a song: `DLAA applied 600 times in 600 frames`, camera vote
  `600 of 600 views voted` (188-189 of 195 offers), object motion 195 draws matched with 194 moved; the note
  highway, the score and the fret board keep their 1:1 pixels.
- The observer (`--native_x_renderer_verify=true`) reports no render-state, vertex-fetch, texture-fetch,
  shader-program or constant mismatches, but it does not yet match GHWT's draw packets to calls
  ("0 of 0 draw calls fully match", `native_x_renderer/src/observer.cpp`): its packet windows do not cover
  the inline draws this engine commits itself, so the report proves absence of state divergence only, not
  agreement of the draw set. The packet tracking it relies on is the `kPackets`/`device` flags in
  `native_x_renderer/include/native_x_renderer/calls.inc`, read in `native_x_renderer/src/state.cpp`
  (`last_device_`); this engine commits its draw packets in `EndVertices`'s inline store of the device's
  `inline_draw_end` (see the offset table above), and that entry point is not hooked, so no draw packet is
  ever read. This is the next thing to fix if the draw stream ever looks wrong.
- Presenting scaling (`native_x_renderer_scaling`) was checked with AMD FSR 1: a 1600x900 window with
  `--native_x_renderer_resolution_scale=1` logs `scaling: 1280x720 into 1600x900 with AMD FSR 1: 1 EASU
  pass, RCAS` and applies it on every frame, and the title and quickplay screens render correctly. The
  filter only has work to do when the internal resolution is below the window: `native_x_renderer_resolution_scale`
  is host pixels per guest pixel and is clamped to at least 1, so a value below 1 is raised to 1, and with
  the default 0 a 1600x900 window fits the 1280x720 image at 1.25x, leaving FSR RCAS at the same size
  (`0 EASU passes`). To exercise an upscale, ask for a window larger than the image at scale 1: a 1920x1080
  window renders 1.5x, and `-RenderScale 1` keeps the image at 1280x720 under it.

### Temporal upscaling and DLAA

`--native_x_renderer_antialiasing=dlaa` (NVIDIA DLSS at the render resolution), `=dlss_quality|dlss_balanced|dlss_performance|dlss_ultra_performance`
(DLSS at a reduced size) and `=fsr_native|fsr_quality|fsr_balanced|fsr_performance|fsr_ultra_performance` (AMD FSR 3.1) run NVIDIA DLSS or
AMD FSR 3.1 on the main 3D view. The game marks no views, so
NativeXRenderer finds it from the draws: it starts at the first 1280x720 draw that writes depth with a
perspective matrix in its vertex constants (the camera from a vote of the draws, D118/D119), and ends at the
`Resolve` from `0x824AE0D0` — the depth copy `sub_824ADED0` makes for the depth of field. That copy is the
game's only output-sized resolve of the view, so the profile sets `upscale_resolve_depth` (D138) and the
upscaler takes the depth surface there while the color is the 1280x720 target the view's draws made.

The glow passes, the composite, the HUD and the note highway are drawn after that resolve and stay outside
the view: they keep their 1:1 pixels and are not reprojected. Verified at 1280x720 in the attract mode and in
a song (DLAA run `ghworldtour_058`): `DLAA applied 600 times in 600 frames`, camera vote `600 of 600 views
voted` (188-189 of 195 offers), 294-658 draw calls a frame. FSR 3.1 takes the same boundary
(`--native_x_renderer_antialiasing=fsr_native`; in a song `ghworldtour_126.log`, see "Interactive verification"). The DLSS *quality* modes
(`dlss_quality|balanced|performance|ultra_performance`, the 3D view drawn at a reduced size, D121) use it too;
boot-checked with DLSS Quality (`ghworldtour_090.log`): `antialiasing: DLSS Quality (experimental, D53): the 3D view
drawn at 853x480 (scale 0.666x0.667), upscaled to 1280x720 by DLSS, with the motion of objects that move on their own;
the main 3D view and the camera's motion found from the draws (D118, D119)` and `[frame rate] script waits in game
frames last as at 60 FPS (vblank at 120 Hz)`. In a song at reduced resolution it ran 18,000 frames in
`ghworldtour_125.log` (`tools/runs/nxr-dlss-quality-song`, see "Interactive verification").

The log says which state a frame is in (D139), one line per change that persists half a second: `3D view: upscaled
at the profile's point 0x824ae0d0` when the upscaler ran on the view, `3D view: found, but its upscale point … did
not run` when the view started and the boundary was rejected (the first rejected `Resolve` logs why), and `3D
view: none` for menus and videos. `tools/scenario.ps1 -Scenario song` fails (exit 5) when a run never logs a view
at all.

### Pipeline lists and pre-compilation

Pipeline storage and list tools are verified against `4156081A.pipelines`:
- Stored pipelines on boot (`ghworldtour_087.log`): `pipeline storage .../4156081A.pipelines: 272 shaders, 306 translations and 345 pipelines from earlier runs; pipeline cache 15104 KB` and `the 345 stored pipelines created in 179 ms after the first draw (their compilation continues on DiligentCore's threads); 345 pipelines with the resource signature, 0 with their own layout (D131)`.
- List generation (`--native_x_renderer_make_pipeline_list`, `ghworldtour_091.log`): `make_pipeline_list: ... 4156081A.pipelines.list from 1 storages: 272 of 272 shaders (122 pixel, 150 vertex of which 0 with their exports linked to a pixel shader; 0 not in the game's files, 0 of them vertex shaders patched beyond their vertex layout and exports), 306 translations and 345 pipelines (0 and 0 left out with their shaders)` (75,195 byte list file).
- Pre-compilation (`--native_x_renderer_prepare_pipelines`, `ghworldtour_093.log`): `prepare_pipelines: list ...: 272 of 272 shaders rebuilt from the game's files (0 not found, 0 with another hash), 306 translations, 345 pipelines` -> `306 translations and 345 pipelines made in 2389 ms (0 failed) with 12 threads; pipeline cache 13522 KB` -> `linked from parts (D132): 247 parts made, 1133 reused, 345 pipelines linked, 0 made whole for want of parts; every whole pipeline compiled after 2792 ms`, progress `done 651 651`. The launcher enables pipeline compilation via `kHasPipelineList = true` in `launcher/game.h`.

### Frame generation and the note highway

Frame generation (`native_x_renderer_frame_generation`, NVIDIA DLSS-G or AMD FSR 3.1 through
`native_x_renderer_frame_generation_provider=auto|nvidia|amd`) is wired: the profile sets `overlay_motion` and
`overlay_motion_adjust = AdjustHighwayMotion` (`src/native_x_renderer_ghworldtour.cpp`). The highway is drawn
after the 3D view's resolve, so its motion comes from its own vertices: the board is the 1600-vertex draw of
`Highway_UI_Default` and the beat lines are the 4-vertex quads of `ImmediateMode_AlphaFade_UI_Default`.

The hashes are the XXH3 of the vertex shaders as the XDK patches them at draw time, read from
`userdata/cache/native_x_renderer/4156081A.pipelines`: board `0x4d61655977a48b60`, beat lines
`0x3f3bf50f2d798c23`. They are not GH Metallica's (`0x2083ccdca7046959`, `0x73eff373b3e69dbd`): the same
`.updb` microcode in GH Metallica's `MaterialLibrary.bin.xen`, with GHWT's vertex-fetch words patched in, hashes to
GH Metallica's values (checked with a scratch tool on both libraries), which ties each pair together.

The frame rate is `ghworldtour_frame_rate` (60, 120, 144, 160, 165, 240 in the launcher). With frame generation on and
a temporal upscaler (DLAA, DLSS, FSR) the app halves it into `video_mode_refresh_rate` and logs `[options] frame
generation: 120 FPS shown, the game at 60`; below 120 it turns frame generation off and says why.

Verified without a desktop session (`ghworldtour_088.log`, `ghworldtour_089.log`, 25 s boot, DLAA,
`--ghworldtour_frame_rate=120 --native_x_renderer_frame_generation=true`, providers `nvidia` and `auto`): the lines
`[options] frame generation: 120 FPS shown, the game at 60`, `frame generation: NVIDIA DLSS-G (requested "nvidia"), a
frame between each two of the game's, with V-Sync (D123, D142)` (`requested "auto"` in the second run, no AMD
fallback) and `frame generation (D123): 0 frames generated, 1 game frames without one; the game's frames 16.70 ms apart`; no FATAL or `[error]`.

In a song (interactive desktop, RTX 4070 Ti, `--ghworldtour_frame_rate=120`): AMD FSR 3.1 frame generation
(`provider=amd`) generated frames for 18,000 frames, while NVIDIA DLSS-G (`provider=auto`) logged an `[error]` at
its first evaluate and generated none; both are in "Interactive verification".

Not verified: whether `AdjustHighwayMotion` matches the highway draws (no log line reports it; the run logs
only the 2D layer's motion, `ghworldtour_128.log`: `26929 draws, 26909 matched with the last frame's` at frame 18000),
how 120 FPS pacing feels (the logs give the game's frame spacing, 16.59-17.55 ms), NVIDIA DLSS-G producing a
frame, and the `provider=auto` fallback to AMD after an NVIDIA failure (`FallbackAfterNvidiaFailure()` runs when
`CreateNvidiaFeature` fails, not when `NGX_VK_EVALUATE_DLSSG` fails: `patches/native_x_renderer-dlssg-and-depth-upscale.patch`
lines 1025, 1081 and 1166-1176). The launcher's frame generation row stays off
(`kFrameGenerationRow`, in the launcher submodule): the option is reached with `--native_x_renderer_frame_generation=true`.

## Interactive verification (2026-11-18)

Six `tools/scenario.ps1 -Scenario song` runs from an interactive desktop, one after another, on an RTX 4070 Ti
(`DXGI adapter: NVIDIA GeForce RTX 4070 Ti (vendor 0x10DE, device 0x2782)`, Vulkan 1.4.357, driver 621.01), 1280x720
window, `--ghworldtour_frame_rate=60` (120 for the two frame generation runs). Each run's screenshots are in
`tools/runs/<dir>` (`*-review.png`; the full-size PNGs are the same frames). A controller was plugged in and played
live during the runs (`ghworldtour_123.log`: `SDL JoystickAdded: "Xbox 360 Controller"`), so the song, the venue and the
camera differ from capture to capture: the screenshots show the same screens and elements, not the same frame.
The `[warning]` lines in these logs are the same few stubs and notices in every run (`IoDismountVolumeByFileHandle`,
`XAudioOverrideSpeakerConfig`, `XamInputSendStayAliveRequest` stubs, `gamecontrollerdb.txt` missing, the Vulkan device
list).

| Run (`tools/runs/<dir>`) | Log (`out/build/win-amd64-release/logs/`) | Exit | Frames | `[error]` / FATAL | What the log shows |
|---|---|---|---|---|---|
| `xenos-d3d12-song` | `ghworldtour_123.log` | 0 | not logged | 0 / 0 | `[options] ... gpu_backend=d3d12 ... native_x_renderer=false ... ghworldtour_frame_rate=60`, `DXGI adapter: NVIDIA GeForce RTX 4070 Ti`, no `D3D12Presenter` line |
| `nxr-smaa-song` | `ghworldtour_124.log` | 1 | 18,000 | 0 / 0 | `antialiasing: SMAA`; `frame 18000: antialiasing (SMAA) applied 600 times in 600 frames`; no `3D view:` line |
| `nxr-dlss-quality-song` | `ghworldtour_125.log` | 0 | 18,000 | 0 / 0 | `DLSS Quality: 853x480 to 1280x720`; `3D view: upscaled at the profile's point 0x824ae0d0`; `frame 18000: DLSS Quality applied 600 times in 600 frames` |
| `nxr-fsr3-native-song` | `ghworldtour_126.log` | 0 | 18,000 | 0 / 0 | `FSR 3.1: AMD's 3.1.4 upscaler, 1280x720 to 1280x720, LDR`; `3D view: upscaled at the profile's point 0x824ae0d0`; `FSR 3.1 Native AA applied 600 times in 600 frames` |
| `nxr-dlaa-dlssg-song` | `ghworldtour_127.log` | 0 | 18,000 | **1** / 0 | `frame generation: NVIDIA DLSS-G (requested "auto")`; `[error] ... NVIDIA DLSS-G evaluate failed (NVSDK_NGX_Result_FAIL_InvalidParameter: 0xBAD00005)`; `0 frames generated` in every interval; `DLAA applied 600 times in 600 frames` |
| `nxr-fsr3-fg-amd-song` | `ghworldtour_128.log` | 0 | 18,000 | 0 / 0 | `frame generation: AMD FSR 3.1 (requested "amd")`; `AMD's 1.1.3 frame interpolation`; 528-600 frames generated per 600 frames after the first interval, 17,105 in all; `FSR 3.1 Native AA applied 600 times in 600 frames` |

In every NativeXRenderer run `frame 600` to `frame 18000` report `0 failed` and `0 without targets` draws for the
sampled intervals (31 samples per log, 677-691 draw calls at most). Run-specific notes:

- **#12, Xenos D3D12 (`ghworldtour_123.log`, `tools/runs/xenos-d3d12-song`).** The Xenos path on `gpu_backend=d3d12`
  ran from the loading screen (`0-title-review.png`) through the Quick Play song list (`2-started-review.png`,
  `HOTEL CALIFORNIA: THE EAGLES, 1976`), the loading tip (`3-confirm-1-review.png`) into a song with the highway, HUD
  and band (`3-confirm-6-review.png`, `4-song-review.png`); the log has no `[error]` or FATAL and no `D3D12Presenter`
  failure. The Xenos path logs nothing when its swap chain succeeds, so the swap chain is shown by the screenshots,
  not by a line. It replaces the earlier boot attempt `ghworldtour_121.log` (`[error] D3D12Presenter: Failed to
  create a swap chain for the HWND`, from a session without an interactive desktop; `ghworldtour_122.log` ran 205 s
  without that error and its screenshot step then failed with `CopyFromScreen: The handle is invalid`).
- **SMAA exit 1 (`ghworldtour_124.log`).** `scenario.ps1` requires a `3D view: (upscaled|found)` line, which is only
  logged when a temporal upscaler is on (SMAA has no view boundary to report). The renderer drew a song the whole
  run (`SMAA applied 600 times in 600 frames` up to frame 18000; `4-song-review.png` is in a song), so the exit code
  says the scenario's check does not apply to SMAA, not that the run failed.
- **DLSS Quality and AMD FSR 3.1 Native in a song (`ghworldtour_125.log`, `ghworldtour_126.log`).** `3D view:
  upscaled` is logged, the highway, the HUD (rock meter, score, multiplier) and the fret buttons are drawn at 1:1
  pixels after the view in `3-confirm-6-review.png` and `4-song-review.png` of both runs; the reduced 853x480 view
  of the DLSS Quality run is upscaled without visible loss of the HUD.
- **#11, AMD FSR 3.1 frame generation in a song (`ghworldtour_128.log`).** Both the upscaler and the interpolation are
  AMD's (`AMD's 3.1.4 upscaler`, `AMD's 1.1.3 frame interpolation`), the game's frames stay 16.59-16.75 ms apart after
  the first interval (20.16 ms in the first, `frame 600`), and the 2D layer's motion matches 97-100 % of its draws
  after the first interval (for example `frame 3000: 32644 draws, 32470 matched with the last frame's`). The highway and the band in
  `4-song-review.png` and `3-confirm-6-review.png` show no tearing or doubled notes in the stills; motion quality
  cannot be judged from stills.
- **#11, NVIDIA DLSS-G in a song (`ghworldtour_127.log`).** Not working: `NGX_VK_CREATE_DLSSG` passes (`frame
  generation: NVIDIA DLSS-G frame interpolation, the view 1280x720, the picture 1280x720 (D142)` at 23:34:40.253) and
  `NGX_VK_EVALUATE_DLSSG` fails once (`[error] ... 0xBAD00005` at 23:34:40.263, logged once by design); frame
  generation stays off for 18,000 frames, with DLAA still applied on 600 of 600 frames and the picture intact
  (`3-confirm-6-review.png`, `4-song-review.png`). `provider=auto` stayed on NVIDIA, as the fallback only covers a
  failed feature creation. `nvngx_dlssg.dll` is not in `out/build/win-amd64-release` (only `nvngx_dlss.dll` and
  `amd_fidelityfx_vk.dll` are); whether the DLL's absence is the cause was not tested.
- **Non-RTX GPUs (#11).** A GTX, AMD or Intel GPU was not available: every run above is on the RTX 4070 Ti
  (`vendorID 0x10DE`). What these runs add for such cards is AMD FSR 3.1 upscaling (`ghworldtour_126.log`) and AMD
  FSR 3.1 frame generation (`ghworldtour_128.log`) working in a song with `provider=amd` on this card; the card-side
  detection and the runtime SMAA fallback on a card without DLSS remain untested on real hardware.

### A/B comparison (#17)

Xenos (`xenos-d3d12-song`) against the five NativeXRenderer runs, from the `*-review.png` stills of each run
(0-title, 1-quickplay, 2-started, 3-confirm-1, 3-confirm-6, 4-song); no video and no pixel diff, and no two stills
show the same frame, so only screens and elements are compared.

| Area | Observed | Class |
|---|---|---|
| Menus and UI (loading screens, Quick Play song list, loading tips, song-failed menu, instruction screen) | Same artwork, text, pills and button prompts on Xenos (`xenos-d3d12-song`: `0-title`, `1-quickplay`, `2-started`, `3-confirm-1`) and NativeXRenderer (`nxr-dlss-quality-song`: `0-title`, `1-quickplay`; `nxr-dlaa-dlssg-song`: `1-quickplay`, the `FAILED SATCH BOOGIE` menu); no missing textures, no wrong colors | no difference |
| Venue and crowd (band, drums, amps, lights, crowd silhouettes, signs) | Present and lit on both paths (`xenos-d3d12-song/4-song`, `nxr-smaa-song/1-quickplay`, `nxr-fsr3-native-song/0-title`, `nxr-fsr3-fg-amd-song/3-confirm-6`); no missing geometry or textures seen | no difference |
| Shaders, depth of field, glow | The game's depth of field blurs the background in close-ups on both paths (`xenos-d3d12-song/3-confirm-6` and `nxr-dlss-quality-song/4-song`, `nxr-fsr3-native-song/3-confirm-6`, `nxr-dlaa-dlssg-song/4-song`, `nxr-fsr3-fg-amd-song/4-song`); colored stage washes (pink, green, blue, red) and light shafts render in both | shared with Xenos emulation (the game's own effect) |
| Note highway and HUD | Board, beat lines, gems, sustains, fret buttons, rock meter, score and multiplier draw on every run and keep their 1:1 pixels, including under DLSS Quality (`nxr-dlss-quality-song/4-song`), FSR Native and the two frame generation runs | no difference |
| Bottom ~10 % of the NativeXRenderer captures | The strip under the highway shows host desktop content (Explorer items, a console line with `x_renderer_frame_generation=false ghworldtour_frame_rate=60 ... trace_interval=60`) in `nxr-smaa-song`, `nxr-dlss-quality-song`, `nxr-fsr3-native-song`, `nxr-dlaa-dlssg-song` and `nxr-fsr3-fg-amd-song`, not in `xenos-d3d12-song`; the console line is the matrix's own command line, which fits another window covering the bottom of the capture rectangle (not confirmed) | capture artifact (a host window over the game), not a renderer artifact |
| Temporal artifacts (ghosting, shimmer, doubled notes) with DLSS Quality, FSR Native, DLAA and frame generation | None visible in the stills; stills cannot show them | not assessed |

No NativeXRenderer-only graphical glitch was observed in the stills of the five runs, and none that Xenos has and the
NativeXRenderer runs lack. The README's "minor remaining graphical glitches" is therefore not itemized by these runs.
