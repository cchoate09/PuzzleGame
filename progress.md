Original prompt: PLEASE IMPLEMENT THIS PLAN:
# Patchwork Post

## Summary
- Build a premium single-player 2D puzzle game for Steam about restoring a papercraft town’s broken mail routes before its annual festival.
- Keep the game in 2D. The core hook is spatial logic across aligned paper layers, and 3D would add camera/readability cost without making the puzzles better.
- Target a solo-friendly scope: 6 to 10 hours for a first playthrough, roughly 55 mandatory puzzles, 15 to 20 optional challenge rooms, and a light story carried by short scenes and environmental details.
- Position it as a difficult but welcoming logic game: high clarity, deep “aha” moments, unlimited undo, and an optional layered hint system.

Notes
- Godot 4.6.1 is now installed in the environment, and Batch 1 has moved from browser-only prototyping into a native Godot shipping scaffold.
- The goal for this pass is a polished, testable prototype with a real campaign slice rather than pretending the full commercial content set is finished.
- Implemented systems: deterministic layered-grid simulation, undo/redo/reset, replay, save snapshots, hints, accessibility toggles, keyboard remapping, gamepad polling, world map gating, journal/achievement UI, room JSON preview, and basic room validation.
- Implemented campaign slice: 8 handcrafted rooms across Mailroom, Market, Greenhouse, Clocktower, Theater, Rooftops, and Attic, including layer switching, parcel transfer, linked doors, projection bridges, echo timing, mirrored shadows, and a sticky latch secret room.
- Validation summary: automated Playwright runs solved the tutorial, transfer, switch, projection, echo, shadow, mixed-mechanic, and attic rooms; direct Playwright checks also validated hints, undo, reset, and the high-contrast setting.
- Fixed during testing: misaligned stitch coordinates in `mailroom-01`, wall-pinned projector starts in `greenhouse-01` and `rooftops-01`, and a shadow route that blocked the attic stitch.
- Added a product-facing design and launch doc at `docs/patchwork-post-design-and-launch.md` covering current structure, market comparison, gap analysis, and a recommended Steam timeline.
- Added an execution roadmap at `docs/patchwork-post-batch-roadmap.md` that breaks the work into ordered batches with deliverables and exit criteria.
- Batch 1 progress:
  - moved campaign data into `src/content/campaign.js` so content now has a dedicated source-of-truth location
  - added a v1 room schema doc at `docs/puzzle-room-schema.md`
  - added a v1 mechanic lock doc at `docs/v1-mechanic-lock.md`
  - added canonical room solutions in `src/content/solutions.js`
  - added a three-layer proof room in `src/content/devRooms.js`
  - added automated regressions in `tests/room-regressions.test.js`
  - created a native Godot project scaffold in `godot/` with a boot scene, input bootstrap, room loading, room cycling, and save loading
  - ported the deterministic puzzle simulation to `godot/scripts/core/patchwork_engine.gd`
  - ported save-profile helpers to `godot/scripts/core/patchwork_save.gd`
  - ported structural validation to `godot/scripts/core/patchwork_validator.gd`
  - added a native room renderer and debug HUD in `godot/scripts/ui/room_view.gd` and `godot/scripts/main.gd`
  - added a content export path from the browser prototype to Godot via `scripts/export-godot-content.mjs`
  - added headless Godot regression coverage in `godot/scripts/tests/run_batch1_tests.gd`
  - added `npm run sync:godot-data` and `npm run test:godot`
  - verified `npm test` passes for all current canonical rooms, replay behavior, undo/redo/reset behavior, and the three-layer proof room
  - verified `npm run test:godot` passes for canonical room replays, undo/redo/reset behavior, replay behavior, and the three-layer proof room in the native runtime
  - verified the Godot main scene boots headlessly without script errors
- Batch 1 remaining gaps:
  - the native presentation is intentionally minimal and debug-oriented; final-feel rendering belongs to Batch 2
  - export templates and Steam integration are not configured yet
  - the cross-runtime content source of truth still originates in the JS authoring files and exports into `godot/data/generated/`

TODO
- Expand the prototype into the full planned campaign size with many more rooms, district beats, and difficulty ramps.
- Add richer room-editor affordances beyond raw JSON editing, including drag-and-drop placement and better visual layer inspection.
- Decide whether to migrate authoring data fully into engine-agnostic JSON during Batch 1 cleanup or leave the JS authoring files as the source until the editor arrives in Batch 3.
- Install Godot export templates before the first real desktop export pass.
- Add Steam-specific production hooks later, such as achievement plumbing, export targets, and cloud-save integration on the shipping runtime.
