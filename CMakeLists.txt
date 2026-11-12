# GHWorldTourRecomp - static recompilation of Guitar Hero: World Tour (Xbox 360), built on the ReXGlue SDK and drawn by
# the SDK's Xenos emulation.
#
# The ReXGlue SDK (the recomp fork, ElGuslml/rexglue-sdk branch recomp) is found in this order:
#   1. REXSDK_DIR, when set (a rexglue-sdk source tree; CMake builds it with the project).
#   2. thirdparty/rexglue-sdk, when that submodule is present.
#   3. GHWORLDTOUR_SDK_INSTALL_DIR, or a sibling checkout's installed SDK
#      (../rexglue-sdk-recomp/out/install/win-amd64, then ../rexglue-sdk), found with find_package.
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(ghworldtour LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Same CPU baseline as the official SDK builds (its win-amd64 preset): x86-64-v2, i.e. SSE4.2 and
# POPCNT on top of the SSSE3/SSE4.1 the SDK code requires. Not -march=native, so the binaries run on
# any x86-64-v2 CPU.
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
    add_compile_options(-march=x86-64-v2)
endif()

# Locate the SDK. NativeXRenderer compiles the SDK's graphics sources (the SPIR-V translator among them)
# in process, and an installed SDK package does not carry those sources, so the recomp fork's source tree
# is used: REXSDK_DIR when set, thirdparty/rexglue-sdk when present, or the sibling rexglue-sdk-recomp.
if(NOT REXSDK_DIR AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/rexglue-sdk/CMakeLists.txt")
    set(REXSDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/rexglue-sdk" CACHE PATH
        "Path to the rexglue-sdk source tree" FORCE)
endif()
if(NOT REXSDK_DIR)
    set(GHWORLDTOUR_SDK_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rexglue-sdk-recomp" CACHE PATH
        "The rexglue-sdk recomp source tree (built with the game and NativeXRenderer)")
    if(EXISTS "${GHWORLDTOUR_SDK_SOURCE_DIR}/RECOMP.md")
        set(REXSDK_DIR "${GHWORLDTOUR_SDK_SOURCE_DIR}" CACHE PATH
            "Path to the rexglue-sdk source tree" FORCE)
    endif()
endif()
if(NOT REXSDK_DIR OR NOT EXISTS "${REXSDK_DIR}/RECOMP.md")
    message(FATAL_ERROR
        "The rexglue-sdk recomp source tree was not found. Clone ElGuslml/rexglue-sdk (branch recomp) "
        "next to this project as rexglue-sdk-recomp, or set GHWORLDTOUR_SDK_SOURCE_DIR / REXSDK_DIR.")
endif()
message(STATUS "Using the ReXGlue SDK source tree at ${REXSDK_DIR}")

# GPU backends for a source build of the SDK (an installed SDK carries the backends it was built with).
if(WIN32)
    set(REXGLUE_USE_D3D12 ON CACHE BOOL "Enable the D3D12 graphics backend")
endif()
set(REXGLUE_USE_VULKAN ON CACHE BOOL "Enable the Vulkan graphics backend")

include(generated/rexglue.cmake)

# The codegen stamps the manifest's sdk_version after writing codegen.build.stamp, which leaves the
# manifest newer than the stamp and would make Ninja rerun the codegen on every build. Move the
# manifest's timestamp back (not the stamp's: the deps log records the stamp's mtime). The marker
# makes this run only after a codegen run.
set(GHWORLDTOUR_CODEGEN_FIXED "${CMAKE_CURRENT_SOURCE_DIR}/generated/default/codegen.manifest.fixed")
add_custom_command(
    OUTPUT "${GHWORLDTOUR_CODEGEN_FIXED}"
    COMMAND "${CMAKE_COMMAND}"
            "-DMANIFEST=${CMAKE_CURRENT_SOURCE_DIR}/ghworldtour_manifest.toml"
            "-DSTAMP=${CMAKE_CURRENT_SOURCE_DIR}/generated/default/codegen.build.stamp"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/refresh_codegen_stamp.cmake"
    COMMAND "${CMAKE_COMMAND}" -E touch "${GHWORLDTOUR_CODEGEN_FIXED}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/generated/default/codegen.build.stamp"
    COMMENT "Refreshing the codegen stamp"
    VERBATIM)
add_custom_target(ghworldtour_codegen_stamp_fix DEPENDS "${GHWORLDTOUR_CODEGEN_FIXED}")

# The first build of a fresh tree runs the codegen, which writes generated/default/sources.cmake;
# CMake has to configure again to pick up the generated sources (otherwise the link fails with
# PPCImageConfig). A marker file holds the sources.cmake this configure saw and is a configure
# dependency; it is refreshed with copy_if_different after the codegen, so it only changes (and
# triggers a new configure) when the list of generated sources changes. Ninja brings configure
# dependencies up to date before building anything else, so the first build runs the codegen,
# configures again and goes on within the same command.
set(GHWORLDTOUR_CODEGEN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/generated/default")
set(GHWORLDTOUR_SOURCES_MARKER "${GHWORLDTOUR_CODEGEN_DIR}/sources.cmake.configured")
if(EXISTS "${GHWORLDTOUR_CODEGEN_DIR}/sources.cmake")
    file(COPY_FILE "${GHWORLDTOUR_CODEGEN_DIR}/sources.cmake" "${GHWORLDTOUR_SOURCES_MARKER}" ONLY_IF_DIFFERENT)
elseif(NOT EXISTS "${GHWORLDTOUR_SOURCES_MARKER}")
    file(WRITE "${GHWORLDTOUR_SOURCES_MARKER}" "")
endif()
add_custom_command(
    OUTPUT "${GHWORLDTOUR_SOURCES_MARKER}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${GHWORLDTOUR_CODEGEN_DIR}/sources.cmake" "${GHWORLDTOUR_SOURCES_MARKER}"
    DEPENDS "${GHWORLDTOUR_CODEGEN_DIR}/codegen.build.stamp"
    COMMENT "Checking the list of generated sources"
    VERBATIM)
add_custom_target(ghworldtour_sources_marker DEPENDS "${GHWORLDTOUR_SOURCES_MARKER}")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GHWORLDTOUR_SOURCES_MARKER}")

# Sources
set(GHWORLDTOUR_SOURCES
    src/main.cpp
    src/native_x_renderer_ghworldtour.cpp
    src/startup.cpp
    src/keyboard.cpp
)

if(WIN32)
    add_executable(ghworldtour WIN32 ${GHWORLDTOUR_SOURCES})
else()
    add_executable(ghworldtour ${GHWORLDTOUR_SOURCES})
endif()

rexglue_setup_target(ghworldtour GPU_PLUGINS xenos)
add_dependencies(ghworldtour ghworldtour_sources_marker ghworldtour_codegen_stamp_fix)

# NativeXRenderer: the native renderer (native_x_renderer/README.md). The game side (hooks and profile)
# is src/native_x_renderer_ghworldtour.cpp; the game draws on the Xenos path while native_x_renderer is
# off. The library builds the SDK's graphics sources for the SPIR-V translator in process.
add_subdirectory(native_x_renderer)
target_link_libraries(ghworldtour PRIVATE native_x_renderer)
# AMD FidelityFX's Vulkan runtime next to the executable (DLSS comes from the SDK's copy_dlss_dlls).
native_x_renderer_copy_runtime(ghworldtour)

# The target and the app keep the short name "ghworldtour" (ghworldtour.toml, logs\ghworldtour_NNN.log);
# only the executable gets a descriptive name.
set_target_properties(ghworldtour PROPERTIES OUTPUT_NAME "GHWorldTourRecomp")

# Game files: assets/ next to GHWorldTourRecomp.exe (release layout) or, if absent, the repository's assets/.
target_compile_definitions(ghworldtour PRIVATE
    GHWORLDTOUR_DEFAULT_GAME_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/assets")

# Windows resources: file properties (res/version.h) and the icon, res/icon.ico, when it exists.
if(WIN32)
    target_sources(ghworldtour PRIVATE res/game.rc)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/res/icon.ico")
        target_compile_definitions(ghworldtour PRIVATE RECOMP_HAS_ICON)
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/res/icon.ico")
    endif()
endif()

# RecompLauncher: "GH World Tour Launcher.exe", next to the game. Its code is the recomp_launcher/
# submodule; launcher/ holds this game's profile, texts, colors and art.
set(RECOMP_LAUNCHER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/recomp_launcher" CACHE PATH "The RecompLauncher tree")
set(RECOMP_LAUNCHER_SDK_DIR "" CACHE PATH
    "The rexglue-sdk tree the launcher takes Dear ImGui, SDL3 and toml++ from")
if(NOT RECOMP_LAUNCHER_SDK_DIR)
    foreach(candidate
            "${CMAKE_CURRENT_SOURCE_DIR}/../rexglue-sdk-recomp"
            "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/rexglue-sdk")
        if(EXISTS "${candidate}/thirdparty/imgui/imgui.cpp")
            set(RECOMP_LAUNCHER_SDK_DIR "${candidate}" CACHE PATH
                "The rexglue-sdk tree the launcher takes Dear ImGui, SDL3 and toml++ from" FORCE)
            break()
        endif()
    endforeach()
endif()
if(NOT EXISTS "${RECOMP_LAUNCHER_DIR}/RecompLauncher.cmake" OR
   NOT EXISTS "${RECOMP_LAUNCHER_SDK_DIR}/thirdparty/imgui/imgui.cpp")
    message(WARNING "RecompLauncher or its SDK tree not found: the launcher is not built")
else()
    # The SDK package exports SDL3 but not Dear ImGui; RecompLauncher links an "imgui" target.
    if(NOT TARGET imgui)
        add_library(imgui STATIC
            "${RECOMP_LAUNCHER_SDK_DIR}/thirdparty/imgui/imgui.cpp"
            "${RECOMP_LAUNCHER_SDK_DIR}/thirdparty/imgui/imgui_draw.cpp"
            "${RECOMP_LAUNCHER_SDK_DIR}/thirdparty/imgui/imgui_tables.cpp"
            "${RECOMP_LAUNCHER_SDK_DIR}/thirdparty/imgui/imgui_widgets.cpp")
        target_include_directories(imgui PUBLIC "${RECOMP_LAUNCHER_SDK_DIR}/thirdparty/imgui")
    endif()
    if(NOT TARGET SDL3::SDL3 AND TARGET SDL3::SDL3-static)
        add_library(SDL3::SDL3 ALIAS SDL3::SDL3-static)
    endif()

    # RecompLauncher stays a clean checkout: this game's defaults (auto-strum on, V-Sync off; the
    # kVsyncDefault / kKeyboardTapDefault / kGamepadTapDefault constants in launcher/game.h) come from a
    # tracked patch, applied here once. A changed upstream that the patch no longer fits fails loudly
    # instead of silently building the wrong defaults.
    set(GHWT_LAUNCHER_PATCH
        "${CMAKE_CURRENT_SOURCE_DIR}/patches/recomp_launcher-3.14.0-game-defaults.patch")
    if(EXISTS "${GHWT_LAUNCHER_PATCH}" AND EXISTS "${RECOMP_LAUNCHER_DIR}/.git")
        execute_process(
            COMMAND git -C "${RECOMP_LAUNCHER_DIR}" apply --reverse --check "${GHWT_LAUNCHER_PATCH}"
            RESULT_VARIABLE GHWT_PATCH_APPLIED OUTPUT_QUIET ERROR_QUIET)
        if(NOT GHWT_PATCH_APPLIED EQUAL 0)
            execute_process(
                COMMAND git -C "${RECOMP_LAUNCHER_DIR}" apply "${GHWT_LAUNCHER_PATCH}"
                RESULT_VARIABLE GHWT_PATCH_RESULT
                OUTPUT_VARIABLE GHWT_PATCH_OUTPUT ERROR_VARIABLE GHWT_PATCH_ERROR)
            if(NOT GHWT_PATCH_RESULT EQUAL 0)
                message(FATAL_ERROR
                    "Could not apply ${GHWT_LAUNCHER_PATCH} to recomp_launcher:\n${GHWT_PATCH_ERROR}")
            endif()
            message(STATUS "Applied the GHWT game-defaults patch to recomp_launcher")
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GHWT_LAUNCHER_PATCH}")
    endif()

    include("${RECOMP_LAUNCHER_DIR}/RecompLauncher.cmake")
    recomp_launcher_add(ghworldtour_launcher
        OUTPUT_NAME "GH World Tour Launcher"
        GAME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/launcher"
        RC "${CMAKE_CURRENT_SOURCE_DIR}/res/launcher.rc"
        SDK_DIR "${RECOMP_LAUNCHER_SDK_DIR}"
        INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/src" "${CMAKE_CURRENT_SOURCE_DIR}/res"
        DEFAULT_GAME_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/assets")
    if(WIN32 AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/res/icon.ico")
        target_compile_definitions(ghworldtour_launcher PRIVATE RECOMP_HAS_ICON)
    endif()

    # The game reads which launcher profile it runs with (src/startup.cpp).
    recomp_launcher_add_profiles(ghworldtour SDK_DIR "${RECOMP_LAUNCHER_SDK_DIR}")
endif()
