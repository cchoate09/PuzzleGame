import { clone } from "./save.js";

const DIRECTIONS = {
  up: { dx: 0, dy: -1, facing: "up" },
  down: { dx: 0, dy: 1, facing: "down" },
  left: { dx: -1, dy: 0, facing: "left" },
  right: { dx: 1, dy: 0, facing: "right" },
};

function coordKey(layer, x, y) {
  return `${layer}:${x}:${y}`;
}

function clampDistance(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return 1;
  }
  return Math.max(1, Math.floor(parsed));
}

function normalizeAction(action) {
  if (typeof action === "string") {
    return { type: action };
  }
  return { ...action };
}

function isMoveAction(action) {
  return action.type === "move" && action.direction in DIRECTIONS;
}

export class PatchworkEngine {
  constructor(campaign) {
    this.campaign = campaign;
    this.room = null;
    this.runtime = null;
    this.currentRoomId = null;
    this.previewMode = false;
    this.replayState = null;
  }

  loadRoom(roomId, snapshot = null) {
    const room = this.campaign.roomsById[roomId];
    if (!room) {
      throw new Error(`Unknown room '${roomId}'`);
    }
    this.previewMode = false;
    this.currentRoomId = roomId;
    this.room = clone(room);
    this.runtime = this.createRuntime(this.room, snapshot);
    this.replayState = null;
    return this.runtime;
  }

  loadPreviewRoom(roomData) {
    this.previewMode = true;
    this.currentRoomId = roomData.id || "__preview__";
    this.room = clone(roomData);
    this.runtime = this.createRuntime(this.room, null);
    this.replayState = null;
    return this.runtime;
  }

  createRuntime(room, snapshot) {
    const base = {
      player: {
        ...clone(room.start),
        facing: room.start?.facing || "right",
      },
      activeLayer: room.start?.layer || 0,
      entities: clone(room.entities || []),
      moveCount: 0,
      solved: false,
      actionLog: [],
      history: [],
      future: [],
      latchedSwitches: [],
      notifications: [],
    };

    if (snapshot) {
      base.player = clone(snapshot.player);
      base.activeLayer = snapshot.activeLayer;
      base.entities = clone(snapshot.entities);
      base.moveCount = snapshot.moveCount || 0;
      base.solved = !!snapshot.solved;
      base.actionLog = clone(snapshot.actionLog || []);
      base.latchedSwitches = clone(snapshot.latchedSwitches || []);
    }

    this.ensureCompanionState(base.entities);
    this.updateDynamicState(base);
    base.solved = this.isSolved(base);
    return base;
  }

  ensureCompanionState(entities) {
    for (const entity of entities) {
      if (entity.type === "echo" && entity.queuedAction == null) {
        entity.queuedAction = null;
      }
    }
  }

  getRoom() {
    return this.room;
  }

  getRuntime() {
    return this.runtime;
  }

  getRoomSnapshot() {
    if (!this.runtime) {
      return null;
    }
    return {
      player: clone(this.runtime.player),
      activeLayer: this.runtime.activeLayer,
      entities: clone(this.runtime.entities),
      moveCount: this.runtime.moveCount,
      solved: this.runtime.solved,
      actionLog: clone(this.runtime.actionLog),
      latchedSwitches: clone(this.runtime.latchedSwitches),
    };
  }

  getReplayActions(kind = "current") {
    if (!this.runtime) {
      return [];
    }
    if (kind === "current") {
      return clone(this.runtime.actionLog);
    }
    return [];
  }

  canUndo() {
    return !!this.runtime?.history.length;
  }

  canRedo() {
    return !!this.runtime?.future.length;
  }

  undo() {
    if (!this.canUndo()) {
      return false;
    }
    const previous = this.runtime.history.pop();
    this.runtime.future.push(this.getRoomSnapshot());
    this.restoreSnapshot(previous);
    return true;
  }

  redo() {
    if (!this.canRedo()) {
      return false;
    }
    const next = this.runtime.future.pop();
    this.runtime.history.push(this.getRoomSnapshot());
    this.restoreSnapshot(next);
    return true;
  }

  reset() {
    if (!this.room) {
      return false;
    }
    this.runtime = this.createRuntime(this.room, null);
    this.replayState = null;
    return true;
  }

