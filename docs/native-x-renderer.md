# NativeXRenderer in GHWorldTourRecomp

The game's D3D library is replaced by [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer) when
`native_x_renderer = true`; the SDK's Xenos path stays the default and the fallback. The game side is
`src/native_x_renderer_ghworldtour.cpp`: one hook per D3D entry point and a `Profile` with the XDK 2.0.7645
device layout. The library is the `native_x_renderer/` submodule.

## Where the library is

GHWT was built with XDK **2.0.7645**. Its D3D library is linked from **0x821B06F0** (the XGraphics cache
helpers) to **0x821C4040** (Present); the game engine follows. Each function has the same body as in GH
Metallica's XDK 2.0.7978 library (the closest public recomp, `C:\Recomp Library\ghmetalrecomp\assets`), so
the entry points were found with `tools/find_equivalent.py` against a reference codegen of that disc and
checked by reading the generated code. The whole library sits about `0xD300` higher than Metallica's, and
the current objects (index buffer, render targets, depth, vertex buffers, textures, viewport) another
8 bytes lower in the device; everything else (dirty masks, constants, register groups, tiling, command
buffer, inline draw end) is at Metallica's offsets.

Reference codegen (not tracked):

```powershell
# out/ref-ghm/ghm_manifest.toml points at C:/Recomp Library/ghmetalrecomp/assets/default.xex
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
profile names the compressed file for the pipeline list. No `4156081A.pipelines.list` is shipped yet, so the
launcher does not offer "Compiling shaders" (`kHasPipelineList` false in `launcher/game.h`); shaders are
compiled on first use and cached in `<user data>/cache/native_x_renderer`.

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
   is `native_x_renderer_antialiasing=smaa|fxaa`; the upscalers take the view boundary above
   (`native_x_renderer_upscaling=dlss|fsr3`). The launcher drives all of it through `ghworldtour_options.toml`.

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

`--native_x_renderer_antialiasing=dlaa` (or `=dlss` with `--native_x_renderer_upscaling=dlss`, and
`=fsr_native` with `fsr3`) runs NVIDIA DLSS or AMD FSR 3.1 on the main 3D view. The game marks no views, so
NativeXRenderer finds it from the draws: it starts at the first 1280x720 draw that writes depth with a
perspective matrix in its vertex constants (the camera from a vote of the draws, D118/D119), and ends at the
`Resolve` from `0x824AE0D0` — the depth copy `sub_824ADED0` makes for the depth of field. That copy is the
game's only output-sized resolve of the view, so the profile sets `upscale_resolve_depth` (D138) and the
upscaler takes the depth surface there while the color is the 1280x720 target the view's draws made.

The glow passes, the composite, the HUD and the note highway are drawn after that resolve and stay outside
the view: they keep their 1:1 pixels and are not reprojected. Verified at 1280x720 in the attract mode and in
a song (DLAA run `ghworldtour_058`): `DLAA applied 600 times in 600 frames`, camera vote `600 of 600 views
voted` (188-189 of 195 offers), 294-658 draw calls a frame. FSR 3.1 takes the same boundary
(`--native_x_renderer_antialiasing=fsr_native --native_x_renderer_upscaling=fsr3`). The DLSS *quality* modes
(`dlss_quality|balanced|performance|ultra_performance`, the 3D view drawn at a reduced size, D121) use it too
but were not measured; they are the library's experimental path (D53).

The log says which state a frame is in (D139), one line per change that persists half a second: `3D view: upscaled
at the profile's point 0x824ae0d0` when the upscaler ran on the view, `3D view: found, but its upscale point … did
not run` when the view started and the boundary was rejected (the first rejected `Resolve` logs why), and `3D
view: none` for menus and videos. `tools/scenario.ps1 -Scenario song` fails (exit 5) when a run never logs a view
at all.

Frame generation (`native_x_renderer_frame_generation`) is not wired for GHWT: the profile does not set
`overlay_motion`, so the HUD-less picture route would be needed, and GHWT has no output-sized color copy to
take it from. The launcher's frame generation row stays off (`kFrameGenerationRow`).
