# Patchwork Post Audio Style Guide

Last updated: March 22, 2026

This guide captures the first-pass Batch 2 audio direction used in the Godot vertical slice.

## Audio Goal

- Support logic readability with soft tactile feedback.
- Keep sounds papery, mechanical, and warm rather than arcade-sharp.
- Make important state changes easy to feel without becoming noisy during repeated attempts.

## Sound Categories

- Movement:
  - short, light confirmation
  - should feel like paper shoes on a drafting surface
- Push:
  - lower and heavier than movement
  - should imply weight and friction
- Layer switch:
  - slightly magical but still physical
  - should feel like flipping or lifting a sheet
- Transfer:
  - small shimmer with a mechanical handoff
- Wait:
  - understated; never compete with move or solve states
- Undo/redo:
  - soft confirmation, clearly differentiated in pitch direction
- Reset:
  - fuller, lower cue that reads as restoring the board
- Hint:
  - clear but gentle, more like opening a notebook than triggering a reward
- Enter room:
  - subtle scene-setter, not a fanfare
- Solve:
  - the largest cue in the current mix, warm and satisfying rather than triumphant

## Current Runtime Mapping

- `move`: light triangle-led tap
- `push`: lower layered thump with a little grit
- `wait`: soft sine pulse
- `switch_layer`: rising layered tone
- `transfer`: square-plus-triangle shimmer
- `undo`: lower sine cue
- `redo`: slightly higher sine cue
- `reset`: fuller low reset wash
- `hint`: bright short sine ping
- `enter`: warm two-tone scene cue
- `solve`: stacked harmonic cadence

## Mix Rules

- Puzzle actions should remain short so repeated experimentation stays pleasant.
- Solve should be the loudest event, but only modestly louder.
- Avoid long tails that cover up rapid player input.
- Replays can remain visually focused; they do not need dense audio feedback.

## Future Production Notes

- Replace generated placeholder tones with authored paper-and-felt Foley during later audio production.
- Add light ambient beds by district only after the core interaction mix is locked.
- Keep ambience sparse enough that players can think in silence if they want.
- A future music pass should reinforce districts, but never drown out interaction clarity.
