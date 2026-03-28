#!/usr/bin/env node
// Optimized BFS solver: excludes wait, uses compact state keys.
// Usage: node scripts/auto-solve.mjs [room-id] [max-depth]

import { readFileSync, writeFileSync } from "fs";
import { PatchworkEngine } from "../src/game/engine.js";
import { buildCampaignIndex } from "../src/data/campaign.js";

const campaign = buildCampaignIndex();
const solutionsPath = "data/source/solutions.json";
const solutions = JSON.parse(readFileSync(solutionsPath, "utf-8"));
const canonical = solutions.canonicalSolutions;

const targetRoom = process.argv[2];
const maxDepth = parseInt(process.argv[3]) || 80;

const ALL_ROOMS = [
  "mailroom-03",
  "market-01",
  "market-02",
  "market-03",
  "greenhouse-01",
  "greenhouse-02",
  "greenhouse-03",
  "greenhouse-04",
  "clocktower-02",
  "clocktower-03",
  "theater-01",
  "theater-02",
  "theater-03",
  "rooftops-01",
  "rooftops-02",
  "rooftops-03",
  "rooftops-04",
  "clocktower-side-01",
  "theater-side-01",
  "rooftops-side-01",
  "attic-01",
  "attic-02",
  "attic-03",
];

const rooms = targetRoom ? [targetRoom] : ALL_ROOMS.filter(r => !canonical[r]);

const ACTIONS = [
  { type: "move", direction: "up" },
  { type: "move", direction: "down" },
  { type: "move", direction: "left" },
  { type: "move", direction: "right" },
  { type: "switch_layer" },
  { type: "transfer" },
  { type: "wait" },
];

function stateKey(rt) {
  const p = rt.player;
  const ents = rt.entities.map(e => `${e.layer}:${e.x}:${e.y}`).join("|");
  const latched = (rt.latchedSwitches || []).join(",");
  const keys = (rt.collectedKeys || []).join(",");
  // Facing matters for transfer, so include it
  return `${p.layer}:${p.x}:${p.y}:${p.facing}:${rt.activeLayer}|${ents}|${latched}|${keys}`;
}

function solve(roomId) {
  console.log(`\nSolving ${roomId} (maxDepth=${maxDepth})...`);
  const engine = new PatchworkEngine(campaign);
  engine.loadRoom(roomId);

  if (engine.getRuntime().solved) {
    return [];
  }

  const initial = engine.getRoomSnapshot();
  const visited = new Set([stateKey(engine.getRuntime())]);
  const queue = [{ snap: initial, acts: [] }];
  let checked = 0;
  const startTime = Date.now();

  while (queue.length > 0) {
    const { snap, acts } = queue.shift();
    if (acts.length >= maxDepth) continue;

    for (const action of ACTIONS) {
      engine.loadRoom(roomId);
      engine.restoreSnapshot(snap);

      if (!engine.dispatch(action)) continue;

      const rt = engine.getRuntime();
      if (rt.solved) {
        const sol = [...acts, action];
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`  SOLVED in ${sol.length} moves (${checked} states, ${elapsed}s)`);
        return sol;
      }

      const key = stateKey(rt);
      if (visited.has(key)) continue;
      visited.add(key);
      queue.push({ snap: engine.getRoomSnapshot(), acts: [...acts, action] });

      checked++;
      if (checked % 100000 === 0) {
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`  ${checked} states, queue=${queue.length}, depth=${acts.length + 1}, ${elapsed}s`);
      }
    }
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`  NO SOLUTION in ${maxDepth} moves (${checked} states, ${elapsed}s)`);
  return null;
}

let updated = false;
for (const roomId of rooms) {
  if (canonical[roomId]) {
    console.log(`${roomId}: already has solution (${canonical[roomId].length} steps), skipping.`);
    continue;
  }
  const solution = solve(roomId);
  if (solution) {
    canonical[roomId] = solution;
    updated = true;
    // Save incrementally so we don't lose progress
    writeFileSync(solutionsPath, JSON.stringify(solutions, null, 2) + "\n");
    console.log(`  Saved to solutions.json`);
  }
}

if (updated) {
  console.log("\nDone. Run `node scripts/sync-content.mjs` to sync.");
} else {
  console.log("\nNo updates needed.");
}
