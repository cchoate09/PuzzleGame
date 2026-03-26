import { buildCampaignIndex, getDistrictById, getRoomsForDistrict } from "./data/campaign.js";
import { PatchworkEngine } from "./game/engine.js";
import {
  completeRoom,
  DEFAULT_CONTROLS,
  getPostmarkCount,
  getRoomProgress,
  getSolvedCount,
  loadProfile,
  revealHint,
  saveProfile,
  setRoomSnapshot,
  unlockAchievement,
  unlockJournal,
} from "./game/save.js";
import { validateRoom } from "./game/validator.js";

const campaign = buildCampaignIndex();
const profile = loadProfile();
const engine = new PatchworkEngine(campaign);
const urlParams = new URLSearchParams(window.location.search);
const requestedRoomId = urlParams.get("room");
const initialRoomId = requestedRoomId && campaign.roomsById[requestedRoomId]
  ? requestedRoomId
  : profile.lastRoomId || "mailroom-01";
const autoStart = urlParams.get("autostart") === "1";

const state = {
  screen: "title",
  awaitingRemap: null,
  currentRoomId: initialRoomId,
  boardLayout: [],
  lastRenderTime: performance.now(),
  gamepadState: {},
  hintOpen: false,
  autoAdvanceTimer: 0,
  autoAdvanceTarget: null,
};

// ═══════════════════════════════════════
// Element references
// ═══════════════════════════════════════

const el = {
  body: document.body,
  canvas: document.getElementById("game-canvas"),
  // Title
  startBtn: document.getElementById("start-btn"),
  resumeBtn: document.getElementById("resume-btn"),
  // Map
  districtList: document.getElementById("district-list"),
  postmarkCount: document.getElementById("postmark-count"),
  roomCount: document.getElementById("room-count"),
  journalList: document.getElementById("journal-list"),
  achievementList: document.getElementById("achievement-list"),
  settingContrast: document.getElementById("setting-contrast"),
  settingMotion: document.getElementById("setting-motion"),
  settingFontScale: document.getElementById("setting-font-scale"),
  controlList: document.getElementById("control-list"),
  roomJson: document.getElementById("room-json"),
  validationOutput: document.getElementById("validation-output"),
  actionLog: document.getElementById("action-log"),
  refreshRoomJson: document.getElementById("refresh-room-json"),
  loadRoomJson: document.getElementById("load-room-json"),
  validateRoom: document.getElementById("validate-room"),
  replaySolution: document.getElementById("replay-solution"),
  replayCurrent: document.getElementById("replay-current"),
  authorHint1: document.getElementById("author-hint-1"),
  authorHint2: document.getElementById("author-hint-2"),
  authorHint3: document.getElementById("author-hint-3"),
  // Play HUD
  hudBack: document.getElementById("hud-back"),
  hudRoomName: document.getElementById("hud-room-name"),
  hudObjective: document.getElementById("hud-objective"),
  hudMoves: document.getElementById("hud-moves"),
  hudLayer: document.getElementById("hud-layer"),
  hudHint: document.getElementById("hud-hint"),
  hudUndo: document.getElementById("hud-undo"),
  hudRedo: document.getElementById("hud-redo"),
  hudReset: document.getElementById("hud-reset"),
  // Solve overlay
  solveOverlay: document.getElementById("solve-overlay"),
  solveStats: document.getElementById("solve-stats"),
  solveNext: document.getElementById("solve-next"),
  solveReplay: document.getElementById("solve-replay"),
  solveMap: document.getElementById("solve-map"),
  // Hint overlay
  hintOverlay: document.getElementById("hint-overlay"),
  hintContent: document.getElementById("hint-content"),
  hintClose: document.getElementById("hint-close"),
};

const ctx = el.canvas.getContext("2d");

// ═══════════════════════════════════════
// Screen management
// ═══════════════════════════════════════

function setScreen(screen) {
  state.screen = screen;
  el.body.setAttribute("data-screen", screen);
  if (screen === "map") {
    renderMapScreen();
  }
  if (screen === "play") {
    el.solveOverlay.classList.add("hidden");
    state.hintOpen = false;
    el.hintOverlay.classList.add("hidden");
    updateHUD();
  }
}

// ═══════════════════════════════════════
// Room helpers
// ═══════════════════════════════════════

function currentRoom() {
  return engine.getRoom();
}

function currentRuntime() {
  return engine.getRuntime();
}

function ensureRoomLoaded(roomId) {
  const snapshot = getRoomProgress(profile, roomId).lastSnapshot;
  engine.loadRoom(roomId, snapshot);
  state.currentRoomId = roomId;
  profile.lastRoomId = roomId;
  saveProfile(profile);
}

function roomSolved(roomId) {
  return !!profile.rooms[roomId]?.solved;
}

function isDistrictUnlocked(district) {
  return getPostmarkCount(profile, campaign) >= district.unlockPostmarks;
}

function isRoomUnlocked(room) {
  const district = getDistrictById(room.districtId);
  if (!district || !isDistrictUnlocked(district)) {
    return false;
  }
  const districtRooms = getRoomsForDistrict(room.districtId);
  const mandatoryRooms = districtRooms.filter((c) => !c.optional);
  if (room.optional) {
    return !mandatoryRooms.length || mandatoryRooms.some((c) => roomSolved(c.id));
  }
  const roomIndex = mandatoryRooms.findIndex((c) => c.id === room.id);
  if (roomIndex <= 0) return true;
  return mandatoryRooms.slice(0, roomIndex).every((c) => roomSolved(c.id));
}