  restoreSnapshot(snapshot) {
    this.runtime.player = clone(snapshot.player);
    this.runtime.activeLayer = snapshot.activeLayer;
    this.runtime.entities = clone(snapshot.entities);
    this.runtime.moveCount = snapshot.moveCount;
    this.runtime.solved = snapshot.solved;
    this.runtime.actionLog = clone(snapshot.actionLog || []);
    this.runtime.latchedSwitches = clone(snapshot.latchedSwitches || []);
    this.runtime.notifications = [];
    this.ensureCompanionState(this.runtime.entities);
    this.updateDynamicState(this.runtime);
  }

  startReplay(actions) {
    if (!actions?.length) {
      return false;
    }
    this.reset();
    this.replayState = {
      actions: clone(actions),
      index: 0,
      timerMs: 0,
    };
    return true;
  }

  update(dtMs) {
    if (!this.replayState) {
      return;
    }
    this.replayState.timerMs -= dtMs;
    const stepMs = 260;
    while (this.replayState && this.replayState.timerMs <= 0) {
      const nextAction = this.replayState.actions[this.replayState.index];
      if (!nextAction) {
        this.replayState = null;
        return;
      }
      this.dispatch(nextAction, { recordHistory: false, isReplay: true });
      this.replayState.index += 1;
      this.replayState.timerMs += stepMs;
    }
  }

  dispatch(rawAction, options = {}) {
    if (!this.runtime || !this.room) {
      return false;
    }

    const action = normalizeAction(rawAction);
    if (this.runtime.solved && !options.isReplay) {
      return false;
    }

    if (action.type === "undo") {
      return this.undo();
    }
    if (action.type === "redo") {
      return this.redo();
    }
    if (action.type === "reset") {
      return this.reset();
    }

    const snapshot = this.getRoomSnapshot();
    const changed = this.applyPlayerAction(action);
    if (!changed) {
      return false;
    }

    this.processCompanions(action);
    this.runtime.moveCount += 1;
    this.runtime.actionLog.push(action);
    this.updateDynamicState(this.runtime);
    this.runtime.solved = this.isSolved(this.runtime);

    if (options.recordHistory !== false) {
      this.runtime.history.push(snapshot);
      this.runtime.future = [];
    }

    return true;
  }

  applyPlayerAction(action) {
    if (isMoveAction(action)) {
      const direction = DIRECTIONS[action.direction];
      this.runtime.player.facing = direction.facing;
      return this.tryMoveActor(this.runtime.player, direction.dx, direction.dy, true);
    }

    if (action.type === "switch_layer") {
      return this.trySwitchLayer();
    }

    if (action.type === "transfer") {
      return this.tryTransfer();
    }

    if (action.type === "wait") {
      return true;
    }

    return false;
  }

  processCompanions(action) {
    for (const entity of this.runtime.entities) {
      if (entity.type === "shadow" && isMoveAction(action)) {
        const direction = DIRECTIONS[action.direction];
        const mirrored = this.getMirroredVector(direction, entity.mirrorAxis || "vertical");
        this.tryMoveActor(entity, mirrored.dx, mirrored.dy, false);
      }
    }

    for (const entity of this.runtime.entities) {
      if (entity.type !== "echo") {
        continue;
      }

      const queuedAction = entity.queuedAction;
      if (queuedAction?.type === "move") {
        const direction = DIRECTIONS[queuedAction.direction];
        this.tryMoveActor(entity, direction.dx, direction.dy, false);
      }

      if (isMoveAction(action)) {
        entity.queuedAction = clone(action);
      } else {
        entity.queuedAction = { type: "wait" };
      }
    }
  }

  getMirroredVector(direction, axis) {
    if (axis === "horizontal") {
      return { dx: direction.dx, dy: -direction.dy };
    }
    return { dx: -direction.dx, dy: direction.dy };
  }

  routingStampAppliesTo(stamp, channel) {
    if (!stamp) {
      return false;
    }
    const appliesTo = Array.isArray(stamp.appliesTo) ? stamp.appliesTo : [];
    return appliesTo.includes(channel);
  }

  findRoutingStamp(layer, x, y, channel) {
    return (
      (this.room.routingStamps || []).find(
        (stamp) =>
          stamp.layer === layer &&
          stamp.x === x &&
          stamp.y === y &&
          this.routingStampAppliesTo(stamp, channel)
      ) || null
    );
  }

