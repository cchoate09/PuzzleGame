# Batch 6 Campaign Expansion

Last updated: March 23, 2026

Batch 6 turns the demo-quality front half into a fuller premium-campaign prototype by building the late-game districts, introducing a single back-half routing modifier, and wiring optional mastery content into a true secret line instead of isolated bonus rooms.

## Scope Summary

- 31 total rooms across all seven districts
- 21 main-route rooms ending at `rooftops-04`
- 10 optional or secret rooms, including a 3-room attic route
- a late-game `routingStamps` modifier that redirects:
  - stitched layer switches
  - parcel transfers
  - projection bridge resolution
- 5 hidden journal entries tied to side-route and attic completion
- separate completion beats for:
  - the main festival route
  - the attic postscript secret route

## New District Coverage

### Clocktower

- `clocktower-01` extends echo timing into a longer stitched route.
- `clocktower-02` introduces routing stamps as a controlled redirect on layer switching.
- `clocktower-03` mixes echo timing, transfer, and routed bridge logic.
- `clocktower-side-01` is the first mastery branch and unlocks the `Bell Margin` journal entry.

### Theater

- `theater-01` uses shadow setup as the district's primary planning language.
- `theater-02` adds sticky-latch shadow sequencing before movement compression.
- `theater-03` combines shadows with routing stamps and ends the district on a cleaner mastery step.
- `theater-side-01` is the second mastery branch and unlocks the `Backstage Margin` journal entry.

### Rooftops

- `rooftops-01` introduces routed rooftop movement with larger open layouts.
- `rooftops-02` routes transfers instead of only route travel.
- `rooftops-03` mixes rooftop traversal, projection, and held-door planning.
- `rooftops-side-01` is the third mastery branch and unlocks the `Sky Margin` journal entry.
- `rooftops-04` closes the main campaign and triggers the `Festival Line` ending beat.

### Attic

- `attic-01` unlocks only after the three late-game side routes are solved.
- `attic-02` deepens three-layer routed planning and unlocks only after `attic-01`.
- `attic-03` resolves the secret line and unlocks `Mina's Postscript`.

## Progression Structure

- The main campaign is now explicitly mapped through campaign metadata as the `Full Festival Route`.
- The attic route is now explicitly mapped as the `Attic Postscript`.
- `attic` district access requires:
  - `clocktower-side-01`
  - `theater-side-01`
  - `rooftops-side-01`
- Individual late-game rooms can also require prerequisite rooms inside their own district so mastery branches stay readable and intentional.

## Runtime And Tooling Changes

- Added `routingStamps` to the shared room schema and both runtimes.
- Added routing-stamp validation and metrics in the browser and Godot validators.
- Added routing-stamp rendering to the Godot room view so redirected movement is visible and inspectable.
- Added routing-stamp authoring to the Godot content dock with per-channel targeting for:
  - switch
  - transfer
  - projection
- Expanded save metadata with hidden journal unlock support and updated content versioning for the Batch 6 campaign.
- Expanded the Godot shell to surface:
  - main campaign completion
  - secret-route completion
  - secret attic gating
  - unlocked hidden journal threads

## Achievement And Journal Mapping

- Added or mapped late-game achievements for:
  - `stage-route`
  - `festival-line`
  - `attic-secret`
  - `secret-line`
  - `archivist`
- Hidden journal unlocks now tie optional late-game mastery to narrative payoff instead of only postmarks.
- Collecting all journal entries now unlocks `Archivist`.

## QA Checklist

- Solve the full 21-room main route and confirm `rooftops-04` raises the main completion panel.
- Confirm the attic district stays locked until all three late-game side routes are solved.
- Solve `attic-01`, `attic-02`, and `attic-03` in order and confirm the secret-route completion panel appears on `attic-03`.
- Confirm routed switch, transfer, and projection behavior match canonical solutions in both runtimes.
- Confirm the authoring dock can create, save, and reload routing stamps.
- Confirm all browser and Godot regression suites stay green after content sync.
