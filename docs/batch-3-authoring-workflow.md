# Patchwork Post Batch 3 Authoring Workflow

Last updated: March 22, 2026

Batch 3 turns the Godot runtime into the internal content-production surface for Patchwork Post. The goal is to let designers build, validate, preview, and save rooms without hand-editing raw JSON for normal iteration.

## Included Tools

- `Room Browser`: browse rooms grouped by district and load any saved room into the editor.
- `Visual Layer Editor`: paint tiles, place starts, entities, switches, and doors directly on the grid.
- `Structure Controls`: resize the room, rename the selected layer, and add or remove a layer within the v1 two-to-three-layer limit.
- `Room Inspector`: edit title, objective, blurb, intro text, hints, balance metadata, and interactable properties.
- `Validation Panel`: review errors, warnings, and metrics for the current draft.
- `Balance Browser`: compare difficulty targets, expected solve time, validation pressure, and playtest attempts across the campaign.
- `Playtest Browser`: review local internal telemetry for attempts, solves, time, hints, and resets.

## Authoring Loop

1. Open the Godot runtime and pick a room from the left-hand browser, or create a new draft.
2. Use the structure controls to set room size and layer count before deep placement work.
3. Paint tiles in the active layer, then place the player start, entities, switches, and doors.
4. Fill in room metadata and all three hint tiers.
5. Add balance metadata:
   - intended lesson
   - target difficulty from 1 to 5
   - expected solve minutes
   - common misunderstanding
6. Watch the validation panel until structural errors are gone and warnings are understood.
7. Use preview or load-in-play-view to test the room in the shipping runtime.
8. Save the draft to update `data/source/campaign.json` and regenerate `godot/data/generated/campaign_index.json`.

## Validation Rules

The validator currently checks:

- layer count, dimensions, and supported tiles
- start position bounds and wall placement
- goal presence
- stitch pairing across layers
- duplicate or invalid entity, switch, and door ids
- switch-door linkage validity
- projector target bounds
- likely pushable soft-lock corners
- missing hints
- missing metadata and balance fields
- basic static reachability for stitches and goals

Warnings are meant to highlight review risks, not always to block a room. Errors should be treated as must-fix before content review.

## Playtest Logging

The shipping runtime now records local internal playtest data to `user://patchwork-post-playtests.json`.

Each entry captures:

- room id
- completion or abandonment
- duration
- move count
- reset count
- hint tiers used

The authoring dock rolls that into per-room summaries so puzzle difficulty can be compared against the intended balance metadata.

## Source Of Truth

- Shared authored room data lives in [campaign.json](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/data/source/campaign.json).
- Dev-only proof rooms live in [dev-rooms.json](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/data/source/dev-rooms.json).
- The Godot-side authoring save path is handled by [content_repository.gd](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/godot/scripts/core/content_repository.gd).

Use `npm run sync:content` whenever you want the browser prototype and generated assets to pick up source-data changes made outside the Godot editor.

## Regression Coverage

Batch 3 automation now verifies:

- every room includes balance metadata
- the playtest logger summarizes attempts correctly
- the authoring dock builds its room browser and visual layer editor
- new rooms can be created, resized, extended to three layers, edited, and saved
- saved drafts persist entities, switches, doors, layer edits, and validator metrics
