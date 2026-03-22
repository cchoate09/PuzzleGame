# Patchwork Post Design and Competitive Launch Doc

Last updated: March 22, 2026

## Executive Summary

Patchwork Post already proves the core idea: a layered 2D puzzle game where players move through aligned paper sheets, switch layers at stitched coordinates, transfer objects between layers, and eventually combine projection, echo, and shadow logic. The current prototype is a strong pre-production proof of concept, but it is not yet competitive for a premium Steam launch.

Recommendation:

- Keep the game in 2D and push the presentation toward a 2.5D paper-diorama look instead of moving to full 3D.
- Treat the current browser build as a prototype and move the shipping version to Godot 4 for platform support, Steam integration, and long-term tooling.
- Target a competitive premium release window after the October 19-26, 2026 Steam Next Fest, not before it.
- Price target should likely land in the `US$17.99-US$19.99` range if the final game ships with strong art direction, 55+ main puzzles, a polished demo, and full Steam feature support. This pricing recommendation is an inference from the current Steam market snapshot below.

## Current Product Structure

### What exists in the prototype

- Core deterministic grid-based puzzle simulation with:
  - movement
  - pushable entities
  - layer switching at stitched coordinates
  - transfer between layers
  - pressure plates and linked doors
  - projection bridges
  - delayed echo actors
  - mirrored shadow actors
  - sticky latches
- Core UX support:
  - unlimited undo/redo
  - reset
  - replay of current or best-known solution
  - save snapshots
  - optional hints
  - keyboard remapping
  - gamepad polling
  - high contrast mode
  - reduced motion toggle
  - font scaling
- Campaign shell:
  - world map with district unlocking via postmarks
  - journals and achievements
  - room JSON preview and validation tools
- Prototype content:
  - 8 handcrafted rooms
  - 7 districts represented in the structure
  - 1 optional secret route

### What the current structure implies

The prototype already supports the right genre foundation:

- systemic logic rather than one-off gimmicks
- a world-map wrapper that can support branching progression
- low asset requirements per room
- Steam Deck-friendly interaction patterns
- internal content tooling early in production

The main risk is not the core mechanic. The main risk is shipping with too little content, too little presentation identity, and too little onboarding polish relative to the best modern Steam puzzle games.

## Core Product Vision For Launch

### Pillars

1. Readable systemic depth
   Every room should be understandable at a glance, but solving it should require one sharp logical insight.

2. Warm papercraft identity
   The game should feel distinct from abstract puzzle games through its materiality, town setting, and handcrafted paper presentation.

3. Welcoming challenge
   The game should be difficult, but never hostile. Optional hints, rapid reset, clear iconography, and nonlinear side routes should preserve momentum.

4. Discovery beyond the critical path
   Optional rooms, journals, secrets, and late-game twists should reward mastery and encourage community discussion.

### Shipping scope target

- 55 to 60 mainline puzzles
- 15 to 20 optional puzzles
- 6 to 10 hour first playthrough
- 7 districts plus 1 secret postgame route
- 20 to 30 Steam achievements
- 1 launch demo with save carryover
- 8 to 10 interface languages if budget allows

### Recommended mechanic stack

Keep the current core stack and add only one more late-game modifier system. Do not add three or four more mechanics just to increase feature count.

Recommended shipping stack:

- layer switching
- transfer
- pressure plates and doors
- projection bridges
- echoes
- shadows
- sticky latches
- one late-game routing modifier

Recommended late-game modifier:

- `Routing Stamps`: special address marks that redirect a transfer, projection, or stitch exit by one tile or to a tagged coordinate.

Why this is a good fit:

- it extends the existing "mail route" theme
- it multiplies puzzle possibility without requiring a brand new control scheme
- it gives marketing a stronger second sentence beyond "switch layers"

## Competitive Benchmark Snapshot

Market snapshot below is based on Steam store and Steamworks documentation viewed on March 22, 2026.

