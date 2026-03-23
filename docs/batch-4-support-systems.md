# Patchwork Post Batch 4 Support Systems

Last updated: March 23, 2026

Batch 4 makes the Godot runtime safer for a public-facing demo by upgrading the player-support layer around the core puzzles.

## Delivered

- Progressive three-stage hint UX:
  - reframe hint
  - mechanic hint
  - guided opening text
  - guided opening replay button after tier 3
- Controller-first menu pass:
  - board focus starts on the puzzle view
  - D-Pad drives menu focus
  - `A` confirms
  - `B` cancels or resets depending on focus context
  - shoulder buttons cycle focus groups
- Saved control remapping for gameplay actions:
  - separate keyboard and controller bindings
  - runtime capture flow
  - reset-to-default support
- Stronger no-color-only cues:
  - layer chips include explicit active text
  - route buttons include role and state text
  - support cards surface Steam/save state in text, not only icons or color
- Steam/demo support scaffolding:
  - save profile metadata for build channel and content version
  - demo-to-full carryover path
  - pending achievement sync queue
  - Steam runtime bridge stub
  - Steam Input reference manifest at [patchwork-post-steam-input.json](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/steam/input/patchwork-post-steam-input.json)
- Public-shell safety:
  - developer authoring tools are hidden by default
  - developer tools require a debug build toggle

## Save And Build Rules

- Full-build saves live at `user://profiles/full/patchwork-post-save-v2.json`
- Demo saves live at `user://profiles/demo/patchwork-post-save-v2.json`
- Demo carryover exports to `user://profiles/shared/patchwork-post-demo-carryover.json`
- Legacy v1 saves are still imported when present
- Full builds automatically import demo carryover if no full save exists yet

## Controller Layout

Default controller layout:

- Left stick: puzzle movement
- `A`: wait / confirm
- `B`: reset room / cancel
- `X`: switch layer
- `Y`: transfer parcel
- `LB`: undo / previous focus group
- `RB`: redo / next focus group
- `LT`: previous room
- `RT`: next room
- D-Pad: UI navigation
- `Start`: replay route

## Current Steam Scope

This batch does not ship a live Steamworks integration plugin yet. Instead it establishes the runtime seams needed for Batch 5 and Batch 7:

- achievement unlock queue
- cloud-save-friendly save paths and channel metadata
- Steam Input action naming and manifest reference
- demo-to-full compatibility rules

When a Steam plugin is added later, the bridge in [steam_bridge.gd](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/godot/scripts/platform/steam_bridge.gd) is the intended integration seam.

## Automated Coverage

Batch 4 adds regression coverage for:

- demo save carryover import
- guided opening hint playback
- remap flow persistence
- Steam/save status UI creation
- developer tools hidden-by-default behavior
