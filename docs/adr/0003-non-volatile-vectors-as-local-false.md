# 0003: Keep Non-Volatile Vector Registers in PPCContext

Status: accepted

## Context

In `ghworldtour_functions.toml`, scalar non-volatile registers and condition/control registers are promoted to C++ local variables (`non_volatile_as_local = true`) so the host compiler can keep them in host registers. However, *Guitar Hero: World Tour*'s compiled PowerPC code passes values across function boundaries in non-volatile vector registers (such as `v92` set before calling `sub_826862F0` and read without initialization by its callees) outside the standard ABI.

## Decision

Set `non_volatile_vectors_as_local = false` in `ghworldtour_functions.toml` so non-volatile vector registers remain fields in `PPCContext` and are saved/restored through `__savevmx_N` / `__restvmx_N` helpers.

## Considered Options

- **Enable `non_volatile_vectors_as_local = true` globally**: reduces context memory traffic, but silently leaves cross-function non-ABI vector parameters uninitialized and corrupts gameplay/math state.
- **Keep `non_volatile_vectors_as_local = false`**: preserves exact cross-call vector state for non-ABI callees while keeping scalar non-volatile registers as fast locals.

## Consequences

- Any future codegen regeneration must preserve `non_volatile_vectors_as_local = false` unless per-function vector-sharing overrides are introduced and exhaustively audited.
