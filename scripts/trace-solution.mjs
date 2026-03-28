#!/usr/bin/env node
// Trace a solution for a room by executing a sequence of actions.
// Usage: node scripts/trace-solution.mjs <room-id> <action-string>
// Action string: R=right, L=left, U=up, D=down, S=switch_layer, T=transfer, W=wait
// Example: node scripts/trace-solution.mjs mailroom-03 "RRRRUUSLDDLS..."

import { readFileSync } from "fs";
import { PatchworkEngine } from "../src/game/engine.js";
import { buildCampaignIndex } from "../src/data/campaign.js";

const campaign = buildCampaignIndex();
const roomId = process.argv[2];
const actionStr = process.argv[3] || "";

if (!roomId) {
  console.log("Usage: node scripts/trace-solution.mjs <room-id> <action-string>");
  process.exit(1);
}

const ACTION_MAP = {
  R: { type: "move", direction: "right" },
  L: { type: "move", direction: "left" },
  U: { type: "move", direction: "up" },
  D: { type: "move", direction: "down" },
  S: { type: "switch_layer" },
  T: { type: "transfer" },
  W: { type: "wait" },
};

const engine = new PatchworkEngine(campaign);
engine.loadRoom(roomId);
const runtime = engine.getRuntime();
const room = engine.getRoom();

console.log(`Room: ${room.title} (${roomId})`);
console.log(`Start: layer=${runtime.player.layer} x=${runtime.player.x} y=${runtime.player.y} facing=${runtime.player.facing}`);
console.log(`Layers: ${room.layers.length}`);
console.log(`Entities: ${runtime.entities.map(e => `${e.id}@(${e.x},${e.y})L${e.layer}`).join(", ")}`);
console.log();

// Print all layer tiles for reference
for (let li = 0; li < room.layers.length; li++) {
  console.log(`Layer ${li} (${room.layers[li].name}):`);
  room.layers[li].tiles.forEach((row, y) => console.log(`  ${y}: ${row}`));
  console.log();
}

if (!actionStr) {
  // Interactive mode: just show the room info
  console.log("No actions provided. Pass an action string as second argument.");
  console.log("Action codes: R=right, L=left, U=up, D=down, S=switch, T=transfer, W=wait");
  process.exit(0);
}

const actions = actionStr.split("").map(c => ACTION_MAP[c]).filter(Boolean);
const recorded = [];

for (let i = 0; i < actions.length; i++) {
  const action = actions[i];
  const before = engine.getRuntime();
  const changed = engine.dispatch(action);
  const after = engine.getRuntime();

  const label = action.direction || action.type;
  if (!changed) {
    console.log(`Step ${i + 1} (${actionStr[i]}=${label}): FAILED at (${before.player.x},${before.player.y}) L${before.activeLayer}`);
    continue;
  }

  recorded.push(action);
  const p = after.player;
  console.log(`Step ${i + 1} (${actionStr[i]}=${label}): -> (${p.x},${p.y}) L${after.activeLayer} facing=${p.facing} moves=${after.moveCount}${after.solved ? " SOLVED!" : ""}`);

  if (after.solved) {
    console.log(`\nSolved in ${recorded.length} moves!`);
    console.log("\nJSON solution:");
    console.log(JSON.stringify(recorded, null, 2));
    process.exit(0);
  }
}

console.log(`\nNot solved yet. Player at (${engine.getRuntime().player.x},${engine.getRuntime().player.y}) L${engine.getRuntime().activeLayer}`);
console.log(`Entities: ${engine.getRuntime().entities.map(e => `${e.id}@(${e.x},${e.y})L${e.layer}`).join(", ")}`);
console.log(`Moves so far: ${recorded.length}`);