function getRoomLockReason(room, district, districtUnlocked) {
  if (!districtUnlocked) {
    return `Locked: collect ${district.unlockPostmarks} postmarks to unlock ${district.title}.`;
  }
  const districtRooms = getRoomsForDistrict(room.districtId);
  const mandatoryRooms = districtRooms.filter((r) => !r.optional);
  if (room.optional) {
    if (mandatoryRooms.length && !mandatoryRooms.some((r) => roomSolved(r.id))) {
      return `Locked: solve any main room in ${district.title} first.`;
    }
    return "Locked.";
  }
  const roomIndex = mandatoryRooms.findIndex((r) => r.id === room.id);
  if (roomIndex > 0) {
    const prev = mandatoryRooms[roomIndex - 1];
    if (!roomSolved(prev.id)) {
      return `Locked: solve "${prev.title}" first.`;
    }
  }
  return "Locked.";
}

function findNextRoom() {
  // Find next unsolved, unlocked room — prefer mandatory rooms in order
  for (const district of campaign.districts) {
    if (!isDistrictUnlocked(district)) continue;
    const rooms = getRoomsForDistrict(district.id);
    const mandatory = rooms.filter((r) => !r.optional);
    for (const room of mandatory) {
      if (!roomSolved(room.id) && isRoomUnlocked(room)) {
        return room.id;
      }
    }
    // Then optional
    for (const room of rooms) {
      if (room.optional && !roomSolved(room.id) && isRoomUnlocked(room)) {
        return room.id;
      }
    }
  }
  return null;
}

// ═══════════════════════════════════════
// Persistence
// ═══════════════════════════════════════

function persistCurrentSnapshot() {
  const room = currentRoom();
  if (!room || engine.previewMode) return;
  setRoomSnapshot(profile, room.id, currentRuntime().solved ? null : engine.getRoomSnapshot());
  profile.lastRoomId = room.id;
  saveProfile(profile);
}

function onRoomSolved() {
  const room = currentRoom();
  const runtime = currentRuntime();
  if (!room || !runtime?.solved || engine.previewMode || roomSolved(room.id)) return;

  const roomProgress = getRoomProgress(profile, room.id);
  completeRoom(profile, room, runtime);
  unlockJournal(profile, room.districtId);
  if (room.achievementId) unlockAchievement(profile, room.achievementId);
  if ((roomProgress.hintsRevealed || 0) === 0) unlockAchievement(profile, "careful-hands");
  saveProfile(profile);
  showSolveOverlay();
}

function showSolveOverlay() {
  const room = currentRoom();
  const runtime = currentRuntime();
  const roomProgress = getRoomProgress(profile, room.id);
  const moves = runtime.moveCount;
  const best = roomProgress.bestMoves;
  const hints = roomProgress.hintsRevealed || 0;
  const isNewBest = best != null && moves <= best;
  let statsText = `${moves} moves`;
  if (best != null) statsText += `  ·  Best: ${best}${isNewBest ? " ★" : ""}`;
  statsText += `  ·  Hints: ${hints}`;
  el.solveStats.textContent = statsText;

  const nextId = findNextRoom();
  el.solveNext.style.display = nextId ? "" : "none";
  el.solveNext.dataset.nextRoom = nextId || "";
  el.solveOverlay.classList.remove("hidden");

  // Auto-advance to next room after 3 seconds
  if (nextId) {
    state.autoAdvanceTimer = 3000;
    state.autoAdvanceTarget = nextId;
  } else {
    state.autoAdvanceTimer = 0;
    state.autoAdvanceTarget = null;
  }
}

function advanceToNextRoom() {
  const nextId = state.autoAdvanceTarget;
  if (!nextId) return;
  state.autoAdvanceTimer = 0;
  state.autoAdvanceTarget = null;
  ensureRoomLoaded(nextId);
  syncEditorFromRoom();
  setScreen("play");
}

// ═══════════════════════════════════════
// Actions
// ═══════════════════════════════════════

function performAction(action) {
  const changed = engine.dispatch(action);
  if (!changed) return;
  persistCurrentSnapshot();
  onRoomSolved();
  updateHUD();
}

// ═══════════════════════════════════════
// Map Screen rendering
// ═══════════════════════════════════════

function renderMapScreen() {
  renderDistrictList();
  renderJournalAndAchievements();
  renderControls();
  renderMapStats();
  renderActionLog();
}

