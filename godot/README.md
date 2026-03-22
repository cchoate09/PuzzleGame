# Patchwork Post Godot Runtime

This directory is the native Godot 4 shipping scaffold for Batch 1.

## Current Scope

- minimal native boot scene
- deterministic puzzle engine parity with the browser prototype
- room loading from exported JSON content
- undo, redo, reset, replay, save snapshot support
- simple debug renderer and room HUD
- headless regression runner for canonical solutions

## Commands

From the repo root:

```bash
npm run sync:godot-data
npm run test:godot
```

To open the runtime manually, launch the Godot editor against [project.godot](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/godot/project.godot).

## Data Flow

- Authoring content currently lives in the browser prototype files under `src/content/`.
- `scripts/export-godot-content.mjs` exports that content into `godot/data/generated/`.
- The Godot runtime loads those generated JSON files through `scripts/core/content_loader.gd`.

## Notes

- This runtime is intentionally debug-first for Batch 1.
- Final visuals, transitions, audio, and presentation polish belong to Batch 2.
- Steam-specific integration is not wired yet.
