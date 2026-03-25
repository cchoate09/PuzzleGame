# Patchwork Post: Steam Launch Improvement Recommendations

Last updated: March 24, 2026

## Executive Summary

Patchwork Post has a strong technical foundation: a deterministic puzzle simulation, unlimited undo/redo, a demo-to-full carryover system, an in-engine authoring toolkit, accessibility toggles, and a complete 31-room campaign across 7 districts. The core mechanic — layer switching with routing stamps — is novel and defensible.

The game is not yet competitive for a premium Steam launch. The gaps are not in the core simulation; they are in content density, visual identity, audio, and Steam integration. This document details specific, actionable improvements organized into three effort tiers.

**Launch target:** February–March 2027, following the October 19–26, 2026 Steam Next Fest.
**Price target:** US$17.99–US$19.99.
**Existing competitive analysis:** See `docs/patchwork-post-design-and-launch.md` for market positioning and milestone planning.

---

## Tier Summary Table

| Area | Tier | Key Gap | Primary Files Affected |
|---|---|---|---|
| Puzzle content | Must-Ship | 31 rooms vs. 55–60 target | `data/source/campaign.json` |
| Visual identity | Must-Ship | Procedural rendering only, no authored art | `godot/scripts/ui/room_view.gd` |
| Audio | Must-Ship | Synth-only, no music or Foley | `godot/scripts/ui/audio_manager.gd` |
| Steam integration | Must-Ship | All Steamworks calls are stubs | `godot/scripts/platform/steam_bridge.gd` |
| Store readiness | Must-Ship | No assets, no page, no trailer | — |
| UX & onboarding | High-Value | No tutorial flow, tier-3 hint is text only | `godot/scripts/main.gd`, `godot/scripts/core/patchwork_engine.gd` |
| Accessibility | High-Value | No colorblind modes, no localization | `godot/scripts/ui/room_view.gd`, `godot/scripts/main.gd` |
| Progression feel | High-Value | District list feels like a menu | `godot/scripts/main.gd` |
| Post-launch content | Post-Launch | No DLC pipeline | — |

---

## 1. Puzzle Content (Must-Ship)

### Gap
The campaign contains 31 rooms (21 main route + 10 optional). A competitive Steam puzzle game at $17.99–$19.99 typically ships with 55–100+ rooms. Patchwork Post needs roughly 25 additional main-route rooms and 5–10 more optional rooms.

### Recommendations

**1.1 Expand each district to the target room count.**

Current totals vs. target:

| District | Current Main | Current Optional | Target Main | Target Optional |
|---|---|---|---|---|
| Mailroom | 4 | 1 | 6–7 | 2–3 |
| Market | 3 | 2 | 6–7 | 2–3 |
| Greenhouse | 4 | 1 | 6–7 | 2–3 |
| Clocktower | 3 | 1 | 6–7 | 2–3 |
| Theater | 3 | 1 | 7–8 | 2–3 |
| Rooftops | 4 | 1 | 7–8 | 2–3 |
| Attic | 3 | 0 | 5–6 | 1–2 |

Use the five-step pacing model already defined in the design doc for each district:
1. Teach the mechanic in a safe environment.
2. Reinforce it with a slightly harder variation.
3. Combine it with one earlier rule.
4. Subvert the assumed use of the mechanic.
5. Deliver a capstone that tests synthesis.

**1.2 Add true three-layer capstone rooms.**

The current campaign uses two-layer rooms throughout. Three-layer rooms are explicitly supported by `patchwork_engine.gd` and the room schema (`layers` array supports any count) but are not yet authored. Add at least two three-layer capstone rooms — one in Theater, one in Rooftops — to demonstrate the full depth of the system.

**1.3 Enforce balance metadata on all rooms.**

The room schema already supports `balance` metadata:
- `lesson` — what the player is meant to learn
- `difficulty` — expected challenge rating
- `expectedTime` — estimated solve time in minutes
- `commonMistakes` — list of failure modes

This data is authored in some rooms but not enforced. Require all new and existing rooms to have complete `balance` fields. This data feeds playtesting prioritization and hint quality.

**1.4 Upgrade tier-3 hints to ghost playback.**

Currently tier-3 hints are static text strings. The replay system in `godot/scripts/core/patchwork_engine.gd` already supports time-stepped action playback (260 ms per step). Extend this to drive a semi-transparent ghost actor that shows the opening sequence of the canonical solution. This makes tier-3 hints feel like guidance rather than surrender.

