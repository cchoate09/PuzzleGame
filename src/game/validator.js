function key(layer, x, y) {
  return `${layer}:${x}:${y}`;
}

function parseTiles(layer) {
  return layer.tiles.map((row) => row.split(""));
}

export function validateRoom(room) {
  const issues = [];
  if (!room || typeof room !== "object") {
    return ["No room data loaded."];
  }

  if (!Array.isArray(room.layers) || room.layers.length < 2 || room.layers.length > 4) {
    issues.push("Room should define two to four layers.");
    return issues;
  }

  const width = room.layers[0].tiles[0].length;
  const height = room.layers[0].tiles.length;

  room.layers.forEach((layer, index) => {
    if (layer.tiles.length !== height) {
      issues.push(`Layer ${index} has a different height than the first layer.`);
    }
    layer.tiles.forEach((row, rowIndex) => {
      if (row.length !== width) {
        issues.push(`Layer ${index} row ${rowIndex} has an inconsistent width.`);
      }
      for (const character of row) {
        if (!["#", ".", "S", "G", "~", "I", "T", ">", "<", "^", "v", "F", "R", "L", "U", "D"].includes(character)) {
          issues.push(`Layer ${index} contains an unsupported tile '${character}'.`);
        }
      }
    });
  });

  if (!room.start) {
    issues.push("Room is missing a player start.");
  } else if (
    room.start.layer < 0 ||
    room.start.layer >= room.layers.length ||
    room.start.x < 0 ||
    room.start.x >= width ||
    room.start.y < 0 ||
    room.start.y >= height
  ) {
    issues.push("Player start is outside the room bounds.");
  }

  const goalCount = room.layers.reduce(
    (count, layer) => count + layer.tiles.join("").split("").filter((tile) => tile === "G").length,
    0
  );
  if (goalCount === 0) {
    issues.push("Room should have at least one mailbox goal tile.");
  }

  const stitchKeys = new Map();
  room.layers.forEach((layer, layerIndex) => {
    const tiles = parseTiles(layer);
    tiles.forEach((row, y) => {
      row.forEach((tile, x) => {
        if (tile === "S") {
          const tileKey = `${x}:${y}`;
          stitchKeys.set(tileKey, (stitchKeys.get(tileKey) || 0) + 1);
        }
      });
    });
  });
  for (const [tileKey, count] of stitchKeys.entries()) {
    if (count < 2) {
      issues.push(`Stitch at ${tileKey} does not line up with another layer.`);
    }
  }

  const switchIds = new Set();
  for (const switchDef of room.switches || []) {
    const switchKey = key(switchDef.layer, switchDef.x, switchDef.y);
    if (switchIds.has(switchDef.id)) {
      issues.push(`Duplicate switch id '${switchDef.id}'.`);
    }
    switchIds.add(switchDef.id);
    if (switchDef.x < 0 || switchDef.x >= width || switchDef.y < 0 || switchDef.y >= height) {
      issues.push(`Switch '${switchDef.id}' is outside the room bounds.`);
    }
    if (room.layers[switchDef.layer]?.tiles[switchDef.y]?.[switchDef.x] === "#") {
      issues.push(`Switch '${switchDef.id}' is placed on a wall.`);
    }
    if (switchKey.endsWith("undefined")) {
      issues.push(`Switch '${switchDef.id}' uses an invalid layer index.`);
    }
  }

  for (const doorDef of room.doors || []) {
    if ((doorDef.switchIds || []).length === 0) {
      issues.push(`Door '${doorDef.id}' is not linked to a switch.`);
    }
    for (const switchId of doorDef.switchIds || []) {
      if (!switchIds.has(switchId)) {
        issues.push(`Door '${doorDef.id}' references missing switch '${switchId}'.`);
      }
    }
  }

  for (const entity of room.entities || []) {
    if (entity.x < 0 || entity.x >= width || entity.y < 0 || entity.y >= height) {
      issues.push(`Entity '${entity.id}' is outside the room bounds.`);
    }
    if (!room.layers[entity.layer]) {
      issues.push(`Entity '${entity.id}' uses invalid layer index '${entity.layer}'.`);
    }
    if (room.layers[entity.layer]?.tiles[entity.y]?.[entity.x] === "#") {
      issues.push(`Entity '${entity.id}' starts inside a wall.`);
    }
    if (entity.projectionTargets) {
      for (const target of entity.projectionTargets) {
        const tx = entity.x + target.dx;
        const ty = entity.y + target.dy;
        if (!room.layers[target.layer]) {
          issues.push(`Entity '${entity.id}' projects to missing layer '${target.layer}'.`);
        } else if (tx < 0 || tx >= width || ty < 0 || ty >= height) {
          issues.push(`Entity '${entity.id}' projects outside the room bounds.`);
        }
      }
    }
  }

  const routingStampIds = new Set();
  const routingStampLocations = new Set();
  for (const stamp of room.routingStamps || []) {
    if (!stamp?.id) {
      issues.push("A routing stamp is missing its id.");
    } else if (routingStampIds.has(stamp.id)) {
      issues.push(`Duplicate routing stamp id '${stamp.id}'.`);
    }
    routingStampIds.add(stamp.id);

    if (!room.layers[stamp.layer]) {
      issues.push(`Routing stamp '${stamp.id}' uses invalid layer index '${stamp.layer}'.`);
      continue;
    }
    if (stamp.x < 0 || stamp.x >= width || stamp.y < 0 || stamp.y >= height) {
      issues.push(`Routing stamp '${stamp.id}' is outside the room bounds.`);
      continue;
    }
    if (room.layers[stamp.layer]?.tiles[stamp.y]?.[stamp.x] === "#") {
      issues.push(`Routing stamp '${stamp.id}' is placed on a wall.`);
    }

    if (!["up", "down", "left", "right"].includes(stamp.direction)) {
      issues.push(`Routing stamp '${stamp.id}' uses invalid direction '${stamp.direction}'.`);
    }

    if (!Number.isInteger(stamp.distance) || stamp.distance < 1) {
      issues.push(`Routing stamp '${stamp.id}' should use an integer distance of at least 1.`);
    }

    if (!Array.isArray(stamp.appliesTo) || stamp.appliesTo.length === 0) {
      issues.push(`Routing stamp '${stamp.id}' should declare at least one routing channel.`);
    } else {
      for (const channel of stamp.appliesTo) {
        if (!["switch", "transfer", "projection"].includes(channel)) {
          issues.push(`Routing stamp '${stamp.id}' uses unsupported channel '${channel}'.`);
        }
      }
    }

    const locationKey = key(stamp.layer, stamp.x, stamp.y);
    if (routingStampLocations.has(locationKey)) {
      issues.push(`Multiple routing stamps share ${locationKey}; only one stamp should occupy a tile.`);
    }
    routingStampLocations.add(locationKey);
  }

  if (!Array.isArray(room.hintTiers) || room.hintTiers.length < 3) {
    issues.push("Room should provide three hint tiers.");
  }

  if ((room.entities || []).every((entity) => !entity.pushable) && room.objective?.toLowerCase().includes("transfer")) {
    issues.push("Objective mentions transfer, but no pushable entities are present.");
  }

  if (room.entities?.some((entity) => entity.pushable)) {
    for (const entity of room.entities) {
      if (!entity.pushable) {
        continue;
      }
      const tiles = room.layers[entity.layer]?.tiles;
      const up = tiles?.[entity.y - 1]?.[entity.x] === "#";
      const down = tiles?.[entity.y + 1]?.[entity.x] === "#";
      const left = tiles?.[entity.y]?.[entity.x - 1] === "#";
      const right = tiles?.[entity.y]?.[entity.x + 1] === "#";
      if ((up || down) && (left || right)) {
        issues.push(`Pushable '${entity.id}' starts in a corner. This may create an accidental soft lock.`);
      }
    }
  }

  if (!issues.length) {
    issues.push("No structural issues detected. This validator only performs basic checks.");
  }

  return issues;
}
