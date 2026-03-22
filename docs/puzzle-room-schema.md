# Patchwork Post Room Schema

Last updated: March 22, 2026

This document locks the v1 room data shape for Batch 1. The schema is based on the current prototype and should be treated as the minimum contract future runtimes must support.

## Core Types

### `PuzzleRoom`

```js
{
  id: string,
  districtId: string,
  title: string,
  optional: boolean,
  developmentOnly?: boolean,
  unlockCost: number,
  postmarks: number,
  objective: string,
  blurb: string,
  intro: DialogueBeat[],
  achievementId?: string,
  hintTiers: [string, string, string],
  layers: RoomLayer[],
  start: PlayerStart,
  entities: Entity[],
  switches: SwitchDef[],
  doors: DoorDef[],
}
```

### `DialogueBeat`

```js
{
  speaker: string,
  text: string,
}
```

### `RoomLayer`

```js
{
  id: string,
  name: string,
  tiles: string[],
}
```

Rules:

- A room supports 2 or 3 layers in v1.
- All layers must share the same width and height.
- Tiles are stored as rows of equal-length strings.

### `PlayerStart`

```js
{
  layer: number,
  x: number,
  y: number,
  facing: "up" | "down" | "left" | "right",
}
```

### `Entity`

```js
{
  id: string,
  type: "parcel" | "projector" | "echo" | "shadow",
  layer: number,
  x: number,
  y: number,
  solid: boolean,
  pushable?: boolean,
  projectionTargets?: ProjectionTarget[],
  echoDelay?: number,
  queuedAction?: Action | null,
  mirrorAxis?: "vertical" | "horizontal",
}
```

### `ProjectionTarget`

```js
{
  layer: number,
  dx: number,
  dy: number,
}
```

### `SwitchDef`

```js
{
  id: string,
  layer: number,
  x: number,
  y: number,
  sticky?: boolean,
}
```

### `DoorDef`

```js
{
  id: string,
  layer: number,
  x: number,
  y: number,
  switchIds: string[],
}
```

## Tile Vocabulary

Supported v1 tiles:

- `#` wall
- `.` floor
- `S` stitch marker
- `G` mailbox goal
- `~` projection gap that requires an active bridge

Rules:

- A stitch must align at the same coordinates across at least two layers.
- A room must contain at least one goal tile.
- Gaps are only traversable when activated by a projector bridge.

## Runtime Behavior Contract

- Player movement is grid-based and deterministic.
- Push resolution must be deterministic and single-step.
- Transfers move a pushable entity to the next passable matching coordinate across available layers.
- Echo actors replay the previous move with a one-turn delay.
- Shadow actors mirror movement across their configured axis.
- Sticky switches remain active after first activation.
- Solved state occurs when the player stands on a `G` tile.

## Authoring Metadata Expectations

Every shipping room should also carry design metadata, even if the current runtime does not consume it yet.

Recommended additions for production authoring:

```js
{
  intendedLesson: string,
  targetDifficulty: "intro" | "easy" | "medium" | "hard" | "expert",
  expectedSolveMinutes: number,
  commonFailureMode: string,
}
```

These are not required by the current prototype, but they should be added before large-scale content production.

## Save Snapshot Contract

Any runtime snapshot used for undo or mid-room saves must preserve:

- player state
- active layer
- entity positions and per-entity state
- move count
- solved flag
- action log
- latched switch state

This is the minimum needed for deterministic restore and replay-safe saves.