function renderDistrictList() {
  el.districtList.innerHTML = "";
  const postmarks = getPostmarkCount(profile, campaign);

  for (const district of campaign.districts) {
    const card = document.createElement("section");
    card.className = "district-card";
    const unlocked = isDistrictUnlocked(district);
    const rooms = getRoomsForDistrict(district.id);
    const solvedCount = rooms.filter((room) => roomSolved(room.id)).length;

    card.innerHTML = `
      <header>
        <div>
          <h3>${district.title}</h3>
          <p class="eyebrow">${district.subtitle}</p>
        </div>
        <span class="badge ${unlocked ? "mandatory" : "locked"}">${unlocked ? `${solvedCount}/${rooms.length}` : `${district.unlockPostmarks} postmarks`}</span>
      </header>
      <p>${district.summary}</p>
      <div class="room-button-list"></div>
    `;

    const roomList = card.querySelector(".room-button-list");
    for (const room of rooms) {
      const button = document.createElement("button");
      const unlockedRoom = unlocked && isRoomUnlocked(room);
      const solved = roomSolved(room.id);
      button.className = `room-button ${room.id === state.currentRoomId ? "active" : ""} ${solved ? "solved" : ""} ${unlockedRoom ? "" : "locked"}`;
      button.disabled = !unlockedRoom;
      button.dataset.roomId = room.id;
      const icon = solved ? "✓ " : "";
      button.innerHTML = `
        <span>${icon}${room.title}</span>
        <span class="badge ${room.optional ? "optional" : "mandatory"}">${room.optional ? "Side" : "Main"}</span>
      `;
      if (!unlockedRoom) {
        const lockReason = getRoomLockReason(room, district, unlocked);
        if (lockReason) button.title = lockReason;
      }
      roomList.append(button);
    }

    if (!unlocked) {
      const note = document.createElement("p");
      note.textContent = `Locked until you collect ${district.unlockPostmarks} postmarks. You have ${postmarks}.`;
      card.append(note);
    }

    el.districtList.append(card);
  }

  // Wire room clicks → switch to play
  el.districtList.querySelectorAll("[data-room-id]").forEach((button) => {
    button.addEventListener("click", () => {
      ensureRoomLoaded(button.dataset.roomId);
      syncEditorFromRoom();
      setScreen("play");
    });
  });
}

function renderJournalAndAchievements() {
  el.journalList.innerHTML = "";
  for (const districtId of profile.journalsUnlocked) {
    const district = getDistrictById(districtId);
    if (!district) continue;
    const entry = document.createElement("article");
    entry.className = "journal-entry";
    entry.innerHTML = `<h4>${district.journalTitle}</h4><p>${district.journalBody}</p>`;
    el.journalList.append(entry);
  }
  if (!profile.journalsUnlocked.length) {
    el.journalList.innerHTML = "<p>No journal pages unlocked yet.</p>";
  }

  el.achievementList.innerHTML = "";
  for (const achievement of campaign.achievements) {
    const unlocked = !!profile.achievements[achievement.id];
    const entry = document.createElement("article");
    entry.className = "achievement-entry";
    entry.innerHTML = `
      <h4>${achievement.title}</h4>
      <p>${achievement.description}</p>
      <span class="badge ${unlocked ? "mandatory" : "locked"}">${unlocked ? "Unlocked" : "Locked"}</span>
    `;
    el.achievementList.append(entry);
  }
}

function renderControls() {
  el.controlList.innerHTML = "";
  for (const [action, code] of Object.entries(profile.settings.controls)) {
    const row = document.createElement("div");
    row.className = "control-row";
    row.innerHTML = `
      <span>${action.replace("_", " ")}</span>
      <button data-remap="${action}" class="${state.awaitingRemap === action ? "remap-pending" : ""}">
        ${state.awaitingRemap === action ? "Press a key" : code}
      </button>
    `;
    el.controlList.append(row);
  }
  el.controlList.querySelectorAll("[data-remap]").forEach((button) => {
    button.addEventListener("click", () => {
      state.awaitingRemap = button.dataset.remap;
      renderControls();
    });
  });
}

function renderMapStats() {
  const postmarks = getPostmarkCount(profile, campaign);
  const solvedCount = getSolvedCount(profile);
  el.postmarkCount.textContent = String(postmarks);
  el.roomCount.textContent = `${solvedCount} / ${campaign.rooms.length}`;
  el.settingContrast.checked = !!profile.settings.highContrast;
  el.settingMotion.checked = !!profile.settings.reducedMotion;
  el.settingFontScale.value = String(profile.settings.fontScale || 1);
  document.documentElement.style.fontSize = `${(profile.settings.fontScale || 1) * 16}px`;
  document.body.classList.toggle("high-contrast", !!profile.settings.highContrast);
}

function syncEditorFromRoom() {
  const room = currentRoom();
  if (!room) return;
  el.roomJson.value = JSON.stringify(room, null, 2);
  el.authorHint1.value = room.hintTiers?.[0] || "";
  el.authorHint2.value = room.hintTiers?.[1] || "";
  el.authorHint3.value = room.hintTiers?.[2] || "";
  el.validationOutput.textContent = "";
}

function renderActionLog() {
  const actions = currentRuntime()?.actionLog || [];
  if (!actions.length) {
    el.actionLog.textContent = "No actions recorded yet.";
    return;
  }
  el.actionLog.textContent = actions
    .map((a, i) => `${i + 1}. ${a.type}${a.direction ? `:${a.direction}` : ""}`)
    .join("\n");
}

// ═══════════════════════════════════════
// Play HUD
// ═══════════════════════════════════════

function updateHUD() {
  const room = currentRoom();
  const runtime = currentRuntime();
  if (!room || !runtime) return;
  el.hudRoomName.textContent = room.title;
  el.hudObjective.textContent = runtime.solved ? "Route restored!" : room.objective;
  let moveText = `${runtime.moveCount} moves`;
  const keys = runtime.collectedKeys || [];
  if (keys.length > 0) {
    moveText += ` · Keys: ${keys.join(", ")}`;
  }
  el.hudMoves.textContent = moveText;
  el.hudLayer.textContent = room.layers[runtime.activeLayer]?.name || "?";
}

