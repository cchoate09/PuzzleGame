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

  assert.equal(engine.dispatch({ type: "move", direction: "right" }), true);
  const snapshotAfterMove = engine.getRoomSnapshot();
  assert.equal(engine.getRuntime().player.x, 2);

  assert.equal(engine.dispatch({ type: "transfer" }), true);
  assert.equal(engine.getRuntime().entities[0].layer, 1);

  assert.equal(engine.dispatch({ type: "undo" }), true);
  assert.equal(engine.getRuntime().entities[0].layer, 0);
  assert.equal(engine.getRuntime().player.x, 2);

  assert.equal(engine.dispatch({ type: "redo" }), true);
  assert.equal(engine.getRuntime().entities[0].layer, 1);

  engine.restoreSnapshot(snapshotAfterMove);
  assert.equal(engine.getRuntime().player.x, 2);
  assert.equal(engine.getRuntime().entities[0].layer, 0);

  assert.equal(engine.dispatch({ type: "reset" }), true);
  assert.equal(engine.getRuntime().player.x, 1);
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

test("routing stamps redirect switch exits, transfer destinations, and projection bridges", () => {
  const switchEngine = new PatchworkEngine(campaign);
  switchEngine.loadRoom("clocktower-03");
  switchEngine.dispatch({ type: "move", direction: "right" });
  switchEngine.dispatch({ type: "move", direction: "right" });
  switchEngine.dispatch({ type: "switch_layer" });
  assert.equal(switchEngine.getRuntime().player.layer, 1);
  assert.equal(switchEngine.getRuntime().player.x, 5);
  assert.equal(switchEngine.getRuntime().player.y, 1);
  assert.equal(switchEngine.getRuntime().solved, true);

  const transferEngine = new PatchworkEngine(campaign);
  transferEngine.loadRoom("rooftops-03");
  assert.equal(transferEngine.dispatch({ type: "transfer" }), true);
  const routedParcel = transferEngine.getRuntime().entities.find((entity) => entity.id === "parcel-stamped");
  assert.deepEqual(
    { layer: routedParcel.layer, x: routedParcel.x, y: routedParcel.y },
    { layer: 1, x: 4, y: 4 }
  );
  assert.equal(transferEngine.getRuntime().dynamicState.activeSwitches.has("roof-transfer-plate"), true);

  const projectionEngine = new PatchworkEngine(campaign);
  projectionEngine.loadRoom("rooftops-02");
  assert.equal(projectionEngine.dispatch({ type: "move", direction: "left" }), true);
  assert.equal(projectionEngine.getRuntime().dynamicState.bridges.has("1:4:2"), true);
});
