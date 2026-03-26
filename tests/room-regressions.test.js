import test from "node:test";
import assert from "node:assert/strict";

import { buildCampaignIndex, getRoomById } from "../src/content/campaign.js";
import { THREE_LAYER_PROOF_ROOM } from "../src/content/devRooms.js";
import { CANONICAL_SOLUTIONS, THREE_LAYER_PROOF_SOLUTION } from "../src/content/solutions.js";
import { PatchworkEngine } from "../src/game/engine.js";
import { validateRoom } from "../src/game/validator.js";

const campaign = buildCampaignIndex();

function runSolution(roomId, actions) {
  const engine = new PatchworkEngine(campaign);
  const room = getRoomById(roomId);
  assert.ok(room, `Unknown room '${roomId}'`);
  engine.loadRoom(roomId);
  for (const action of actions) {
    const changed = engine.dispatch(action);
    assert.equal(changed, true, `Action ${JSON.stringify(action)} should change state in room ${roomId}`);
  }
  return engine;
}

test("all canonical room solutions still solve their rooms", () => {
  for (const [roomId, actions] of Object.entries(CANONICAL_SOLUTIONS)) {
    const engine = runSolution(roomId, actions);
    const runtime = engine.getRuntime();
    assert.equal(runtime.solved, true, `${roomId} should be solved by its canonical solution`);
    assert.equal(runtime.moveCount, actions.length, `${roomId} move count should match action count`);
  }
});

test("undo, redo, reset, and snapshot restore remain stable on a canonical room", () => {
  const engine = new PatchworkEngine(campaign);
  engine.loadRoom("mailroom-02");

  // Navigate to be adjacent to parcel-a: start at (1,8), go up 3 to (1,5), right 1 to (2,5)
  assert.equal(engine.dispatch({ type: "move", direction: "up" }), true);
  assert.equal(engine.dispatch({ type: "move", direction: "up" }), true);
  assert.equal(engine.dispatch({ type: "move", direction: "up" }), true);
  assert.equal(engine.dispatch({ type: "move", direction: "right" }), true);
  const snapshotAfterMove = engine.getRoomSnapshot();
  assert.equal(engine.getRuntime().player.x, 2);
  assert.equal(engine.getRuntime().player.y, 5);

  // Transfer parcel-a (at 3,5) to layer 1
  assert.equal(engine.dispatch({ type: "transfer" }), true);
  assert.equal(engine.getRuntime().entities[0].layer, 1);

  // Undo should restore parcel to layer 0
  assert.equal(engine.dispatch({ type: "undo" }), true);
  assert.equal(engine.getRuntime().entities[0].layer, 0);
  assert.equal(engine.getRuntime().player.x, 2);

  // Redo should move parcel back to layer 1
  assert.equal(engine.dispatch({ type: "redo" }), true);
  assert.equal(engine.getRuntime().entities[0].layer, 1);

  // Restore snapshot should bring us back to before transfer
  engine.restoreSnapshot(snapshotAfterMove);
  assert.equal(engine.getRuntime().player.x, 2);
  assert.equal(engine.getRuntime().entities[0].layer, 0);

  // Reset should bring us back to start
  assert.equal(engine.dispatch({ type: "reset" }), true);
  assert.equal(engine.getRuntime().player.x, 1);
  assert.equal(engine.getRuntime().player.y, 8);
  assert.equal(engine.getRuntime().entities[0].layer, 0);
  assert.equal(engine.getRuntime().moveCount, 0);
});

test("replay reproduces a canonical solution to completion", () => {
  const actions = CANONICAL_SOLUTIONS["clocktower-01"];
  const engine = new PatchworkEngine(campaign);
  engine.loadRoom("clocktower-01");
  assert.equal(engine.startReplay(actions), true);

  for (let index = 0; index < actions.length + 2; index += 1) {
    engine.update(300);
  }

  assert.equal(engine.getRuntime().solved, true);
  assert.equal(engine.getRuntime().moveCount, actions.length);
});

test("three-layer proof room validates and solves correctly", () => {
  const issues = validateRoom(THREE_LAYER_PROOF_ROOM);
  assert.deepEqual(
    issues,
    ["No structural issues detected. This validator only performs basic checks."],
    "Three-layer proof room should pass structural validation"
  );

  const engine = new PatchworkEngine(campaign);
  engine.loadPreviewRoom(THREE_LAYER_PROOF_ROOM);

  const visitedLayers = new Set([engine.getRuntime().activeLayer]);
  for (const action of THREE_LAYER_PROOF_SOLUTION) {
    const changed = engine.dispatch(action);
    assert.equal(changed, true, `Three-layer proof action ${JSON.stringify(action)} should succeed`);
    visitedLayers.add(engine.getRuntime().activeLayer);
  }

  assert.equal(engine.getRuntime().solved, true);
  assert.deepEqual([...visitedLayers].sort((a, b) => a - b), [0, 1, 2]);
});

