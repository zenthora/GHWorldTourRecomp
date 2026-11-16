# 0004: Rewind Codegen Manifest Timestamp After Generation

Status: accepted

## Context

During code generation, `rexglue codegen` updates `sdk_version` inside `ghworldtour_manifest.toml` (`WriteSdkVersionStamp`) *after* writing `generated/default/codegen.build.stamp`. Because Ninja compares input and output modification times, this leaves the manifest newer than the stamp and causes every subsequent build to rerun full code generation.

## Decision

Add a post-codegen CMake step (`cmake/refresh_codegen_stamp.cmake`) that sets `ghworldtour_manifest.toml`'s modification time to one second before `codegen.build.stamp`, leaving the stamp's own timestamp untouched for Ninja's deps log.

## Considered Options

- **Modify the SDK's codegen tool via another patch**: cleaner long-term, but requires carrying another SDK diff and modifying upstream build tooling behavior.
- **Touch `codegen.build.stamp` forward**: breaks Ninja's deps log consistency because Ninja records the stamp's timestamp during the build edge.
- **Rewind `ghworldtour_manifest.toml` by 1 second locally**: keeps the workaround isolated to project CMake and preserves idempotent incremental builds verified by `tools/check.ps1 -Build`.

## Consequences

- `ghworldtour_manifest.toml` has its filesystem mtime adjusted during builds (without changing file contents or git diff).
- Removing this workaround without an upstream SDK fix would reintroduce multi-minute codegen reruns on every incremental build.
