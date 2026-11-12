// ghworldtour - NativeXRenderer for Guitar Hero: World Tour (see
// native_x_renderer_ghworldtour.cpp).

#pragma once

#include <native_x_renderer/native_x_renderer.h>

namespace ghworldtour {

// Guitar Hero: World Tour's D3D library: the XDK 2.0.7645 device and object layouts.
const native_x_renderer::Profile& NativeXRendererProfile();

}  // namespace ghworldtour
