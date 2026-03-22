# Patchwork Post Improvement Batch Roadmap

Last updated: March 22, 2026

This roadmap turns the launch/design doc into a sequence of implementation batches we can tackle one at a time.

## How To Use This Roadmap

- Only work on one batch at a time.
- Do not start a new major mechanic batch before the previous batch has exit criteria met.
- At the end of every batch:
  - run a regression pass on all solved rooms
  - update docs and backlog status
  - capture screenshots or short clips
  - write down what changed in balance, clarity, or production risk
- If a batch starts growing, cut secondary scope instead of weakening the core outcome.

## Assumptions

- Shipping target is a premium Steam game.
- Shipping runtime will be Godot 4, while the current browser build remains the design prototype.
- The planned launch target remains early 2027, after the October 19-26, 2026 Steam Next Fest.
- The current prototype is the reference design for mechanics, not the shipping codebase.

## Batch Overview

| Batch | Focus | Main Outcome |
| --- | --- | --- |
| 1 | Shipping foundation and product lock | A stable Godot-based gameplay core with locked room schema and testable simulation |
| 2 | Visual and UX vertical slice | One district that looks and feels close to shipping quality |
| 3 | Content tools and balancing pipeline | Fast room production, validation, and playtest support |
| 4 | Demo-ready feature support | Hints, accessibility, controller polish, Steam-facing support systems |
| 5 | Demo content and first public slice | A strong demo built around the first three districts |
| 6 | Full campaign expansion | Mainline content, optional mastery routes, late-game twist, secrets |
| 7 | Steam launch preparation | Store assets, localization, QA, integration, and external playtesting |
| 8 | Release and post-launch support | Launch patching, first update, and retention improvements |

## Batch 1: Shipping Foundation And Product Lock

### Goal

Move from a promising prototype to a stable production base that can ship on Steam and support long-term content creation.

### Improvements

- Set up the shipping project in Godot 4.
- Port the deterministic puzzle simulation out of the current browser prototype into the shipping runtime.
- Lock the core content schema:
  - `PuzzleRoom`
  - `Entity`
  - objective rules
  - hint tiers
  - room metadata
  - progression metadata
- Lock the final mechanic list for v1:
  - layer switching
  - transfer
  - switches and doors
  - projection bridges
  - echoes
  - shadows
  - sticky latches
  - one late-game routing modifier
- Add support for true three-layer rooms in the shipping runtime.
- Build automated solution regression support for canonical rooms.

### Deliverables

- Godot project scaffold with game boot, room loading, save loading, and input handling.
- Engine parity with the current prototype for all existing mechanics.
- Room schema document and sample room files.
- Regression test harness that can replay known solutions and report pass/fail.
- One source-of-truth content directory for rooms and progression data.

### Exit Criteria

- All current prototype rooms can be represented in the shipping schema.
- All current mechanics behave correctly in the shipping runtime.
- Undo, redo, reset, save, and replay work in the shipping runtime.
- At least one three-layer test room runs correctly.
- There is no unresolved debate about the v1 mechanic roster.

### Out Of Scope

- final art
- full story content
- Steam integration
- large content expansion

## Batch 2: Visual And UX Vertical Slice

### Goal

Create one district that demonstrates the final presentation quality and proves the game can compete visually while staying readable.

### Improvements

- Establish the final papercraft visual language:
  - torn paper edges
  - stitched seams
  - layered lift shadows
  - district palette rules
  - improved silhouettes for interactables
- Replace prototype UI with shipping-quality UI for:
  - room HUD
  - world navigation
  - dialogue cards
  - hint surfacing
  - settings
- Add polished transitions for:
  - entering rooms
  - switching layers
  - solving rooms
  - unlocking routes
- Add final-feel audio direction prototype:
  - movement
  - push
  - switch layer
  - transfer
  - success
  - reset

### Deliverables

- One district, preferably Mailroom or Market, at near-final visual quality.
- UI style guide with colors, typography, spacing, and icon rules.
- Audio style guide with placeholder or first-pass effects.
- Screenshot and trailer-ready capture from the vertical slice.

### Exit Criteria

- The game no longer looks like a tool prototype.
- Layer relationships are easier to read, not harder, after the art upgrade.
- The district is representative enough to use in early marketing materials.

### Out Of Scope

- full soundtrack
- full game art pass
- whole-campaign content production

## Batch 3: Content Tools And Balancing Pipeline

### Goal

Make room production fast, safe, and reviewable so the campaign can scale without breaking quality.

### Improvements

- Build a visual room editor with:
  - tile painting
  - entity placement
  - layer visibility controls
  - switch-door linking
  - hint authoring
  - room metadata editing
- Add balance metadata to every room:
  - intended lesson
  - target difficulty
  - expected solve time
  - common misunderstanding
- Add editor validation for:
  - invalid linkages
  - unreachable stitches
  - likely soft locks
  - missing hints
  - missing metadata
- Add playtest logging support for:
  - solve time
  - reset count
  - hint usage
  - abandonment

### Deliverables

- In-engine room editor.
- Validation report view.
- Room browser for comparing balance across districts.
- One small telemetry or playtest logging path for internal builds.

### Exit Criteria

- New rooms can be authored without hand-editing raw JSON.
- Designers can review room metadata and known issues quickly.
- We can identify which rooms are too hard, too noisy, or too vague from actual test data.

### Out Of Scope

- public level editor
- workshop support
- analytics at live-service scale

## Batch 4: Demo-Ready Feature Support

### Goal

Polish the support systems that make the game approachable, Steam-ready, and safe to demo publicly.

### Improvements

