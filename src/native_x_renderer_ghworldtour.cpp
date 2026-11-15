// NativeXRenderer's hooks and profile for Guitar Hero: World Tour (4156081A, XDK 2.0.7645).
//
// The D3D library sits where the Neversoft engine linked it: 0x821B06F0 (its XGraphics helpers)
// through 0x821D1418 (Present in GH Metallica; here 0x821C4040). Its functions have the same bodies
// as GH Metallica's XDK 2.0.7978 library, so they were found with tools/find_equivalent.py against
// a reference codegen of that disc and then checked by hand: the register shadow, the constants,
// the command buffer and the tiling records are at the same offsets as in Metallica, while the
// current objects (index buffer, render targets, depth, vertex buffers, textures) moved down by 8
// bytes.
//
// The layout below is the GHWT one, not Metallica's:
//   textures +12544 (12552), index buffer +12436 (12444), render targets +12440 (12448),
//   depth stencil +12456 (12464), viewport +12648 (12656), scissor +12676 (12684),
//   pixel/vertex shader +12692/+12696 (12700/12704), tile count/rects +12748/+12752 (12756/12760),
//   vertex declaration +11820 (11824), flagged stream strides +11832 (11840),
//   predication mask +12708 (12716).
// The constants, dirty masks, register groups, fence counter, write-back block, flags, tile state,
// command buffer and inline draw end (+13444) are unchanged.

#include "native_x_renderer_ghworldtour.h"

#include <algorithm>
#include <cstdint>
#include <vector>

#include <native_x_renderer/hooks.h>

namespace ghworldtour {
namespace {

// Runtime-patched vertex shader XXH3 hashes from 4156081A.pipelines (GHWT XDK compilation of
// Highway_UI_Default.updb and ImmediateMode_AlphaFade_UI_Default.updb).
constexpr uint64_t kBoardShader = 0x4d61655977a48b60ull;
constexpr uint64_t kBeatLineShader = 0x3f3bf50f2d798c23ull;

void AdjustHighwayMotion(native_x_renderer::OverlayDraw* draws, size_t count) {
  struct Line {
    float y, y_last, left, right;
  };
  static std::vector<Line> lines;
  lines.clear();
  for (size_t d = 0; d < count; ++d) {
    const native_x_renderer::OverlayDraw& draw = draws[d];
    if (draw.vertex_shader != kBeatLineShader || !draw.matched || draw.vertex_count != 4) {
      continue;
    }
    Line line{0.0f, 0.0f, draw.positions[0], draw.positions[0]};
    for (uint32_t i = 0; i < 4; ++i) {
      line.y += draw.positions[2 * i + 1] * 0.25f;
      line.y_last += draw.previous[2 * i + 1] * 0.25f;
      line.left = std::min(line.left, draw.positions[2 * i]);
      line.right = std::max(line.right, draw.positions[2 * i]);
    }
    // A line comes down the screen; one matched with another (a new line at the top) is left out.
    if (line.y_last < line.y && line.right - line.left > 1.0f) {
      lines.push_back(line);
    }
  }
  if (lines.size() < 2) {
    return;
  }
  std::sort(lines.begin(), lines.end(), [](const Line& a, const Line& b) { return a.y < b.y; });
  // Interpolate between the surrounding beat lines, or extrapolate from the nearest two past ends.
  auto at = [&](float y, float Line::* field) {
    size_t i = 1;
    while (i + 1 < lines.size() && lines[i].y < y) {
      ++i;
    }
    const Line& a = lines[i - 1];
    const Line& b = lines[i];
    float t = b.y != a.y ? (y - a.y) / (b.y - a.y) : 0.0f;
    return a.*field + t * (b.*field - a.*field);
  };
  for (size_t d = 0; d < count; ++d) {
    native_x_renderer::OverlayDraw& draw = draws[d];
    if (draw.vertex_shader != kBoardShader) {
      continue;
    }
    for (uint32_t i = 0; i < draw.vertex_count; ++i) {
      float x = draw.positions[2 * i];
      float y = draw.positions[2 * i + 1];
      float y_last = at(y, &Line::y_last);
      float left = at(y, &Line::left);
      float right = at(y, &Line::right);
      float across = right - left > 1.0f ? (x - left) / (right - left) : 0.5f;
      float left_last = at(y_last, &Line::left);
      float right_last = at(y_last, &Line::right);
      draw.previous[2 * i] = left_last + across * (right_last - left_last);
      draw.previous[2 * i + 1] = y_last;
    }
  }
}

using native_x_renderer::Profile;

const char* const kShaderFiles[] = {
    "DATA/COMPRESSED/FXFILES/MaterialLibrary.bin.xen",
};

Profile MakeProfile() {
  Profile p;
  p.game = "Guitar Hero: World Tour (4156081A)";
  p.xdk_version = "2.0.7645";
  p.output_width = 1280;
  p.output_height = 720;

  // The main 3D view's only output-sized copy: sub_824ADED0 resolves its 1280x720 depth into the
  // guest texture at 0xABA26C00 (Resolve's return address 0x824AE0D0). The glow passes then sample
  // it at 320x180, the composite draws it back, and the HUD and note highway come after it, outside
  // the view. Both boundaries below name that one Resolve: the antialiasing (SMAA or FXAA acts on
  // the depth copy; the color is copied only at 640x360, through the 4x MSAA surface the
  // post-processing downsamples with, so there is no output-sized color copy) and the upscalers
  // (D138).
  p.scene_resolve_caller = 0x824AE0D0;
  p.upscale_resolve_caller = 0x824AE0D0;
  p.upscale_resolve_depth = true;
  p.unscaled_screen_fractions = true;
  p.overlay_motion = true;
  p.overlay_motion_adjust = AdjustHighwayMotion;

  p.title_id = 0x4156081A;
  p.shader_files = kShaderFiles;
  p.shader_file_count = 1;

  auto& d = p.device;
  d.vs_constants_dirty = 0;
  d.ps_constants_dirty = 8;
  d.fetch_constants_dirty = 24;
  d.fetch_dirty_slot0_bit = 31;
  d.command_buffer_write = 48;
  d.fetch_constants = 1152;
  d.vs_float_constants = 1920;
  d.ps_float_constants = 6016;
  d.bool_loop_constants = 10112;

  d.register_groups = {{
      {10368, 0x2000, 16},
      {10444, 0x2100, 21},
      {10528, 0x2180, 5},
      {10548, 0x2200, 12},
      {10596, 0x2280, 21},
      {10680, 0x2300, 38},
      {10832, 0x2380, 8},
      {0, 0, 0},
  }};

  d.fence_counter = 10908;
  d.write_back_block = 10896;
  d.flags = 10940;

  d.vertex_declaration = 11820;
  d.index_buffer = 12436;
  d.render_targets = 12440;
  d.depth_stencil = 12456;
  d.vertex_buffers = 12460;
  d.textures = 12544;
  d.viewport = 12648;
  d.pixel_shader = 12692;
  d.vertex_shader = 12696;
  d.predication_mask = 12708;
  d.tile_count = 12748;
  d.tile_rects = 12752;
  d.inline_draw_end = 13444;

  auto& o = p.objects;
  o.texture_fetch = 28;
  o.surface_info = 24;
  o.surface_color_depth_info = 28;
  o.surface_size = 36;
  o.surface_width_minus_one = {18, 14};
  o.surface_height_minus_one = {3, 15};
  o.buffer_address = 24;
  o.buffer_size = 28;

  return p;
}

}  // namespace

const Profile& NativeXRendererProfile() {
  static const Profile profile = MakeProfile();
  return profile;
}

}  // namespace ghworldtour