  getRoutedDestination(layer, x, y, channel) {
    const stamp = this.findRoutingStamp(layer, x, y, channel);
    if (!stamp) {
      return { layer, x, y, stamp: null };
    }
    const direction = DIRECTIONS[stamp.direction];
    if (!direction) {
      return { layer, x, y, stamp: null };
    }
    const distance = clampDistance(stamp.distance);
    return {
      layer,
      x: x + direction.dx * distance,
      y: y + direction.dy * distance,
      stamp,
    };
  }

  trySwitchLayer() {
    const { player } = this.runtime;
    if (this.getTile(player.layer, player.x, player.y) !== "S") {
      return false;
    }

    const availableLayers = this.room.layers
      .map((_, index) => index)
      .filter((layerIndex) => layerIndex !== player.layer && this.getTile(layerIndex, player.x, player.y) === "S");

    for (const layerIndex of availableLayers) {
      const routed = this.getRoutedDestination(layerIndex, player.x, player.y, "switch");
      if (this.isPassable(routed.layer, routed.x, routed.y, { ignorePlayer: true })) {
        player.layer = layerIndex;
        player.x = routed.x;
        player.y = routed.y;
        this.runtime.activeLayer = routed.layer;
        return true;
      }
    }

    return false;
  }

  tryTransfer() {
    const direction = DIRECTIONS[this.runtime.player.facing] || DIRECTIONS.right;
    const sourceX = this.runtime.player.x + direction.dx;
    const sourceY = this.runtime.player.y + direction.dy;
    const entity = this.findEntityAt(this.runtime.player.layer, sourceX, sourceY, {
      solidOnly: true,
      pushableOnly: true,
    });

    if (!entity) {
      return false;
    }

    const layerCount = this.room.layers.length;
    for (let offset = 1; offset < layerCount; offset += 1) {
      const targetLayer = (entity.layer + offset) % layerCount;
      if (targetLayer === entity.layer) {
        continue;
      }
      const routed = this.getRoutedDestination(targetLayer, entity.x, entity.y, "transfer");
      if (this.isPassable(routed.layer, routed.x, routed.y, { ignoreEntityId: entity.id })) {
        entity.layer = routed.layer;
        entity.x = routed.x;
        entity.y = routed.y;
        return true;
      }
    }

    return false;
  }

  tryMoveActor(actor, dx, dy, canPush) {
    const targetX = actor.x + dx;
    const targetY = actor.y + dy;
    const blockingEntity = this.findEntityAt(actor.layer, targetX, targetY, {
      solidOnly: true,
      ignoreEntityId: actor.id,
    });

    if (blockingEntity) {
      if (!canPush || !blockingEntity.pushable) {
        return false;
      }
      const beyondX = targetX + dx;
      const beyondY = targetY + dy;
      if (!this.isPassable(actor.layer, beyondX, beyondY, { ignoreEntityId: blockingEntity.id })) {
        return false;
      }
      blockingEntity.x = beyondX;
      blockingEntity.y = beyondY;
    } else if (!this.isPassable(actor.layer, targetX, targetY, { ignoreEntityId: actor.id, ignorePlayer: actor !== this.runtime.player })) {
      return false;
    }

    actor.x = targetX;
    actor.y = targetY;
    if (actor === this.runtime.player) {
      this.runtime.activeLayer = actor.layer;
    }
    return true;
  }

  isPassable(layer, x, y, options = {}) {
    const tile = this.getTile(layer, x, y);
    if (!tile || tile === "#") {
      return false;
    }
    if (tile === "~" && !this.runtime.dynamicState.bridges.has(coordKey(layer, x, y))) {
      return false;
    }

    const door = this.findDoorAt(layer, x, y);
    if (door && !this.runtime.dynamicState.openDoors.has(door.id)) {
      return false;
    }

    const occupant = this.findEntityAt(layer, x, y, {
      solidOnly: true,
      ignoreEntityId: options.ignoreEntityId,
    });
    if (occupant) {
      return false;
    }

    if (!options.ignorePlayer) {
      const player = this.runtime.player;
      if (player.layer === layer && player.x === x && player.y === y) {
        return false;
      }
    }

    return true;
  }