| Game | Current Steam signal | Competitive lesson for Patchwork Post |
| --- | --- | --- |
| [Patrick's Parabox](https://store.steampowered.com/app/1260520/Patricks_Parabox/) | `US$19.99`, 4,568 Steam purchaser reviews, `Overwhelmingly Positive`, 350+ handcrafted puzzles, demo, 22 achievements, 10 languages | The bar for a single-system logic game is very high if the systemic depth is exceptional and content density is strong. |
| [Can of Wormholes](https://store.steampowered.com/app/1295320/Can_of_Wormholes/) | `US$19.99`, 512 Steam purchaser reviews, `Overwhelmingly Positive`, 100+ handcrafted stages, interactive overworld, playable hints, explicit accessibility notes | Puzzle players respond well to dense content, clean support systems, and discoverable hinting that does not feel like surrender. |
| [Paper Trail](https://store.steampowered.com/app/1889740/Paper_Trail/) | `US$19.99`, 622 Steam purchaser reviews, `Overwhelmingly Positive`, 35 achievements, 13 languages, strong paper-world art direction | A paper-themed puzzle game needs striking visual identity and worldbuilding, not just a paper mechanic. |
| [A Monster's Expedition](https://store.steampowered.com/app/1052990/A_Monsters_Expedition/) | `US$19.99`, 1,426 Steam purchaser reviews, `Very Positive`, hundreds of islands, open-world nonlinear progression, 14 languages | Nonlinear exploration broadens puzzle appeal and reduces frustration when players get stuck. |
| [Isles of Sea and Sky](https://store.steampowered.com/app/1233070/Isles_of_Sea_and_Sky/) | 1,277 Steam purchaser reviews, `Very Positive`, open world, multiple endings, 21 achievements, 15 languages | A larger sense of place and optional discovery can make a puzzle game feel substantial even without lavish production. |
| [Bonfire Peaks](https://store.steampowered.com/app/1147890/Bonfire_Peaks/) | `US$19.99`, 267 Steam purchaser reviews, `Very Positive`, demo, 41 achievements, DLC, strong art presentation | Visual identity and post-launch support matter, especially when content volume is lower than category leaders. |
| [Void Stranger](https://store.steampowered.com/app/2121980/Void_Stranger/) | `US$11.99`, 3,000 Steam purchaser reviews, `Very Positive`, 2D, story-rich mystery framing | Secrets, mood, and meta layers can generate evangelism, but higher harshness narrows the audience. |

### Market inference

Inference from the titles above:

- The strongest premium puzzle games on Steam usually win with one killer systemic hook plus either:
  - standout visual identity
  - nonlinear exploration and secrets
  - unusually high content density
- Patchwork Post already has the hook, but it currently lacks enough of the other three.

## Gap Analysis

### 1. Gameplay and content depth

Current state:

- 8 rooms total
- one room per major mechanic
- no meaningful late-game recombination curve yet
- no three-layer mastery rooms

Gap versus competitive launch:

- needs roughly 8x more handcrafted content
- needs stronger mastery ramps within each district
- needs optional side-route challenges that feel meaningfully different from mainline rooms
- needs at least one late-game mechanic modifier so the back half does not feel like simple recombination only

Recommendation:

- structure each district as:
  - 6 to 8 main rooms
  - 2 to 3 optional rooms
  - 1 capstone room
- add true three-layer rooms in the Theater or Rooftops, not just two-layer rooms with more entities

### 2. Puzzle balance and fairness

Current state:

- hints exist, but they are static text only
- there is no expert move target, difficulty tracking, or analytics
- validation catches structural issues, but not room elegance or discovery quality

Gap versus competitive launch:

- modern Steam puzzle audiences expect strong fairness, not just solvability
- the best games in this space teach by level structure, not only by hint text

Recommendation:

- add room design metadata:
  - target difficulty
  - intended lesson
  - expected solve time
  - common failure mode
- add a ghost-based tier-3 hint instead of text only
- add transfer and projection previews so players can reason visually before committing
- internally track:
  - first-solve time
  - reset count
  - hint usage
  - abandonment rate per room

### 3. Progression and macro structure

Current state:

- world map exists
- districts unlock by postmarks
- optional rooms exist, but the macro structure is still very light

Gap versus competitive launch:

- compared with A Monster's Expedition and Isles of Sea and Sky, the world currently feels like a wrapper, not a place

Recommendation:

- make each district a small explorable paper map rather than just a menu of rooms
- hide optional journal pages, route seals, and secret letters in side content
- add one secret thread that spans multiple districts and resolves in the Attic
- ensure players can skip some optional difficulty spikes without losing access to credits

### 4. Visual identity

Current state:

- prototype visuals are readable and pleasant
- presentation is still tool-grade rather than commercial

Gap versus competitive launch:

- Paper Trail demonstrates how much a paper theme gains from cohesive, memorable art direction
- Bonfire Peaks demonstrates how much polish and atmosphere can elevate simple block movement

Recommendation:

- stay 2D, but present the game as layered 2.5D paper dioramas
- add:
  - torn paper edges
  - stitched seams
  - subtle lift shadows between layers
  - small ambient flutter animation
  - district-specific color scripts
  - character portrait cards for dialogue
  - more expressive mailbox, parcel, and route icon silhouettes
- avoid full 3D camera movement; it will raise production cost and reduce spatial readability

### 5. Audio and feel

Current state:

- no shipping-grade soundtrack or final sound design

Gap versus competitive launch:

- category leaders often use music and soft feedback to make difficult thinking feel inviting

Recommendation:

- add a bespoke soundtrack with district motifs
- build a full paper-and-post sound palette:
  - paper slide
  - soft stamp thud
  - stitched flip
  - lantern hum
  - echo shimmer
  - shadow hush
- make audio feedback mechanically informative, not just decorative

### 6. Accessibility and controls

Current state:

- strong foundation: remapping, high contrast, reduced motion, font scaling, gamepad polling

Gap versus competitive launch:

- compared with Can of Wormholes, accessibility messaging is not yet explicit enough and the UX support is not fully surfaced
- Steam Input and controller glyph support are not production-ready

Recommendation:

- ship with:
  - full controller support
  - Steam Input action manifest
  - correct controller glyph swapping
  - mouse and controller simultaneous compatibility
  - no color-only communication
  - full text scaling and readable Steam Deck layouts
- add an in-game accessibility page that states constraints clearly:
  - no timed inputs
  - no required audio
  - no color-only logic

### 7. Tooling and production workflow

Current state:

- JSON room editing
- structural validation
- preview loading

Gap versus competitive launch:

- content production at 70+ rooms will be too slow and error-prone without stronger tools

Recommendation:

- build a visual room editor with:
  - tile painting
  - entity palette
  - layer visibility toggles
  - switch-door linking UI
  - hint authoring
  - test from cursor
  - export to room data
- add automated regression tests for all canonical solutions
- build a room browser for batch balance review

### 8. Steam and commercial readiness

Current state:

- no Steam-native integration
- no shipping engine target
- no demo app
- no store page assets
- no trailer
- no localization pipeline

Gap versus competitive launch:

- this is currently the largest non-design gap

Recommendation:

- move the product to Godot 4 for the shipping build
- implement:
  - Steam achievements
  - Steam Cloud
  - Steam Input action manifest and glyph support
  - Steam Deck review process
  - demo app and save carryover
- prepare:
  - key art
  - capsules
  - screenshot set
  - gameplay trailer
  - polished demo page copy

## Features Required To Be Competitive

### Must-have before launch

- 55 to 60 main puzzles plus 15 to 20 optional puzzles
- one polished demo with save carryover
- one additional late-game modifier mechanic
- three-layer capstone rooms
- production-quality visual identity
- full soundtrack and sound design
- controller parity and Steam Deck polish
- Steam achievements, Steam Cloud, Steam Input manifest
- 8 to 10 interface languages if budget allows
- strong hint system with a ghost or guided tier-3 hint

### Should-have before launch

- interactive district maps with secrets
- route seal collectibles or another optional mastery currency
- internal difficulty and solve-time telemetry
- richer character portraits and interstitials
- cleaner visual content tools

### Nice-to-have after launch

- challenge update or secret epilogue
- soundtrack DLC
- extra puzzle pack
- optional photo mode or replay-sharing clips

### Features to avoid for v1

- full user-generated level sharing
- procedural puzzles
- voice acting
- full 3D conversion
- combat or action-adventure detours

These would add scope much faster than they add competitive value.

## Balance and Content Standards

### District pacing model

Use this structure for each district:

1. teach the mechanic in a safe room
2. reinforce it in a clearer but slightly trickier room
3. combine it with one old rule
4. subvert the assumed use of the mechanic
5. deliver a capstone that tests synthesis

### Difficulty standards

- mainline rooms should introduce one new rule or one new interaction pattern at a time
- optional rooms may spike harder, but should reward that spike with secrets or mastery currency
- no room should rely on hidden rules
- players should be able to explain the solve after they complete it

### Hint standards

- tier 1: restate the goal in a better framing
- tier 2: identify the relevant mechanic
- tier 3: show the opening sequence or ghost

### Achievement standards

Target `20-30` achievements, mostly tied to:

- district clears
- optional route clears
- no-hint milestones
- secret discoveries

Avoid clutter achievements for trivial actions.

## Art and Audio Direction

### Visual direction

Recommended visual brief:

- illustrated paper town
- tactile edges and seams
- low animation count, high composition quality
- warm daylight palette, not generic white-minimal
- strong silhouettes for parcels, stitches, lanterns, echoes, and shadows

### Production targets

- one final key-art illustration
- one title-screen illustration
- one set of district palette guides
- one reusable character portrait system
- polished transitions for:
  - entering a room
  - switching layers
  - solving a room
  - opening a secret route

### Audio direction

- 45 to 60 minutes of adaptive or district-themed music
- signature paper-physics sound palette
- subtle UI audio that supports thinking instead of interrupting it

## Recommended Steam Launch Plan

### Timing recommendation

Do not target the June 15-22, 2026 Steam Next Fest from the current state. The prototype is too early for a competitive showing.

Recommended launch path:

- Coming Soon page live by August 2026
- Steam Next Fest participation: October 19-26, 2026
- full release target: February or March 2027

Why:

- Steam requires a Coming Soon page for at least two weeks before release, but competitive wishlist-building usually needs much longer
- the October 2026 festival is the first realistic festival window for a polished demo from the current state
- an early 2027 release leaves enough room for playtesting, localization, Deck review, and demo polish

### Milestone plan

#### Phase 1: Product lock and shipping architecture
April 2026

- finalize mechanic list
- choose shipping engine and start Godot migration
- define art target and audio target
- build a 10 to 12 room golden path in the shipping runtime

Exit criteria:

- one district looks close to final quality
- full save, hint, and controller loop works in the shipping build

#### Phase 2: Vertical slice and store prep
May to July 2026

- finish first 15 to 20 rooms
- implement visual room editor
- capture trailer-worthy footage
- prepare store branding and capsule art

Exit criteria:

- first strong public-facing slice exists
- store copy can accurately describe the full game

#### Phase 3: Coming Soon and demo production
August to September 2026

- publish Coming Soon page
- release or privately test the demo app
- begin creator outreach, festival applications, and community beats
- localize store page and demo text

Exit criteria:

- demo is festival-ready
- store page has polished screenshots and trailer

#### Phase 4: Next Fest push
October 19-26, 2026

- participate in Steam Next Fest
- run a livestream plan
- collect demo analytics, bug reports, and wishlist conversion signals

Exit criteria:

- top friction rooms identified
- demo conversion and retention patterns understood

#### Phase 5: Content complete and release prep
November 2026 to January 2027

- finish remaining campaign content
- content lock
- request Steam Deck review
- finalize achievements, cloud saves, and controller polish
- do full regression, localization QA, and trailer refresh

Exit criteria:

- release candidate is stable
- review keys, launch communications, and discount plan are ready

#### Phase 6: Launch and first update
February to March 2027

- launch the base game
- ship one quality-of-life patch within 2 weeks
- ship one meaningful content or challenge update within 6 to 10 weeks

## Business and Positioning Recommendations

### Pricing

Recommended price band:

- `US$17.99` if the game launches with solid content but modest presentation
- `US$19.99` if the art, audio, demo, and localization package are strong

This is an inference from the current market snapshot:

- Patrick's Parabox, Paper Trail, Can of Wormholes, Bonfire Peaks, and A Monster's Expedition are all positioned around `US$19.99`
- Void Stranger sits lower at `US$11.99`, but it accepts a harsher, more niche presentation profile

### Commercial targets

Internal recommendation, not a Steam rule:

- minimum wishlist comfort target before launch: `10,000`
- stronger competitive target: `20,000+`

Patchwork Post does not need to become a mass-market hit, but it does need enough audience momentum that the demo and launch trailer get surfaced to the right puzzle audience.

### Best positioning sentence

Current best positioning:

"A layered paper-town puzzle game where every solution is hidden across multiple stitched sheets."

Stronger shipping version:

"Restore a folded paper town by switching between stitched layers, rerouting parcels, and solving one-room logic machines that only make sense when the whole letter is read at once."

## Final Recommendation

Patchwork Post is viable and promising, but only if it avoids the most common indie puzzle failure mode: shipping a good mechanic with too little content and too little identity.

To be competitive on Steam, the game needs:

- more content
- stronger visual identity
- better onboarding polish
- at least one more late-game modifier
- a real demo and Steam-facing production plan

It does not need:

- 3D
- procedural generation
- a level editor at launch
- many more mechanics

The right move is to deepen the existing design, not broaden it indiscriminately.

## Sources

- Prototype structure from local project files:
  - [campaign.js](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/src/data/campaign.js)
  - [engine.js](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/src/game/engine.js)
  - [main.js](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/src/main.js)
  - [progress.md](C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/progress.md)
- Steam market references:
  - [Patrick's Parabox](https://store.steampowered.com/app/1260520/Patricks_Parabox/)
  - [Can of Wormholes](https://store.steampowered.com/app/1295320/Can_of_Wormholes/)
  - [Paper Trail](https://store.steampowered.com/app/1889740/Paper_Trail/)
  - [A Monster's Expedition](https://store.steampowered.com/app/1052990/A_Monsters_Expedition/)
  - [Isles of Sea and Sky](https://store.steampowered.com/app/1233070/Isles_of_Sea_and_Sky/)
  - [Bonfire Peaks](https://store.steampowered.com/app/1147890/Bonfire_Peaks/)
  - [Void Stranger](https://store.steampowered.com/app/2121980/Void_Stranger/)
- Steamworks references:
  - [Demos](https://partner.steamgames.com/doc/store/application/demos)
  - [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon)
  - [Steam Cloud](https://partner.steamgames.com/doc/features/cloud)
  - [Steam Input: Getting Started for Developers](https://partner.steamgames.com/doc/features/steam_controller/getting_started_for_devs)
  - [Stats and Achievements](https://partner.steamgames.com/doc/features/achievements)
  - [Steam Deck Compatibility Review Process](https://partner.steamgames.com/doc/steamdeck/compat?l=english)
  - [Upcoming Steam Events](https://partner.steamgames.com/doc/marketing/upcoming_events)