The canonical solutions are already stored in `data/source/solutions.json` and loaded via `godot/scripts/core/content_loader.gd`. The replay infrastructure exists; this is a UI-layer addition.

**1.5 Add action preview overlays.**

Before a player commits a transfer or projection, show a brief visual indicator of where the object will land. This reduces trial-and-error resets and makes the spatial logic more legible. Implement as a preview pass in `godot/scripts/ui/room_view.gd` triggered by the input hold state from `godot/scripts/core/patchwork_input.gd`.

---

## 2. Visual Identity (Must-Ship)

### Gap
All rendering is done via Godot's 2D DrawAPI in `godot/scripts/ui/room_view.gd`. The output is readable and stylistically coherent, but it is tool-grade: flat solid colors, no texture, no authored sprite assets, no animated effects beyond simple lerp transitions. Competing games like Paper Trail and Bonfire Peaks demonstrate how much a distinctive visual identity affects reception.

### Recommendations

**2.1 Commission key art and illustration assets.**

Required before store readiness:
- One final key art illustration (capsule hero image)
- One title screen illustration
- One set of district palette swatches (extend the existing color constants in `room_view.gd`)
- Character portrait cards for dialogue overlays (the overlay system in `godot/scripts/main.gd` already renders speaker attribution text — portraits slot in as texture nodes)

**2.2 Add authored background textures.**

Replace the flat desk color (`#dcc39a`) with a scanned or illustrated paper-grain texture. This one change significantly increases the sense of materiality without requiring a full art overhaul. Implement as a background TextureRect behind the room canvas in `godot/scenes/main.tscn`.

**2.3 Add idle animations to the layer cards.**

Small ambient motion makes the game feel alive during the thinking phase:
- Subtle paper flutter (gentle sinusoidal offset) on inactive layer cards
- Parcel sway (idle oscillation) when the player is stationary
- Stitch thread pulse (slow opacity fade) to draw attention to available layer transitions

These can be implemented as lightweight Tween loops in `godot/scripts/ui/room_view.gd`. Add a check against the `reducedMotion` setting to skip them.

**2.4 Polish solve and unlock transitions.**

The current solve flash is a simple palette tint fade. Replace or augment with:
- **Solve celebration:** a stamp-thud visual with a postmark ring expanding outward, followed by a confetti scatter of paper scraps.
- **Secret route unlock:** a letter-seal breaking animation with a brief district-color flourish.
- **Room entry:** the current slide-in animation is functional; add a page-fold effect at the start.

Implement using Godot's `AnimationPlayer` or `Tween` in `room_view.gd`, gated by `reducedMotion`.

**2.5 Improve actor silhouettes.**

The current actors are rendered as simple geometric shapes. Improve distinctiveness:
- **Parcels:** render as tied paper boxes with a visible string knot on top.
- **Projectors:** render as paper lanterns with a visible light cone.
- **Echoes:** render as ripple rings to reinforce the delay metaphor.
- **Shadows:** render with a soft mirror-blurred edge to reinforce the mirroring mechanic.

These are still procedural drawing changes in `room_view.gd` — no external sprite assets required unless a higher quality bar is desired.

---

## 3. Audio (Must-Ship)

### Gap
All audio is generated at runtime by `godot/scripts/ui/audio_manager.gd` using additive sine/triangle/square synthesis. There is no music, no authored sound design, and no ambient audio. The procedural sounds are functional as placeholder feedback but are not suitable for a commercial release. The audio style guide at `docs/batch-2-audio-style-guide.md` already describes the target direction; it needs to be produced.

### Recommendations

**3.1 Commission a full soundtrack.**

Target: 45–60 minutes of adaptive or district-themed music.

Suggested track list:
- Main menu / overworld theme
- 7 district themes (Mailroom, Market, Greenhouse, Clocktower, Theater, Rooftops, Attic)
- Puzzle-completion stinger (short)
- District-unlock fanfare (short)
- Demo completion beat
- Full campaign completion theme

Tracks should be looping `.ogg` files with a separate intro segment for seamless looping. Load via Godot's `AudioStreamPlayer` with bus routing (see 3.4).

**3.2 Replace procedural SFX with authored Foley.**

The audio style guide describes the target palette. Prioritized replacement order:

