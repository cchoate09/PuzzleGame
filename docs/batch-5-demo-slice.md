# Batch 5 Demo Slice

Last updated: March 23, 2026

Batch 5 turns the polished runtime into a real public-facing demo slice by expanding the first three districts and adding a cleaner end beat for wishlist-facing play.

## Scope Summary

- 15 total rooms across the first three districts
- 11 mainline rooms and 4 optional side rooms
- a guided teaching curve for:
  - layer switching
  - parcel transfer
  - visible and hidden door logic
  - projection bridges
  - early mixed-mechanic mastery
- a demo-complete finale that unlocks the Clocktower route and teases later mechanics

## Content Map

### Mailroom

- `mailroom-01` teaches stitched layer switching.
- `mailroom-02` teaches parcel transfer.
- `mailroom-03` recombines a push, transfer, and stitch in one route.
- `mailroom-side-01` is a two-switch optional route.
- `mailroom-04` caps the district with transfer plus two-sheet traversal and hands off to Market.

### Market

- `market-01` teaches visible plate and door logic.
- `market-side-01` reinforces a visible plate plus stitched shortcut.
- `market-02` teaches hidden back-sheet plate activation through transfer.
- `market-side-02` recombines hidden plate logic with a stitched lane.
- `market-03` caps the district with one visible plate, one hidden plate, and two parcels.

### Greenhouse

- `greenhouse-01` teaches same-coordinate projection.
- `greenhouse-side-01` teaches offset projection.
- `greenhouse-02` teaches multi-tile projection.
- `greenhouse-03` combines projection with a held door.
- `greenhouse-04` caps the demo with parcel parking, projection, and a true three-layer route.

## Runtime Additions

- Added campaign-level `demo` metadata to the shared content source and generated campaign index.
- Added demo progress surfacing in the main HUD.
- Added room-level outro beats for key handoff rooms.
- Added a demo completion overlay and finale dialogue beat on `greenhouse-04`.
- Retuned district unlock thresholds so Clocktower opens after the full demo mainline, not midway through the slice.

## QA Checklist

- Solve every mainline demo room through the shipping runtime with canonical solutions.
- Confirm Market stays locked until 2 postmarks, Greenhouse until 5, and Clocktower until the demo finale.
- Confirm all 4 optional rooms unlock only after their district's main route has started.
- Confirm the demo HUD reports `Demo route: x / 11 main`.
- Confirm `greenhouse-04` raises the demo completion panel and teaser dialogue.
- Confirm demo saves still report Batch 5 content version and pass demo/full carryover checks.
- Confirm all browser and Godot regression suites stay green after content sync.
