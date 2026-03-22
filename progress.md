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
  - completed Batch 1 cleanup by moving shared authoring data into `data/source/` and generating both browser and Godot outputs from that source
  - added `scripts/sync-content.mjs` and generated browser modules in `src/content/generated/`
  - added root repo documentation in `README.md`
  - added GitHub Actions CI in `.github/workflows/ci.yml`
  - added reusable Godot setup tooling in `scripts/godot-paths.mjs`, `scripts/verify-godot-setup.mjs`, and `scripts/install-godot-export-templates.ps1`
  - installed official Godot export templates locally and verified them with `npm run verify:godot`
- Batch 1 status:
  - complete
- Batch 2 progress:
  - completed the vertical-slice presentation pass in the native runtime
  - expanded the Godot shell into a three-column game layout with route-map navigation, room HUD, dialogue overlays, toast notifications, solve banners, and in-game settings
  - upgraded the Godot board renderer into a district-themed papercraft presentation with stitched seam connectors, torn edges, layered lift shadows, animated active-sheet focus, and stronger interactable silhouettes
  - added accessibility wiring for high contrast, reduced motion, and font scaling in the shipping runtime
  - added first-pass procedural audio for move, push, switch, transfer, hint, reset, room-enter, and solve feedback
  - added a Batch 2 UI smoke test in `godot/scripts/tests/run_batch2_ui_smoke.gd`
  - documented the vertical-slice presentation direction in `docs/batch-2-ui-style-guide.md` and `docs/batch-2-audio-style-guide.md`
  - verified `npm test`, `npm run test:godot`, and a headless boot of the main Godot scene all pass after the visual/UX changes

- Batch 2 status:
  - complete for the current vertical slice
- Batch 3 progress:
  - added a Godot-side content repository in `godot/scripts/core/content_repository.gd` so authored rooms can be loaded and saved directly from `data/source/campaign.json`
  - upgraded `godot/scripts/core/patchwork_validator.gd` from basic structural checks into a richer report with errors, warnings, infos, metrics, reachability checks, linkage checks, and balance metadata validation
  - added `godot/scripts/tools/playtest_logger.gd` to capture local internal telemetry for attempts, solves, resets, hint use, and abandonment
  - built an in-engine authoring dock in `godot/scripts/tools/room_authoring_dock.gd` with:
    - district room browser
    - live room preview
    - visual tile painting
    - start, entity, switch, and door placement
    - structure editing for room resize and layer add/remove
    - hint and metadata authoring
    - switch-door linking
    - validation summaries
    - balance and playtest browser tabs
  - integrated the authoring dock into the shipping runtime through `godot/scripts/main.gd`
  - added Batch 3 regression coverage in `godot/scripts/tests/run_batch3_tools_tests.gd`
  - expanded `scripts/run-godot-tests.mjs` so `npm run test:godot` now runs Batch 1, Batch 2, and Batch 3 coverage in one pass
  - added required balance metadata to all current campaign rooms and the three-layer proof room
  - documented the new toolchain in `docs/batch-3-authoring-workflow.md`
  - verified `npm test`, `npm run test:godot`, `npm run verify:godot`, and a headless boot of the Godot main scene all pass after the tooling changes

- Batch 3 status:
  - complete for the current internal content-production scope

TODO
- Expand the prototype into the full planned campaign size with many more rooms, district beats, and difficulty ramps.
- Push into Batch 4: richer hint UX, controller-only navigation polish, Steam-facing support hooks, and a stronger demo-ready accessibility pass.
- Add richer room-editor ergonomics over time, such as drag placement, copy/paste, and faster layer inspection, if content production exposes pain points.
- Decide how much of the browser prototype UI should continue to evolve versus freezing it as a mechanics reference while Godot becomes the clear primary runtime.
- Add Steam-specific production hooks later, such as achievement plumbing, export targets, and cloud-save integration on the shipping runtime.