| Event | Current (synth) | Target (Foley) |
|---|---|---|
| `move` | 420 Hz triangle tap | Paper slide on felt |
| `push` | 210+310 Hz thump | Soft parcel thud |
| `switch_layer` | 370+554 Hz dual-tone | Paper page flip + stitch snap |
| `transfer` | 260+390 Hz shimmer | Object pass-through crinkle |
| `solve` | Stacked harmonic cadence | Postmark stamp + celebration ring |
| `reset` | 180+96 Hz wash | Paper sheet flatten |
| `hint` | 620 Hz ping | Soft envelope tap |
| `enter` | 240+360 Hz cue | Room atmosphere settle |

Record as `.ogg` files, load in `audio_manager.gd`, and keep the procedural generator as a fallback for missing assets during development.

**3.3 Add ambient district beds.**

Add a low-volume looping ambient layer per district that plays under music:
- Mailroom: postal sorting clicks, distant paper shuffling
- Market: soft crowd murmur, wind
- Greenhouse: birdsong, water drip
- Clocktower: tick, distant bell
- Theater: muffled applause, curtain sway
- Rooftops: wind, distant city
- Attic: dust settle, creak

**3.4 Add Godot audio bus structure and volume controls.**

Currently `audio_manager.gd` routes everything to the Master bus at -8.0 dB with no sub-buses. Add:
- `Music` bus (routed to Master)
- `SFX` bus (routed to Master)
- `Ambient` bus (routed to Master)

Expose three volume sliders in the settings panel in `godot/scripts/main.gd`:
- Master volume
- Music volume
- Sound effects volume

Store values in the settings section of `patchwork_save.gd` alongside `highContrast`, `reducedMotion`, and `fontScale`.

---

## 4. Steam Integration (Must-Ship)

### Gap
`godot/scripts/platform/steam_bridge.gd` is a stub that checks for `Engine.has_singleton("Steam")` and returns placeholder values. No Steamworks calls are live. The Steam Input manifest at `steam/input/patchwork-post-steam-input.json` is drafted but not published. Achievements are defined in `data/source/campaign.json` but never sent to Steam.

### Recommendations

**4.1 Integrate GodotSteam.**

