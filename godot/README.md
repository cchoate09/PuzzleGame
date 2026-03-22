# Patchwork Post Godot Runtime

This directory is the native Godot 4 runtime for Patchwork Post. Batch 1 established the production base; Batch 2 now carries the first near-final vertical-slice presentation pass.

## Current Scope

- minimal native boot scene
- deterministic puzzle engine parity with the browser prototype
- room loading from exported JSON content
- undo, redo, reset, replay, save snapshot support
- route-map navigation with district and room unlock states
- layered paper-board renderer with stitched connectors, district accents, and animated active-sheet focus
- room HUD with dialogue cards, solve banners, toasts, hints, notes, settings, and action tools
- accessibility toggles for high contrast, reduced motion, and font scaling
- first-pass procedural interaction audio
- headless regression runner for canonical solutions plus a UI smoke test

## Commands

From the repo root:

```bash
npm run sync:content
npm run test:godot
npm run verify:godot
```

To open the runtime manually, launch the Godot editor against [project.godot](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/godot/project.godot).

## Data Flow

- Authoring content lives in the shared JSON source under `data/source/`.
- `scripts/sync-content.mjs` exports that content into browser modules and `godot/data/generated/`.
- The Godot runtime loads those generated JSON files through `scripts/core/content_loader.gd`.

## Notes

- This runtime is now the primary vertical-slice surface for presentation work.
- Visual and audio direction notes are documented in:
  - [batch-2-ui-style-guide.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-2-ui-style-guide.md)
  - [batch-2-audio-style-guide.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/docs/batch-2-audio-style-guide.md)
- Steam-specific integration is not wired yet.
