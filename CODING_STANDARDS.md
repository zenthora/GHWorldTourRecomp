# Coding standards (review)

Rules a reviewer applies to a diff. Only what no guardrail can decide: `tools/check.ps1` covers formatting,
whitespace, the launcher patch and the submodule's commit state.

## Verified claims cite the evidence

A claim that something works names what showed it: the log line (and run id, or `tools/runs/<dir>`) or the
command output. "SMAA is applied on 100 % of frames" without the line is how a wrong boundary survived in
`docs/native-x-renderer.md` while the antialiasing was running on a depth copy. When a claim stops being true,
update or delete it in the same change.

## A description lives once, next to what it describes

Behaviour, addresses and offsets are commented beside the field or function that uses them, not repeated at
the top of the file. `src/native_x_renderer_ghworldtour.cpp` had two scene-resolve descriptions (`0x8250F8E4`
and `0x824AE0D0`) and the stale one cost a trace to disprove. One source of truth; cross-reference by name.

## The library keeps its own style

`native_x_renderer/` has no `.clang-format` and does not follow the SDK's: 120 columns, short statements on
one line, and the surrounding file's comments. Do not reformat it to this repository's style; match the file
you are in. Its decisions go in `native_x_renderer/docs/decisions.md` (D-numbers), and its changes are
committed in the submodule before the parent.