- Upgrade hints from text-only to a full three-stage system:
  - reframing hint
  - mechanic hint
  - guided opening or ghost replay
- Improve accessibility and input support:
  - final remapping flow
  - glyph swapping
  - readable Steam Deck layout
  - stronger no-color-only rules
- Implement Steam-facing support systems in the shipping runtime:
  - achievements
  - Steam Cloud
  - Steam Input action manifest
  - demo save carryover path
- Add controller-only navigation pass for every active menu.

### Deliverables

- Full hint UX.
- Accessibility review checklist and pass.
- Steam integration checklist and first-pass implementation.
- Demo/full build save compatibility spec.

### Exit Criteria

- A first-time player can get unstuck without leaving the game.
- Controller support feels intentional rather than "supported on paper."
- The build is structurally ready to become a Steam demo.

### Out Of Scope

- full store page rollout
- full localization set
- launch trailer

## Batch 5: Demo Content And First Public Slice

### Goal

Build a public-quality demo that shows the game's strongest early progression and earns wishlists.

### Improvements

- Expand content for:
  - Mailroom
  - Market
  - Greenhouse
- Shape the early-game teaching curve around:
  - layer switching
  - transfer
  - door logic
  - projection
- Build optional side rooms that preview the game's depth without overcomplicating the demo.
- Add stronger narrative beats and character presence in the first three districts.
- Add demo-end hook that points toward later mechanics.

### Deliverables

- Demo campaign slice with roughly 15 to 20 rooms.
- Polished demo intro and ending beat.
- Demo-specific difficulty pass.
- Demo QA checklist.

### Exit Criteria

- The demo communicates the game's hook in under 10 minutes.
- The demo ends on a strong "I want the full game" reveal.
- The demo is stable enough for festival play and creator coverage.

### Out Of Scope

- full campaign
- postgame content
- final late-game twist implementation unless needed for the demo hook

## Batch 6: Full Campaign Expansion

### Goal

Turn the demo-quality slice into a full premium campaign with strong late-game mastery and secrets.

### Improvements

- Build out:
  - Clocktower
  - Theater
  - Rooftops
  - Attic
- Add the late-game routing modifier and use it only where it meaningfully deepens the back half.
- Build true three-layer mastery rooms.
- Add optional mastery routes, hidden journal threads, and a cross-district secret line.
- Do a full macro progression pass so players can reach credits without hardest optional content.

### Deliverables

- Full room set for launch target scope.
- Secret path and postgame route.
- Full achievement list and content mapping.
- Difficulty map across the whole campaign.

### Exit Criteria

- Main campaign is content-complete.
- Optional content feels rewarding, not like leftovers.
- The back half introduces new thinking patterns rather than just longer versions of early puzzles.

### Out Of Scope

- full post-launch challenge pack
- community level support

## Batch 7: Steam Launch Preparation

### Goal

Convert a content-complete game into a competitive Steam product.

### Improvements

- Build store presence:
  - capsule art
  - screenshots
  - short trailer
  - long trailer
  - store copy
  - tags
- Prepare localization for:
  - store page
  - UI
  - hints
  - core dialogue
- Run external playtests and creator preview outreach.
- Request and respond to Steam Deck review.
- Finalize demo app and Next Fest materials.

### Deliverables

- Coming Soon page assets and copy.
- Festival demo build.
- Localization-ready strings and translated first set.
- QA bug database with priority and ownership.

### Exit Criteria

- Store page is strong enough to convert views into wishlists.
- Demo is stable enough for Steam Next Fest.
- External feedback identifies polish work, not core-concept confusion.

### Out Of Scope

- major new mechanics
- large-scale narrative rewrite
- foundational engine changes

## Batch 8: Release And Post-Launch Support

### Goal

Launch cleanly, respond quickly, and reinforce the game's reputation while reviews and wishlists are most sensitive.

### Improvements

- Final launch stabilization.
- Release-day bug triage process.
- Quality-of-life patch planning.
- First content or challenge update planning.
- Community-facing communication cadence:
  - patch notes
  - launch post
  - follow-up update

### Deliverables

- Launch candidate build.
- Day-0 and day-7 response checklist.
- First update backlog.
- Post-launch metrics review.

### Exit Criteria

- Major launch bugs are triaged quickly.
- First user reviews focus on puzzle quality rather than avoidable technical issues.
- There is a clear plan for the first update within 6 to 10 weeks.

## Recommended First Batch To Tackle Now

Start with Batch 1.

Reason:

- It removes the biggest structural risk early.
- It prevents us from building too much future content on prototype-only code.
- It locks the schema and mechanic roster before art, tooling, and content scale up.

### Batch 1 Immediate Worklist

1. Create the Godot 4 project structure and import pipeline.
2. Port the puzzle simulation and room loading logic from the browser prototype.
3. Define the final room schema and migrate the current 8 rooms into it.
4. Rebuild save, undo, redo, reset, and replay in the shipping runtime.
5. Add canonical solution replay tests for all current rooms.
6. Add one three-layer test room to prove the data and engine structure.
7. Write a short mechanic lock document for the v1 roster.

### Batch 1 Done Means

- We can stop treating the current prototype as the future shipping codebase.
- New work from Batch 2 onward lands in the real production runtime.

## Notes For Batch Discipline

- If visual polish work reveals readability problems, fix readability before style.
- If content production exposes tool friction, pause and improve tools before brute-forcing more rooms.
- If playtests show players are confused about a mechanic, fix onboarding before adding harder rooms with that mechanic.
- Do not add extra mechanics unless they survive a strict "does this deepen the core?" review.
