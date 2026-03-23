# Patchwork Post

Patchwork Post is a 2D logic-puzzle game prototype built around layered paper rooms, object transfer, switches, projection bridges, echo timing, mirrored shadow actors, and late-game routing stamps that bend how routes behave across layers.

The repo currently contains:

- a browser prototype used as the mechanic reference
- a Godot 4 native runtime that now carries the full Batch 6 campaign prototype
- shared JSON content sources that generate browser and Godot data outputs
- regression tests for canonical puzzle solutions, UI smoke coverage, authoring tools, support systems, the Batch 5 demo flow, and the Batch 6 late-game campaign route

## Commands

From [package.json](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/package.json):

```bash
npm install
npm run sync:content
npm test
npm run test:godot
npm run verify:godot
```

If Godot export templates are missing on Windows:

```bash
npm run install:godot-templates
```

## Structure

- [data/source](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/data/source): shared source-of-truth content
- [src](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/src): browser prototype
- [godot](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/godot): native runtime scaffold
- [docs](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs): design, roadmap, schema, and mechanic lock docs
- [tests](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/tests): browser-side regression coverage

## Current Status

- Batch 1 foundation work is complete and verified.
- Batch 2 visual and UX work is implemented in the Godot runtime: route map navigation, dialogue and toast overlays, settings, accessibility toggles, animated layer presentation, and first-pass procedural audio.
- Batch 3 content tools are implemented in the Godot runtime: a visual room authoring dock, balance metadata browser, richer structural validation, and local playtest logging summaries.
- Style direction lives in [batch-2-ui-style-guide.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-2-ui-style-guide.md) and [batch-2-audio-style-guide.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-2-audio-style-guide.md).
- Batch 3 workflow notes live in [batch-3-authoring-workflow.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-3-authoring-workflow.md).
- Batch 4 is implemented in the Godot runtime: progressive hint UX, control remapping, controller-first menu support, demo/full save carryover scaffolding, and Steam-support stubs.
- Batch 4 notes live in [batch-4-support-systems.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-4-support-systems.md).
- Batch 5 is implemented: the first three districts now form a 15-room public-demo slice with 11 main rooms, 4 optional rooms, room handoff beats, a demo completion overlay, and updated progression gating.
- Batch 5 notes live in [batch-5-demo-slice.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-5-demo-slice.md).
- Batch 6 is implemented for the current campaign prototype: Clocktower, Theater, Rooftops, and Attic are now playable with a late-game routing-stamp modifier, optional mastery branches, a cross-district secret line, and hidden journal threads.
- The shared campaign source now contains 31 rooms total: 21 main-route rooms and 10 optional or secret rooms.
- The secret route now requires three late-game side routes before the attic unlocks, and the runtime surfaces separate completion beats for the main festival line and the attic postscript.
- Batch 6 notes live in [batch-6-campaign-expansion.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-6-campaign-expansion.md).