function updateHintOverlay() {
  const room = currentRoom();
  const roomProgress = room ? getRoomProgress(profile, room.id) : null;
  const hintsRevealed = roomProgress?.hintsRevealed || 0;
  el.hintContent.innerHTML = "";
  if (room) {
    for (let i = 0; i < hintsRevealed; i++) {
      const div = document.createElement("div");
      div.className = "hint-entry";
      div.innerHTML = `<strong>Hint ${i + 1}</strong><p>${room.hintTiers[i]}</p>`;
      el.hintContent.append(div);
    }
    if (hintsRevealed === 0) {
      el.hintContent.innerHTML = "<p style='color:var(--muted)'>No hints revealed yet.</p>";
    }
  }
}

// ═══════════════════════════════════════
// Canvas rendering
// ═══════════════════════════════════════

function tileColor(tile) {
  switch (tile) {
    case "#": return "#ad8c63";
    case "~": return "#d7c5a2";
    case "S": return "#f7efdd";
    case "G": return "#f7e0a1";
    case "I": return "#c8dff0";
    case "T": return "#d8c4f0";
    case "F": return "#f0d8d8";
    case "R": case "L": case "U": case "D": return "#d8e8d0";
    case ">": case "<": case "^": case "v": return "#f0e4c8";
    default: return "#fff8ed";
  }
}

const KEY_LOCK_COLORS = {
  red: { fill: "#e04040", light: "#ff8080" },
  blue: { fill: "#4060e0", light: "#80a0ff" },
  green: { fill: "#40a040", light: "#80d080" },
  yellow: { fill: "#c0a020", light: "#e0d060" },
};

function drawRoundedRect(x, y, width, height, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + width, y, x + width, y + height, radius);
  ctx.arcTo(x + width, y + height, x, y + height, radius);
  ctx.arcTo(x, y + height, x, y, radius);
  ctx.arcTo(x, y, x + width, y, radius);
  ctx.closePath();
}