// --- The D3D entry points (calls.inc's ids, GHWT addresses) ---

// Draws.
NATIVE_X_RENDERER_HOOK(821B4B28, DrawIndexedVertices)
NATIVE_X_RENDERER_HOOK(821B4738, DrawVertices)
NATIVE_X_RENDERER_HOOK(821B4130, DrawVerticesUP)
NATIVE_X_RENDERER_HOOK(821B3C88, BeginVertices)
NATIVE_X_RENDERER_HOOK(821B4178, BeginIndexedVertices)

// Render targets, depth, clears and resolves.
NATIVE_X_RENDERER_HOOK(821B8008, SetRenderTarget)
NATIVE_X_RENDERER_HOOK(821B8350, SetDepthStencilSurface)
NATIVE_X_RENDERER_HOOK(821CEE18, Clear)
NATIVE_X_RENDERER_HOOK(821CECF0, ClearF)
NATIVE_X_RENDERER_HOOK(821CF658, Resolve)
NATIVE_X_RENDERER_HOOK(821C2FE0, BeginTiling)
NATIVE_X_RENDERER_HOOK(821C3360, EndTiling)
NATIVE_X_RENDERER_HOOK(821C2E70, SetPredication)
NATIVE_X_RENDERER_HOOK(821B7ED8, SetViewport)
NATIVE_X_RENDERER_HOOK(821B7538, SetScissorRect)

// Shaders, declarations and stream sources.
NATIVE_X_RENDERER_HOOK(821B3778, SetVertexShader)
NATIVE_X_RENDERER_HOOK(821B34C0, SetPixelShader)
NATIVE_X_RENDERER_HOOK(821B3948, SetVertexDeclaration)
NATIVE_X_RENDERER_HOOK(821B76A8, SetStreamSource)
NATIVE_X_RENDERER_HOOK(821B7850, SetIndices)
NATIVE_X_RENDERER_HOOK(821B26D8, SetTexture)
NATIVE_X_RENDERER_HOOK(821B3220, SetVertexShaderConstantF)
NATIVE_X_RENDERER_HOOK(821B3300, SetPixelShaderConstantF)

// Resource locking.
NATIVE_X_RENDERER_HOOK(821B9720, VertexBufferLock)
NATIVE_X_RENDERER_HOOK(821B9770, VertexBufferUnlock)
NATIVE_X_RENDERER_HOOK(821B9780, IndexBufferLock)
NATIVE_X_RENDERER_HOOK(821B97C8, IndexBufferUnlock)
NATIVE_X_RENDERER_HOOK(821B06F0, TextureUnlock)
NATIVE_X_RENDERER_HOOK(821C2C98, FlushCpuRange)

// Command buffers, queries and the frame.
NATIVE_X_RENDERER_HOOK(821BBE50, KickSegment)
NATIVE_X_RENDERER_HOOK(821BBB70, NewSegment)
NATIVE_X_RENDERER_HOOK(821B3AD8, SetShaderGPRAllocation)
NATIVE_X_RENDERER_HOOK(821BF150, QueryIssue)
NATIVE_X_RENDERER_HOOK(821BF3D8, QueryGetData)
NATIVE_X_RENDERER_HOOK(821C3B50, Swap)
NATIVE_X_RENDERER_HOOK(821C4040, Present)
