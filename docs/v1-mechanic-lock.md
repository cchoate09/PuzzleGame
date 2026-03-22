# Patchwork Post V1 Mechanic Lock

Last updated: March 22, 2026

This document locks the Batch 1 mechanic roster for the shipping version. New mechanics should not be added casually; they must survive a clear "does this deepen the core more than it expands scope?" review.

## Locked V1 Core Mechanics

### 1. Layer Switching

- The player can switch between aligned sheets at stitch markers.
- Switching is only allowed when both source and destination layers have a stitch at the same coordinate.
- This is the signature mechanic and must remain the foundation of the game.

### 2. Object Transfer

- Pushable objects can be moved between aligned coordinates across layers.
- Transfer is the second pillar mechanic and should remain readable and predictable.

### 3. Switches And Doors

- Pressure plates open doors.
- Sticky latches are a variant of this system, not a separate family.

### 4. Projection Bridges

- Projector entities activate traversable structure on another layer.
- Projection should always read visually before it is required by a hard puzzle.

### 5. Echo Actors

- Echo actors replay the prior move one beat later.
- They add temporal planning without adding real-time pressure.

### 6. Shadow Actors

- Shadow actors mirror player movement across an axis on another layer.
- They should be used for spatial reasoning, not twitch precision.

### 7. Sticky Latches

- Sticky switches persist once touched.
- Treat this as an escalation of switch logic, not a wholly separate subsystem.

### 8. One Late-Game Routing Modifier

Recommended implementation:

- `Routing Stamps`: special marks that redirect a transfer, projection, or stitch exit by rule.

Purpose:

- deepen the late game
- strengthen the postal theme
- expand recombination space without creating an unrelated new system

## Mechanics Explicitly Not In V1

- combat
- stealth
- time limits
- action-platforming
- procedural puzzle generation
- full player-authored level sharing
- multiple controllable protagonists as a separate ruleset
- 3D camera rotation puzzles

## Design Rules For New Uses Of Existing Mechanics

- Prefer recombination over mechanic accumulation.
- Every room should hinge on one main insight, not on exhaustive trial and error.
- Optional rooms may be harder, but should not teach hidden rules.
- If a new interaction requires a long explanation, it probably needs stronger visual language or does not belong in v1.

## Late-Game Standard

The late game should feel smarter, not busier.

Good late-game escalation:

- three-layer routing
- combined shadow and projection setups
- transfer puzzles with route redirection
- optional mastery rooms that reuse known rules in cleaner, sharper ways

Bad late-game escalation:

- bigger boards with no new idea
- many simultaneous moving parts with weak visual cues
- meta rules that invalidate previously learned expectations