  updateDynamicState(runtime) {
    const bridges = new Set();
    for (const entity of runtime.entities) {
      if (!entity.projectionTargets) {
        continue;
      }
      for (const projection of entity.projectionTargets) {
        const routed = this.getRoutedDestination(
          projection.layer,
          entity.x + projection.dx,
          entity.y + projection.dy,
          "projection"
        );
        if (this.getTile(routed.layer, routed.x, routed.y)) {
          bridges.add(coordKey(routed.layer, routed.x, routed.y));
        }
      }
    }

    const activeSwitches = new Set(runtime.latchedSwitches || []);
    for (const switchDef of this.room.switches || []) {
      if (this.hasOccupant(runtime, switchDef.layer, switchDef.x, switchDef.y)) {
        activeSwitches.add(switchDef.id);
      }
    }

    const openDoors = new Set();
    for (const door of this.room.doors || []) {
      const allActive = (door.switchIds || []).every((switchId) => activeSwitches.has(switchId));
      if (allActive) {
        openDoors.add(door.id);
      }
    }

    runtime.latchedSwitches = (runtime.latchedSwitches || []).filter((switchId) =>
      (this.room.switches || []).some((switchDef) => switchDef.id === switchId && switchDef.sticky)
    );
    for (const switchDef of this.room.switches || []) {
      if (switchDef.sticky && activeSwitches.has(switchDef.id) && !runtime.latchedSwitches.includes(switchDef.id)) {
        runtime.latchedSwitches.push(switchDef.id);
      }
    }

    runtime.dynamicState = {
      activeSwitches,
      openDoors,
      bridges,
    };
  }

  hasOccupant(runtime, layer, x, y) {
    if (runtime.player.layer === layer && runtime.player.x === x && runtime.player.y === y) {
      return true;
    }
    return !!runtime.entities.find(
      (entity) => entity.layer === layer && entity.x === x && entity.y === y && entity.solid
    );
  }

  findEntityAt(layer, x, y, options = {}) {
    return (
      this.runtime.entities.find((entity) => {
        if (options.ignoreEntityId && entity.id === options.ignoreEntityId) {
          return false;
        }
        if (options.solidOnly && !entity.solid) {
          return false;
        }
        if (options.pushableOnly && !entity.pushable) {
          return false;
        }
        return entity.layer === layer && entity.x === x && entity.y === y;
      }) || null
    );
  }

  findDoorAt(layer, x, y) {
    return (this.room.doors || []).find((door) => door.layer === layer && door.x === x && door.y === y) || null;
  }

  getTile(layer, x, y) {
    const row = this.room.layers[layer]?.tiles[y];
    return row?.[x] || null;
  }

  isSolved(runtime) {
    const tile = this.getTile(runtime.player.layer, runtime.player.x, runtime.player.y);
    return tile === "G";
  }

  getTextState() {
    if (!this.runtime || !this.room) {
      return {
        mode: "boot",
      };
    }

    return {
      mode: this.previewMode ? "preview" : "room",
      roomId: this.room.id,
      roomTitle: this.room.title,
      coordinates: "origin top-left, x increases right, y increases down",
      activeLayer: this.runtime.activeLayer,
      layerNames: this.room.layers.map((layer) => layer.name),
      player: {
        layer: this.runtime.player.layer,
        x: this.runtime.player.x,
        y: this.runtime.player.y,
        facing: this.runtime.player.facing,
      },
      entities: this.runtime.entities.map((entity) => ({
        id: entity.id,
        type: entity.type,
        layer: entity.layer,
        x: entity.x,
        y: entity.y,
      })),
      switches: (this.room.switches || []).map((switchDef) => ({
        id: switchDef.id,
        layer: switchDef.layer,
        x: switchDef.x,
        y: switchDef.y,
        active: this.runtime.dynamicState.activeSwitches.has(switchDef.id),
      })),
      doors: (this.room.doors || []).map((door) => ({
        id: door.id,
        layer: door.layer,
        x: door.x,
        y: door.y,
        open: this.runtime.dynamicState.openDoors.has(door.id),
      })),
      routingStamps: (this.room.routingStamps || []).map((stamp) => ({
        id: stamp.id,
        layer: stamp.layer,
        x: stamp.x,
        y: stamp.y,
        direction: stamp.direction,
        appliesTo: [...(stamp.appliesTo || [])],
      })),
      moveCount: this.runtime.moveCount,
      solved: this.runtime.solved,
      availableActions: [
        "move",
        "wait",
        "switch_layer",
        "transfer",
        "undo",
        "redo",
        "reset",
      ],
    };
  }
}