function drawLayerBoard(layerIndex, boardX, boardY, tileSize) {
  const room = currentRoom();
  const runtime = currentRuntime();
  const layer = room.layers[layerIndex];
  const width = layer.tiles[0].length;
  const height = layer.tiles.length;
  const boardWidth = width * tileSize;
  const boardHeight = height * tileSize;
  const active = runtime.activeLayer === layerIndex;

  // Card background
  ctx.save();
  ctx.shadowColor = "rgba(74, 43, 17, 0.18)";
  ctx.shadowBlur = active ? 18 : 8;
  ctx.shadowOffsetY = active ? 12 : 8;
  ctx.fillStyle = active ? "#fffdf8" : "#f5ebd5";
  const cardX = boardX - 18;
  const cardY = boardY - 48;
  const cardW = boardWidth + 36;
  const cardH = boardHeight + 58;
  drawRoundedRect(cardX, cardY, cardW, cardH, 28);
  ctx.fill();
  ctx.restore();

  if (active) {
    ctx.save();
    ctx.strokeStyle = "#d39b34";
    ctx.lineWidth = 3;
    drawRoundedRect(cardX + 1, cardY + 1, cardW - 2, cardH - 2, 27);
    ctx.stroke();
    ctx.restore();
  }

  // Layer name
  ctx.fillStyle = active ? "#5d301f" : "#7d6853";
  ctx.font = active ? "700 20px Georgia" : "600 16px Georgia";
  ctx.fillText(layer.name, boardX - 2, boardY - 16);

  // Tiles
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const tile = layer.tiles[y][x];
      const sx = boardX + x * tileSize;
      const sy = boardY + y * tileSize;

      ctx.fillStyle = tileColor(tile);
      ctx.fillRect(sx, sy, tileSize - 2, tileSize - 2);

      if (tile === "#") {
        ctx.fillStyle = "#8d6a45";
        ctx.fillRect(sx + 5, sy + 5, tileSize - 12, tileSize - 12);
      }
      if (tile === "S") {
        ctx.fillStyle = "rgba(247, 224, 161, 0.35)";
        ctx.fillRect(sx + 7, sy + 7, tileSize - 16, tileSize - 16);
        ctx.strokeStyle = "#7d3f29";
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 3]);
        ctx.strokeRect(sx + 7, sy + 7, tileSize - 16, tileSize - 16);
        ctx.setLineDash([]);
        ctx.lineWidth = 1;
        ctx.fillStyle = "#7d3f29";
        const cx = sx + tileSize / 2, cy = sy + tileSize / 2, d = 4;
        ctx.beginPath();
        ctx.moveTo(cx, cy - d);
        ctx.lineTo(cx + d, cy);
        ctx.lineTo(cx, cy + d);
        ctx.lineTo(cx - d, cy);
        ctx.closePath();
        ctx.fill();
      }
      if (tile === "~" && !runtime.dynamicState.bridges.has(`${layerIndex}:${x}:${y}`)) {
        ctx.strokeStyle = "#a98964";
        ctx.beginPath();
        ctx.moveTo(sx + 8, sy + 8);
        ctx.lineTo(sx + tileSize - 10, sy + tileSize - 10);
        ctx.moveTo(sx + tileSize - 10, sy + 8);
        ctx.lineTo(sx + 8, sy + tileSize - 10);
        ctx.stroke();
      }
      if (tile === "G") {
        ctx.fillStyle = "#d39b34";
        ctx.fillRect(sx + tileSize * 0.25, sy + tileSize * 0.3, tileSize * 0.5, tileSize * 0.45);
        ctx.fillStyle = "#7d3f29";
        ctx.fillRect(sx + tileSize * 0.35, sy + tileSize * 0.15, tileSize * 0.3, tileSize * 0.2);
      }
      // Ice tile
      if (tile === "I") {
        ctx.strokeStyle = "rgba(100, 160, 210, 0.45)";
        ctx.lineWidth = 1;
        for (let i = 0; i < 3; i++) {
          const lx = sx + 6 + i * (tileSize - 12) / 2;
          ctx.beginPath();
          ctx.moveTo(lx, sy + 6);
          ctx.lineTo(lx, sy + tileSize - 8);
          ctx.stroke();
        }
      }
      // Teleporter
      if (tile === "T") {
        ctx.fillStyle = "rgba(150, 120, 200, 0.35)";
        ctx.beginPath();
        ctx.arc(sx + tileSize / 2, sy + tileSize / 2, tileSize * 0.3, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = "#7d5faa";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(sx + tileSize / 2, sy + tileSize / 2, tileSize * 0.3, 0, Math.PI * 2);
        ctx.stroke();
        ctx.lineWidth = 1;
      }
      // One-way gates
      if ("><<^v".includes(tile) && tile !== ".") {
        const arrows = { ">": "→", "<": "←", "^": "↑", "v": "↓" };
        if (arrows[tile]) {
          ctx.fillStyle = "rgba(109, 78, 47, 0.35)";
          ctx.font = `${Math.floor(tileSize * 0.5)}px sans-serif`;
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          ctx.fillText(arrows[tile], sx + tileSize / 2, sy + tileSize / 2);
          ctx.textAlign = "left";
          ctx.textBaseline = "alphabetic";
        }
      }
      // Gravity tiles
      if (tile === "F") {
        ctx.fillStyle = "rgba(180, 80, 80, 0.25)";
        ctx.font = `${Math.floor(tileSize * 0.5)}px sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText("⬇", sx + tileSize / 2, sy + tileSize / 2);
        ctx.textAlign = "left";
        ctx.textBaseline = "alphabetic";
      }
      // Conveyor belts
      if ("RLUD".includes(tile)) {
        const convArrows = { R: "⇒", L: "⇐", U: "⇑", D: "⇓" };
        ctx.fillStyle = "rgba(60, 120, 60, 0.4)";
        ctx.font = `${Math.floor(tileSize * 0.45)}px sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(convArrows[tile], sx + tileSize / 2, sy + tileSize / 2);
        ctx.textAlign = "left";
        ctx.textBaseline = "alphabetic";
      }
    }
  }

  // Switches
  for (const switchDef of room.switches || []) {
    if (switchDef.layer !== layerIndex) continue;
    const sx = boardX + switchDef.x * tileSize;
    const sy = boardY + switchDef.y * tileSize;
    ctx.fillStyle = runtime.dynamicState.activeSwitches.has(switchDef.id) ? "#80a768" : "#b9d3a9";
    ctx.fillRect(sx + 7, sy + tileSize - 16, tileSize - 16, 9);
  }

  // Doors
  for (const door of room.doors || []) {
    if (door.layer !== layerIndex) continue;
    const sx = boardX + door.x * tileSize;
    const sy = boardY + door.y * tileSize;
    const open = runtime.dynamicState.openDoors.has(door.id);
    if (!open) {
      ctx.fillStyle = "#7d3f29";
      ctx.fillRect(sx + 7, sy + 3, tileSize - 16, tileSize - 6);
    } else {
      ctx.strokeStyle = "#7d3f29";
      ctx.strokeRect(sx + 9, sy + 5, tileSize - 20, tileSize - 10);
    }
  }

  // Entities
  for (const entity of runtime.entities) {
    if (entity.layer !== layerIndex) continue;
    const ex = boardX + entity.x * tileSize;
    const ey = boardY + entity.y * tileSize;
    if (entity.type === "parcel") {
      ctx.fillStyle = "#bf5f3c";
      ctx.fillRect(ex + 8, ey + 8, tileSize - 18, tileSize - 18);
      ctx.fillStyle = "#fff3e7";
      ctx.fillRect(ex + 15, ey + 15, tileSize - 32, tileSize - 32);
    } else if (entity.type === "projector") {
      ctx.fillStyle = "#d39b34";
      ctx.beginPath();
      ctx.arc(ex + tileSize / 2, ey + tileSize / 2, tileSize * 0.28, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#7d3f29";
      ctx.strokeRect(ex + 10, ey + 10, tileSize - 20, tileSize - 20);
    } else if (entity.type === "echo") {
      ctx.fillStyle = "rgba(105, 150, 211, 0.78)";
      ctx.beginPath();
      ctx.arc(ex + tileSize / 2, ey + tileSize / 2, tileSize * 0.28, 0, Math.PI * 2);
      ctx.fill();
    } else if (entity.type === "shadow") {
      ctx.fillStyle = "rgba(59, 44, 36, 0.78)";
      ctx.beginPath();
      ctx.arc(ex + tileSize / 2, ey + tileSize / 2, tileSize * 0.3, 0, Math.PI * 2);
      ctx.fill();
    } else if (entity.type === "key") {
      const kc = KEY_LOCK_COLORS[entity.color] || KEY_LOCK_COLORS.red;
      ctx.fillStyle = kc.fill;
      ctx.beginPath();
      ctx.arc(ex + tileSize / 2, ey + tileSize * 0.38, tileSize * 0.18, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillRect(ex + tileSize * 0.44, ey + tileSize * 0.45, tileSize * 0.12, tileSize * 0.32);
      ctx.fillRect(ex + tileSize * 0.48, ey + tileSize * 0.65, tileSize * 0.16, tileSize * 0.06);
    }
  }

  // Locks
  for (const lock of room.locks || []) {
    if (lock.layer !== layerIndex) continue;
    const lx = boardX + lock.x * tileSize;
    const ly = boardY + lock.y * tileSize;
    const open = runtime.dynamicState.openLocks.has(lock.id);
    const lc = KEY_LOCK_COLORS[lock.color] || KEY_LOCK_COLORS.red;
    if (!open) {
      ctx.fillStyle = lc.fill;
      ctx.globalAlpha = 0.7;
      ctx.fillRect(lx + 4, ly + 4, tileSize - 10, tileSize - 10);
      ctx.globalAlpha = 1;
      ctx.strokeStyle = lc.fill;
      ctx.lineWidth = 2;
      ctx.strokeRect(lx + 4, ly + 4, tileSize - 10, tileSize - 10);
      ctx.lineWidth = 1;
      // Lock icon
      ctx.fillStyle = "#fff";
      ctx.font = `${Math.floor(tileSize * 0.35)}px sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("🔒", lx + tileSize / 2, ly + tileSize / 2);
      ctx.textAlign = "left";
      ctx.textBaseline = "alphabetic";
    } else {
      ctx.strokeStyle = lc.light;
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 3]);
      ctx.strokeRect(lx + 6, ly + 6, tileSize - 14, tileSize - 14);
      ctx.setLineDash([]);
    }
  }

  // Player
  if (runtime.player.layer === layerIndex) {
    const px = boardX + runtime.player.x * tileSize;
    const py = boardY + runtime.player.y * tileSize;
    ctx.fillStyle = "#2f4d6a";
    ctx.beginPath();
    ctx.arc(px + tileSize / 2, py + tileSize / 2, tileSize * 0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f9dcb2";
    ctx.fillRect(px + tileSize * 0.4, py + tileSize * 0.22, tileSize * 0.18, tileSize * 0.18);
  }

  state.boardLayout.push({
    layerIndex, x: boardX, y: boardY,
    width: boardWidth, height: boardHeight, tileSize,
  });
}

function renderCanvas() {
  const room = currentRoom();
  const runtime = currentRuntime();
  const rect = el.canvas.getBoundingClientRect();
  const scale = window.devicePixelRatio || 1;
  el.canvas.width = rect.width * scale;
  el.canvas.height = rect.height * scale;
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  ctx.clearRect(0, 0, rect.width, rect.height);
  state.boardLayout = [];

  // Background
  ctx.fillStyle = "#e7d9b5";
  ctx.fillRect(0, 0, rect.width, rect.height);
  ctx.fillStyle = "rgba(255,255,255,0.25)";
  for (let i = 0; i < 12; i++) {
    ctx.beginPath();
    ctx.arc(100 + i * 110, 60 + (i % 4) * 30, 22, 0, Math.PI * 2);
    ctx.fill();
  }

  if (!room || !runtime) {
    ctx.fillStyle = "#5d301f";
    ctx.font = "700 34px Georgia";
    ctx.fillText("Patchwork Post", 72, 108);
    return;
  }

  const w = room.layers[0].tiles[0].length;
  const h = room.layers[0].tiles.length;
  const layerCount = room.layers.length;

  // Calculate tile size to fit the available space
  const availW = rect.width - 80;
  const availH = rect.height - 100;
  const maxTileByWidth = Math.floor(availW / (w * layerCount + (layerCount - 1) * 1.2));
  const maxTileByHeight = Math.floor((availH - 60) / h);
  const tileSize = Math.min(78, Math.max(36, Math.min(maxTileByWidth, maxTileByHeight)));

  const totalBoardWidth = layerCount * (w * tileSize + 48) - 48;
  const totalBoardHeight = h * tileSize + 60;
  const startX = Math.max(40, (rect.width - totalBoardWidth) / 2);
  const startY = Math.max(50, (rect.height - totalBoardHeight) / 2);

  room.layers.forEach((_, index) => {
    const boardX = startX + index * (w * tileSize + 48);
    const boardY = startY + (runtime.activeLayer === index ? 0 : 22);
    drawLayerBoard(index, boardX, boardY, tileSize);
  });

  // Replay indicator
  if (engine.replayState) {
    ctx.save();
    ctx.fillStyle = "rgba(255, 248, 228, 0.88)";
    const rw = 180;
    const rx = (rect.width - rw) / 2;
    drawRoundedRect(rx, 12, rw, 36, 14);
    ctx.fill();
    ctx.fillStyle = "#5d301f";
    ctx.font = "600 14px Trebuchet MS";
    ctx.textAlign = "center";
    ctx.fillText(`Replaying... ${engine.replayState.index}/${engine.replayState.actions.length}`, rect.width / 2, 36);
    ctx.textAlign = "left";
    ctx.restore();
  }

  // Keyboard shortcuts at bottom
  if (!runtime.solved && !engine.replayState) {
    ctx.save();
    ctx.font = "11px Trebuchet MS";
    ctx.fillStyle = "rgba(125, 104, 83, 0.45)";
    ctx.textAlign = "center";
    ctx.fillText("Arrows: Move · Tab: Switch Layer · X: Transfer · Z/Y: Undo/Redo · R: Reset · Esc: Map", rect.width / 2, rect.height - 8);
    ctx.textAlign = "left";
    ctx.restore();
  }
}

// ═══════════════════════════════════════
// Input handling
// ═══════════════════════════════════════

function keyToAction(code) {
  const controls = profile.settings.controls;
  const entry = Object.entries(controls).find(([, value]) => value === code);
  if (!entry) {
    const aliasMap = {
      Enter: { type: "switch_layer" },
      KeyB: { type: "transfer" },
      KeyA: { type: "wait" },
    };
    return aliasMap[code] || null;
  }
  const [action] = entry;
  if (["up", "down", "left", "right"].includes(action)) {
    return { type: "move", direction: action };
  }
  return { type: action };
}

function handleKeydown(event) {
  // Remap mode (on map screen)
  if (state.awaitingRemap) {
    event.preventDefault();
    profile.settings.controls[state.awaitingRemap] = event.code;
    state.awaitingRemap = null;
    saveProfile(profile);
    renderControls();
    return;
  }

  // Escape → back to map (from play screen)
  if (event.code === "Escape") {
    if (state.screen === "play") {
      if (state.hintOpen) {
        state.hintOpen = false;
        el.hintOverlay.classList.add("hidden");
      } else {
        setScreen("map");
      }
      event.preventDefault();
    }
    return;
  }

  // Only handle game input on play screen
  if (state.screen !== "play") return;

  // Don't handle while typing in inputs
  if (event.target instanceof HTMLTextAreaElement || event.target instanceof HTMLInputElement) return;

  // Don't handle game input when solve overlay is showing
  if (!el.solveOverlay.classList.contains("hidden")) return;

  const action = keyToAction(event.code);
  if (!action) return;
  event.preventDefault();
  if (action.type === "replay") {
    engine.startReplay(currentRuntime()?.actionLog || []);
    return;
  }
  performAction(action);
}

function handleCanvasClick(event) {
  if (state.screen !== "play") return;
  const room = currentRoom();
  const runtime = currentRuntime();
  if (!room || !runtime || runtime.solved) return;

  const rect = el.canvas.getBoundingClientRect();
  const canvasX = event.clientX - rect.left;
  const canvasY = event.clientY - rect.top;
  const board = state.boardLayout.find(
    (e) => canvasX >= e.x && canvasX <= e.x + e.width && canvasY >= e.y && canvasY <= e.y + e.height
  );
  if (!board) return;

  const tileX = Math.floor((canvasX - board.x) / board.tileSize);
  const tileY = Math.floor((canvasY - board.y) / board.tileSize);

  if (board.layerIndex === runtime.player.layer) {
    const dx = tileX - runtime.player.x;
    const dy = tileY - runtime.player.y;
    if (Math.abs(dx) + Math.abs(dy) === 1) {
      if (dx === 1) performAction({ type: "move", direction: "right" });
      if (dx === -1) performAction({ type: "move", direction: "left" });
      if (dy === 1) performAction({ type: "move", direction: "down" });
      if (dy === -1) performAction({ type: "move", direction: "up" });
    }
  } else if (
    tileX === runtime.player.x &&
    tileY === runtime.player.y &&
    room.layers[runtime.player.layer].tiles[runtime.player.y]?.[runtime.player.x] === "S" &&
    room.layers[board.layerIndex].tiles[tileY]?.[tileX] === "S"
  ) {
    performAction({ type: "switch_layer" });
  }
}

function pollGamepad() {
  if (state.screen !== "play") return;
  const gamepad = navigator.getGamepads?.()[0];
  if (!gamepad) {
    state.gamepadState = {};
    return;
  }
  const buttons = {
    up: gamepad.buttons[12]?.pressed,
    down: gamepad.buttons[13]?.pressed,
    left: gamepad.buttons[14]?.pressed,
    right: gamepad.buttons[15]?.pressed,
    wait: gamepad.buttons[0]?.pressed,
    transfer: gamepad.buttons[2]?.pressed,
    switch_layer: gamepad.buttons[3]?.pressed,
    undo: gamepad.buttons[4]?.pressed,
    redo: gamepad.buttons[5]?.pressed,
    reset: gamepad.buttons[8]?.pressed,
  };
  for (const [action, pressed] of Object.entries(buttons)) {
    if (!pressed || state.gamepadState[action]) continue;
    if (["up", "down", "left", "right"].includes(action)) {
      performAction({ type: "move", direction: action });
    } else {
      performAction({ type: action });
    }
  }
  state.gamepadState = buttons;
}

// ═══════════════════════════════════════
// Event binding
// ═══════════════════════════════════════

function bindEvents() {
  // Title screen
  el.startBtn.addEventListener("click", () => {
    const nextRoom = findNextRoom() || "mailroom-01";
    ensureRoomLoaded(nextRoom);
    syncEditorFromRoom();
    setScreen("play");
  });

  el.resumeBtn.addEventListener("click", () => {
    ensureRoomLoaded(profile.lastRoomId || "mailroom-01");
    syncEditorFromRoom();
    setScreen("play");
  });

  // Play HUD buttons
  el.hudBack.addEventListener("click", () => setScreen("map"));
  el.hudHint.addEventListener("click", () => {
    state.hintOpen = !state.hintOpen;
    el.hintOverlay.classList.toggle("hidden", !state.hintOpen);
    if (state.hintOpen) updateHintOverlay();
  });
  el.hintClose.addEventListener("click", () => {
    state.hintOpen = false;
    el.hintOverlay.classList.add("hidden");
  });
  el.hudUndo.addEventListener("click", () => performAction({ type: "undo" }));
  el.hudRedo.addEventListener("click", () => performAction({ type: "redo" }));
  el.hudReset.addEventListener("click", () => performAction({ type: "reset" }));

  // Hint tier buttons
  document.querySelectorAll("[data-hint-tier]").forEach((button) => {
    button.addEventListener("click", () => {
      const room = currentRoom();
      if (!room || engine.previewMode) return;
      revealHint(profile, room.id, Number(button.dataset.hintTier));
      saveProfile(profile);
      updateHintOverlay();
    });
  });

  // Solve overlay buttons
  el.solveNext.addEventListener("click", () => {
    advanceToNextRoom();
  });
  el.solveReplay.addEventListener("click", () => {
    state.autoAdvanceTimer = 0;
    state.autoAdvanceTarget = null;
    el.solveOverlay.classList.add("hidden");
    engine.startReplay(currentRuntime()?.actionLog || []);
  });
  el.solveMap.addEventListener("click", () => {
    state.autoAdvanceTimer = 0;
    state.autoAdvanceTarget = null;
    setScreen("map");
  });

  // Play control bar buttons
  document.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const actionName = button.dataset.action;
      if (["up", "down", "left", "right"].includes(actionName)) {
        performAction({ type: "move", direction: actionName });
      } else if (actionName === "replay") {
        engine.startReplay(currentRuntime()?.actionLog || []);
      } else {
        performAction({ type: actionName });
      }
    });
  });

  // Settings
  el.settingContrast.addEventListener("change", () => {
    profile.settings.highContrast = el.settingContrast.checked;
    saveProfile(profile);
    renderMapStats();
  });
  el.settingMotion.addEventListener("change", () => {
    profile.settings.reducedMotion = el.settingMotion.checked;
    saveProfile(profile);
  });
  el.settingFontScale.addEventListener("input", () => {
    profile.settings.fontScale = Number(el.settingFontScale.value);
    saveProfile(profile);
    renderMapStats();
  });

  // Content tools
  el.refreshRoomJson.addEventListener("click", syncEditorFromRoom);
  el.validateRoom.addEventListener("click", () => {
    try {
      const roomData = JSON.parse(el.roomJson.value);
      el.validationOutput.textContent = validateRoom(roomData).join("\n");
    } catch (error) {
      el.validationOutput.textContent = `Invalid JSON: ${error.message}`;
    }
  });
  el.loadRoomJson.addEventListener("click", () => {
    try {
      const roomData = JSON.parse(el.roomJson.value);
      roomData.hintTiers = [
        el.authorHint1.value || roomData.hintTiers?.[0] || "",
        el.authorHint2.value || roomData.hintTiers?.[1] || "",
        el.authorHint3.value || roomData.hintTiers?.[2] || "",
      ];
      engine.loadPreviewRoom(roomData);
      state.currentRoomId = roomData.id || "__preview__";
      setScreen("play");
    } catch (error) {
      el.validationOutput.textContent = `Invalid JSON: ${error.message}`;
    }
  });
  el.replayCurrent.addEventListener("click", () => {
    engine.startReplay(currentRuntime()?.actionLog || []);
  });
  el.replaySolution.addEventListener("click", () => {
    const bestSolution = getRoomProgress(profile, state.currentRoomId).bestSolution || [];
    if (!bestSolution.length) {
      el.validationOutput.textContent = "No saved best solution yet for this room.";
      return;
    }
    engine.startReplay(bestSolution);
  });

  // Global input
  window.addEventListener("keydown", handleKeydown);
  el.canvas.addEventListener("click", handleCanvasClick);
}

// ═══════════════════════════════════════
// Update loop
// ═══════════════════════════════════════

function updateLoop(now) {
  const delta = now - state.lastRenderTime;
  state.lastRenderTime = now;

  if (state.screen === "play") {
    engine.update(profile.settings.reducedMotion ? Math.max(delta, 260) : delta);
    pollGamepad();
    renderCanvas();

    // Auto-advance countdown
    if (state.autoAdvanceTimer > 0 && state.autoAdvanceTarget) {
      state.autoAdvanceTimer -= delta;
      const seconds = Math.max(0, Math.ceil(state.autoAdvanceTimer / 1000));
      el.solveNext.textContent = seconds > 0 ? `Next Room (${seconds}s) →` : "Next Room →";
      if (state.autoAdvanceTimer <= 0) {
        advanceToNextRoom();
      }
    }
  }

  requestAnimationFrame(updateLoop);
}

// ═══════════════════════════════════════
// Boot
// ═══════════════════════════════════════

function boot() {
  ensureRoomLoaded(state.currentRoomId);
  bindEvents();
  syncEditorFromRoom();

  if (autoStart) {
    setScreen("play");
  } else {
    setScreen("title");
  }

  window.render_game_to_text = () =>
    JSON.stringify({
      mode: state.screen,
      currentRoomId: state.currentRoomId,
      postmarks: getPostmarkCount(profile, campaign),
      solvedRooms: getSolvedCount(profile),
      ...engine.getTextState(),
    });

  window.advanceTime = (ms) => {
    engine.update(ms);
    renderCanvas();
  };

  requestAnimationFrame(updateLoop);
}

boot();