Add the [GodotSteam](https://godotsteam.com/) plugin to `godot/addons/`. Replace the stub in `steam_bridge.gd` with live Steamworks calls for:
- App initialization (`Steam.steamInit()`)
- Achievement unlock (`Steam.setAchievement(id)` + `Steam.storeStats()`)
- Cloud save read/write (see 4.3)
- Input glyph queries (see 4.4)

**4.2 Wire all achievements to live Steamworks calls.**

All 9 current achievements are defined in `campaign.json` with IDs already matching Steam API naming conventions. The unlock flow exists in `patchwork_save.gd` via `pendingAchievements`. Replace the pending-sync stub in `steam_bridge.gd` with a real `setAchievement` call on app initialization (flush pending) and on each new unlock.

Expand to 20–30 total achievements per the design doc target. Suggested additions:
- Per-district completion awards (7 achievements)
- No-hint completion for each district (7 achievements)
- Speed-solve medals for capstone rooms
- Secret letter collection milestones

**4.3 Implement Steam Cloud save.**

The save schema in `patchwork_save.gd` already has a `cloudSlot` field. Implement sync:
- On save: write profile JSON to Steam Remote Storage alongside the local `user://` path
- On load: compare timestamps and prefer the more recent version
- Surface sync status via the existing `steam_status_label` in `godot/scripts/main.gd`

**4.4 Wire the Steam Input action manifest and controller glyphs.**

The action manifest at `steam/input/patchwork-post-steam-input.json` defines 13 gameplay actions and menu navigation bindings. Steps:
1. Register the manifest with Steamworks at app setup.
2. Query active controller type on input source change (detected in `patchwork_input.gd`).
3. Replace the static button label strings in the controls display (e.g., "A", "X", "LB") with platform-correct glyph images sourced from the Steam Input API or a local glyph atlas for Xbox/PS/Switch/Steam Deck layouts.

**4.5 Submit for Steam Deck Verified review.**

Prerequisites before submission:
- All UI navigable without mouse
- No required keyboard input (already true)
- Full screen at 1280×800 (current viewport is 1366×768 — verify stretch behavior)
- No small unreadable text (font scaling already implemented)
- Controller glyphs display correctly (see 4.4)

---

## 5. Store & Launch Readiness (Must-Ship)

### Gap
No store page, no screenshots, no trailer, no Coming Soon page, no localized copy.

### Recommendations

**5.1 Store asset checklist.**

Required before Coming Soon page (target: August 2026):
- [ ] Capsule art (460×215, 231×87, 616×353)
- [ ] Header capsule (460×215)
- [ ] Hero graphic (1920×620, optional)
- [ ] 6 store screenshots at 1920×1080 (one per mechanic: layer switching, transfer, projection, echo, shadow, routing stamp)
- [ ] 30-second teaser trailer
- [ ] 90-second full gameplay trailer
- [ ] Short description (≤300 characters)
- [ ] Full store description with features list

**5.2 Use the recommended positioning sentence.**

From the design doc:

> "Restore a folded paper town by switching between stitched layers, rerouting parcels, and solving one-room logic machines that only make sense when the whole letter is read at once."

**5.3 Localize store copy.**

Localize the store page short description, full description, and feature bullet points into 8–10 languages before the Coming Soon page goes live. In-game localization can follow later (see Section 7), but store copy localization is low cost and directly expands wishlist conversion.

Suggested initial languages based on Steam puzzle game audience: English, German, French, Spanish, Portuguese (BR), Simplified Chinese, Japanese, Russian, Korean, Italian.

**5.4 Follow the milestone plan from the design doc.**

| Milestone | Target Date |
|---|---|
| Coming Soon page live | August 2026 |
| Steam Next Fest participation | October 19–26, 2026 |
| Content complete | November 2026 |
| Steam Deck review submitted | December 2026 |
| Release candidate | January 2027 |
| Launch | February–March 2027 |

---

## 6. UX & Onboarding (High-Value)

### Gap
Mechanics are introduced entirely through room design and static hint text. There is no tutorial sequence, no pause menu during gameplay, and the tier-3 hint is text-only. The playtest logger collects per-room analytics but they are never surfaced to players.

### Recommendations

**6.1 Add environmental tutorial cues in the Mailroom.**

Do not add UI tutorial popups. Instead, use the existing dialogue/intro system to deliver contextual cues at the room level. The `intro` field in the room schema already supports per-room dialogue. Add:
- Room `mailroom-01`: A brief intro card from the postmaster explaining the layer-switching mechanic in in-world language ("the stamps connect matching corners of each sheet").
- Room `mailroom-02`: An intro card for the transfer mechanic.
- Room `mailroom-03`: An intro card for pressure plates and doors.

These already render via the `_show_dialogue()` flow in `godot/scripts/main.gd`.

**6.2 Upgrade tier-3 hints to ghost playback (see also 1.4).**

Wire the `hintTiers[2]` slot to trigger a ghost replay using `patchwork_engine.gd`'s existing replay system. Display the ghost as a semi-transparent duplicate of the player actor. Keep the text hint as a subtitle below the board for players who find the ghost distracting.

**6.3 Add an in-room pause menu.**

Currently the settings panel is only accessible from the map view. Add a pause overlay triggered by `ui_cancel` (already mapped to a controller button and Escape key via `patchwork_input.gd`) that exposes:
- Resume
- Reset room
- View hints
- Settings (subset: audio, accessibility)
- Return to map

**6.4 Add a per-room "record card" on completion.**

On solving a room, display a brief overlay showing:
- Move count vs. best (from `bestMoves` in save profile)
- Whether hints were used (`hintsRevealed` count)
- A "replay best route" button (already wired via the replay system)

This rewards optimization and makes repeat solves feel meaningful.

**6.5 Add controller glyph swapping.**

Detect the active input source in `patchwork_input.gd` (the polling system already differentiates keyboard and gamepad) and display platform-correct button icons in the controls display and hint prompts. Maintain a small glyph atlas for Xbox, PlayStation, Nintendo Switch, and Steam Deck layouts.

---

## 7. Accessibility (High-Value)

### Gap
The existing accessibility system (high-contrast toggle, reduced-motion toggle, font scaling) is a strong foundation. The gaps are colorblind-specific palette variants, an explicit in-game accessibility statement, and no localization pipeline.

### Recommendations

**7.1 Add colorblind palette presets.**

No color-only communication already exists in the design (all state communicated via shape + color), which is the hard part. The remaining work is tuning the color constants in `room_view.gd` to remain distinguishable under:
- Deuteranopia (red-green, most common)
- Protanopia (red-green, less common)
- Tritanopia (blue-yellow, rare)

Add three named palette override modes to the settings panel alongside the existing high-contrast toggle. Store the selection in `patchwork_save.gd` settings.

**7.2 Add an in-game accessibility page.**

Add a dedicated accessibility section to the settings panel that explicitly states:
- No timed inputs anywhere in the game
- No required audio cues (all logic is visual)
- No color-only logic (state communicated by shape and position)
- Available options: high contrast, colorblind modes, reduced motion, font scaling, full remapping

This is a two-sentence-per-point text card in the existing settings layout. It signals quality to accessibility-conscious players and reviewers.

**7.3 Build a localization pipeline.**

Start with string extraction before writing all remaining rooms and UI text. Steps:
1. Replace all hardcoded UI strings in `godot/scripts/main.gd` with `tr()` calls using translation keys.
2. Create a base `.po` or Godot `.translation` resource file for English.
3. Submit for machine translation of the 8–10 target languages; plan for human review of at least 3 priority languages (German, Simplified Chinese, Japanese) before launch.

Do not block room authoring on this — author all content in English and localize in a final pass.

**7.4 Audit settings UI for keyboard and controller navigability.**

Walk through the entire settings panel in `godot/scripts/main.gd` using only keyboard (Tab/arrow keys) and only a gamepad. Identify any interactive elements that cannot be focused or activated without a mouse. Fix focus order and ensure all sliders and buttons emit correct `focus_entered` signals.

---

## 8. Progression & World Feel (High-Value)

### Gap
The district list in the main UI functions correctly but feels like a menu. Competing games like A Monster's Expedition and Isles of Sea and Sky create a sense of place through exploration, not just selection.

### Recommendations

**8.1 Replace the district list with an illustrated district map view.**

This is a visual-only change — the underlying unlock logic in `patchwork_save.gd` and `main.gd` stays the same. Instead of a `VBoxContainer` of district buttons, render each district as a named location on a paper-style town map. Clicking a district zooms in to the room selection view.

This does not require new mechanics and does not change how rooms are accessed. It significantly improves the first impression of the world.

**8.2 Make optional content feel discoverable, not gated.**

Currently optional rooms are listed alongside main rooms. Add visual differentiation:
- Main-route rooms: standard postcard frame
- Optional rooms: slightly torn-edge frame with a "side route" ribbon
- Secret rooms: hidden until a discovery condition is met, then revealed with a flourish

Ensure the Attic route has at least one in-world hint (a note, a postmark, a sealed letter) visible before its unlock condition is met, so players know something hidden exists.

**8.3 Surface the hidden journal entries more actively.**

Five hidden journal entries exist in `campaign.json` but their discovery conditions are not clearly signposted. Add a visible "?" slot in the journal UI for each missing entry, so players who care about narrative completeness know to keep looking.

---

## 9. Post-Launch (Nice-to-Have)

These items should not block launch but should be planned for a first content update.

**9.1 Soundtrack DLC.**

Package the commissioned soundtrack as a separate Steam DLC. This is low-cost, expected by puzzle game audiences, and provides an additional revenue line.

**9.2 Challenge update or secret epilogue.**

A free update 6–10 weeks post-launch with 5–10 new high-difficulty rooms keeps the game visible on Steam and rewards players who cleared everything. Reference the existing Attic aesthetic as the delivery vehicle.

**9.3 Replay clip sharing.**

The replay system in `patchwork_engine.gd` stores complete action sequences. A post-launch update could export a short animated GIF or video clip of a solve for social sharing. Use Godot's `SubViewport` capture or a third-party GIF encoder add-on.

**9.4 Extra puzzle pack.**

A paid DLC expansion with 15–20 new rooms across 2–3 new mini-districts. Plan the room schema to accommodate new district IDs without breaking save compatibility (the `districtId` field is already freeform string).

---

## Sources

- Codebase exploration of `C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/` (March 24, 2026)
- `docs/patchwork-post-design-and-launch.md` — competitive analysis and milestone planning
- `docs/batch-2-audio-style-guide.md` — audio production direction
- `docs/batch-2-ui-style-guide.md` — visual design direction
- `godot/scripts/core/patchwork_engine.gd` — replay and simulation systems
- `godot/scripts/core/patchwork_save.gd` — save schema and Steam sync stubs
- `godot/scripts/ui/audio_manager.gd` — procedural audio implementation
- `godot/scripts/ui/room_view.gd` — rendering and animation implementation
- `godot/scripts/platform/steam_bridge.gd` — Steamworks stub
- `data/source/campaign.json` — room and achievement definitions