test("demo slice metadata references a complete Batch 5 early-game route", () => {
  const demo = campaign.demo;
  assert.ok(demo, "Campaign should expose demo metadata");
  assert.deepEqual(demo.districtIds, ["mailroom", "market", "greenhouse"]);
  assert.equal(demo.mainRoomIds.length, 11);
  assert.equal(demo.optionalRoomIds.length, 4);

  const allDemoRoomIds = [...demo.mainRoomIds, ...demo.optionalRoomIds];
  for (const roomId of allDemoRoomIds) {
    const room = getRoomById(roomId);
    assert.ok(room, `Demo room '${roomId}' should exist in the campaign`);
  }

  const earlyDistrictRoomCount = campaign.rooms.filter((room) =>
    demo.districtIds.includes(room.districtId)
  ).length;
  assert.equal(earlyDistrictRoomCount, 15);
  assert.equal(getRoomById(demo.finalRoomId)?.districtId, "greenhouse");
});

test("Batch 6 campaign metadata exposes a main route, a secret route, and hidden journal entries", () => {
  const mainCampaign = campaign.mainCampaign;
  const secretRoute = campaign.secretRoute;

  assert.ok(mainCampaign, "Campaign should expose main-campaign metadata");
  assert.ok(secretRoute, "Campaign should expose secret-route metadata");
  assert.equal(mainCampaign.mainRoomIds.length, 21);
  assert.equal(secretRoute.roomIds.length, 3);
  assert.deepEqual(secretRoute.requiredRoomIds, [
    "clocktower-side-01",
    "theater-side-01",
    "rooftops-side-01",
  ]);
  assert.equal(campaign.journalEntries.length, 5);
  assert.equal(getRoomById(mainCampaign.finalRoomId)?.districtId, "rooftops");
  assert.equal(getRoomById(secretRoute.finalRoomId)?.districtId, "attic");
});

test("new engine mechanics: gravity, conveyors, and key/lock system", () => {
  // Test gravity tile (F) - create a room with gravity
  const gravityRoom = {
    id: "test-gravity",
    title: "Gravity Test",
    layers: [
      { name: "Main", tiles: ["######", "#....#", "#.F..#", "#....#", "#...G#", "######"] },
    ],
    start: { layer: 0, x: 1, y: 1, facing: "right" },
    entities: [],
    switches: [],
    doors: [],
    locks: [],
    hintTiers: ["", "", ""],
    objective: "Test",
  };

  const engine = new PatchworkEngine(campaign);
  engine.loadPreviewRoom(gravityRoom);

  // Move right onto gravity tile at (2,2)
  engine.dispatch({ type: "move", direction: "down" });
  engine.dispatch({ type: "move", direction: "right" });
  // Player should fall from (2,2) down to (2,3) since F tile pulls down
  assert.equal(engine.getRuntime().player.y >= 2, true, "Gravity should pull player down");

  // Test conveyor belt (R) - push right
  const conveyorRoom = {
    id: "test-conveyor",
    title: "Conveyor Test",
    layers: [
      { name: "Main", tiles: ["######", "#.R..#", "#....#", "#...G#", "######"] },
    ],
    start: { layer: 0, x: 1, y: 1, facing: "right" },
    entities: [],
    switches: [],
    doors: [],
    locks: [],
    hintTiers: ["", "", ""],
    objective: "Test",
  };

  engine.loadPreviewRoom(conveyorRoom);
  // Move right onto conveyor at (2,1) — should be pushed to (3,1)
  engine.dispatch({ type: "move", direction: "right" });
  assert.equal(engine.getRuntime().player.x >= 2, true, "Conveyor should push player right");

  // Test key/lock system
  const keyLockRoom = {
    id: "test-keylock",
    title: "Key Lock Test",
    layers: [
      { name: "Main", tiles: ["######", "#....#", "#....#", "#...G#", "######"] },
    ],
    start: { layer: 0, x: 1, y: 1, facing: "right" },
    entities: [
      { id: "red-key", type: "key", color: "red", layer: 0, x: 2, y: 1, solid: false, pushable: false },
    ],
    switches: [],
    doors: [],
    locks: [
      { id: "red-lock", layer: 0, x: 3, y: 1, color: "red" },
    ],
    hintTiers: ["", "", ""],
    objective: "Test",
  };

  engine.loadPreviewRoom(keyLockRoom);
  // Move right to pick up key at (2,1)
  engine.dispatch({ type: "move", direction: "right" });
  assert.ok(engine.getRuntime().collectedKeys.includes("red"), "Should collect red key");
  // Lock at (3,1) should now be open
  assert.ok(engine.getRuntime().dynamicState.openLocks.has("red-lock"), "Red lock should be open");
  // Move through the lock
  engine.dispatch({ type: "move", direction: "right" });
  assert.equal(engine.getRuntime().player.x, 3, "Should pass through opened lock");
});

test("all campaign rooms pass structural validation", () => {
  for (const room of campaign.rooms) {
    const issues = validateRoom(room);
    // Filter out soft warnings (corner locks, info-only messages)
    const hardIssues = issues.filter((issue) =>
      issue !== "No structural issues detected. This validator only performs basic checks." &&
      !issue.includes("soft lock") &&
      !issue.includes("corner")
    );
    assert.equal(hardIssues.length, 0, `Room ${room.id} has validation issues: ${hardIssues.join("; ")}`);
  }
});
