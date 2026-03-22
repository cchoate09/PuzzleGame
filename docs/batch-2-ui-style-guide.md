# Patchwork Post UI Style Guide

Last updated: March 22, 2026

This guide captures the current Batch 2 vertical-slice presentation rules in the Godot runtime.

## Visual Goal

- Present each puzzle room as a desk-top papercraft diorama rather than a flat logic grid.
- Keep the board readable first: visual polish must clarify layer relationships, not obscure them.
- Make the runtime feel like a premium authored puzzle game, not an internal tool.

## Core Visual Language

- Boards are paper sheets resting on a desk, with lift shadows that make the active layer feel physically higher.
- Each layer card gets:
  - a top strip color
  - side stitches
  - a torn lower edge
  - a warm paper border
- Matching stitch coordinates between layers are connected by visible thread lines so players can read layer travel before they act.
- Interactables use silhouette-first shapes instead of relying on letter glyphs alone:
  - parcels read as tied boxes
  - projectors read as lantern devices
  - echoes read as translucent circular ripples
  - shadows read as dark mirrored blobs
  - the courier reads as a small character token with facing direction

## District Palette Rules

- Global base:
  - backdrop: warm drafting desk
  - sheets: cream and off-white
  - borders: stitched tan
  - grid: light parchment lines
- District accents:
  - Mailroom: rust and brass
  - Market: muted berry and amber
  - Greenhouse: moss and lantern gold
  - Clocktower: slate blue and brass
  - Theater: plum and faded velvet
  - Rooftops: sunlit gold and terracotta
  - Attic: sepia and dry wood
- Accent colors should appear in:
  - card titles
  - active layer strips
  - district state labels
  - route map emphasis

## Layout Rules

- Three-column gameplay shell:
  - left: town map and route progression
  - center: room board and overlays
  - right: objective, hints, notes, settings, and action tools
- The center board should always dominate eye priority.
- Overlay hierarchy:
  - dialogue card in upper-left of board
  - solve banner centered
  - route or system toast near bottom-left
  - soft transition wash over the whole board during room entry

## Typography And Scale

- Use a large title, medium section heads, and compact supporting copy.
- Important numbers live in the header metrics, not buried in side cards.
- Font scaling must support at least `0.9x` to `1.35x`.
- Body copy should stay comfortable on Steam Deck-class screens.

## Interaction Rules

- Route map buttons must communicate four states clearly:
  - active room
  - solved room
  - unlocked room
  - locked room
- Hint buttons should communicate progression, not just numbering:
  - Reframe
  - Mechanic
  - Opening
- Solve feedback should feel celebratory but short; it must not slow fast repeat attempts.
- Room entry dialogue should surface the room’s teaching beat immediately, then fade cleanly.

## Accessibility Rules

- High contrast mode must increase separation between paper, wall, gap, bridge, and actor colors.
- No interaction should depend on color alone; silhouettes and card states must still communicate.
- Reduced motion should remove or sharply shorten:
  - room entry transitions
  - layer lift animation
  - solve flashes
- Controls remain visible in the settings card at all times.

## Capture Direction

- Preferred capture rooms for early marketing:
  - `mailroom-01` for layer-switch readability
  - `market-01` for parcel plus door logic
  - `greenhouse-01` for projected bridges
- Capture should emphasize:
  - stitched connections across layers
  - active-sheet lift
  - warm paper textures and card framing
  - short before/after puzzle reveals
