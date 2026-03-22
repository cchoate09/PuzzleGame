# Patchwork Post

Patchwork Post is a 2D logic-puzzle game prototype built around layered paper rooms, object transfer, switches, projection bridges, echo timing, and mirrored shadow actors.

The repo currently contains:

- a browser prototype used as the mechanic reference
- a Godot 4 native runtime that now carries the Batch 2 vertical slice
- shared JSON content sources that generate browser and Godot data outputs
- regression tests for canonical puzzle solutions in both runtimes

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
- Style direction lives in [batch-2-ui-style-guide.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-2-ui-style-guide.md) and [batch-2-audio-style-guide.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-2-audio-style-guide.md).
- Batch 3 is the next major focus: content tools, validation workflow, and balancing support.
