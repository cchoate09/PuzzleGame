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
  started: autoStart,
  awaitingRemap: null,
  currentRoomId: initialRoomId,
  boardLayout: [],
  lastRenderTime: performance.now(),
  gamepadState: {},
  solveBannerTimer: 0,
  solveBannerShown: false,
};

const elements = {
  body: document.body,
  canvas: document.getElementById("game-canvas"),
  startScreen: document.getElementById("start-screen"),
  startBtn: document.getElementById("start-btn"),
  resumeBtn: document.getElementById("resume-btn"),
  districtList: document.getElementById("district-list"),
  postmarkCount: document.getElementById("postmark-count"),
  roomCount: document.getElementById("room-count"),
  districtName: document.getElementById("district-name"),
  roomName: document.getElementById("room-name"),
  moveCount: document.getElementById("move-count"),
  activeLayerName: document.getElementById("active-layer-name"),
  objectiveText: document.getElementById("objective-text"),
  storyTitle: document.getElementById("story-title"),
  storySummary: document.getElementById("story-summary"),
  dialogueCard: document.getElementById("dialogue-card"),
  hintSummary: document.getElementById("hint-summary"),
  hintList: document.getElementById("hint-list"),
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
};

const ctx = elements.canvas.getContext("2d");

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
  state.solveBannerShown = false;
  state.solveBannerTimer = 0;
  profile.lastRoomId = roomId;
  saveProfile(profile);
}

function roomSolved(roomId) {
  return !!profile.rooms[roomId]?.solved;
}

function isDistrictUnlocked(district) {
  return getPostmarkCount(profile, campaign) >= district.unlockPostmarks;
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

function isRoomUnlocked(room) {
  const district = getDistrictById(room.districtId);
  if (!district || !isDistrictUnlocked(district)) {
    return false;
  }

  const districtRooms = getRoomsForDistrict(room.districtId);
  const mandatoryRooms = districtRooms.filter((candidate) => !candidate.optional);
  if (room.optional) {
    if (!mandatoryRooms.length) {
      return true;
    }
    return mandatoryRooms.some((candidate) => roomSolved(candidate.id));
  }

  const roomIndex = mandatoryRooms.findIndex((candidate) => candidate.id === room.id);
  if (roomIndex <= 0) {
    return true;
  }
  return mandatoryRooms.slice(0, roomIndex).every((candidate) => roomSolved(candidate.id));
}

function persistCurrentSnapshot() {
  const room = currentRoom();
  if (!room || engine.previewMode) {
    return;
  }
  setRoomSnapshot(profile, room.id, currentRuntime().solved ? null : engine.getRoomSnapshot());
  profile.lastRoomId = room.id;
  saveProfile(profile);
}

function onRoomSolved() {
  const room = currentRoom();
  const runtime = currentRuntime();
  if (!room || !runtime?.solved || engine.previewMode || roomSolved(room.id)) {
    return;
  }

  const roomProgress = getRoomProgress(profile, room.id);
  completeRoom(profile, room, runtime);
  unlockJournal(profile, room.districtId);
  if (room.achievementId) {
    unlockAchievement(profile, room.achievementId);
  }
  if ((roomProgress.hintsRevealed || 0) === 0) {
    unlockAchievement(profile, "careful-hands");
  }
  saveProfile(profile);
  state.solveBannerTimer = 5000;
  state.solveBannerShown = true;
}

function performAction(action) {
  let changed = false;

  if (["undo", "redo", "reset"].includes(action.type)) {
    changed = engine.dispatch(action);
  } else {
    changed = engine.dispatch(action);
  }

  if (!changed) {
    return;
  }

  persistCurrentSnapshot();
  onRoomSolved();
  renderUI();
}

function setStarted(started) {
  state.started = started;
  elements.startScreen.classList.toggle("hidden", started);
}

function renderDistrictList() {
  elements.districtList.innerHTML = "";
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
      button.className = `room-button ${room.id === state.currentRoomId ? "active" : ""} ${roomSolved(room.id) ? "solved" : ""} ${unlockedRoom ? "" : "locked"}`;
      button.disabled = !unlockedRoom;
      button.dataset.roomId = room.id;
      const solved = roomSolved(room.id);
      const icon = solved ? "✓ " : (unlockedRoom ? "" : "");
      button.innerHTML = `
        <span>${icon}${room.title}</span>
        <span class="badge ${room.optional ? "optional" : "mandatory"}">${room.optional ? "Side" : "Main"}</span>
      `;
      if (!unlockedRoom) {
        const lockReason = getRoomLockReason(room, district, unlocked);
        if (lockReason) {
          button.title = lockReason;
        }
      }
      roomList.append(button);
    }

    if (!unlocked) {
      const note = document.createElement("p");
      note.textContent = `Locked until you collect ${district.unlockPostmarks} postmarks. You have ${postmarks}.`;
      card.append(note);
    }

    elements.districtList.append(card);
  }

  elements.districtList.querySelectorAll("[data-room-id]").forEach((button) => {
    button.addEventListener("click", () => {
      const roomId = button.dataset.roomId;
      ensureRoomLoaded(roomId);
      setStarted(true);
      syncEditorFromRoom();
      renderUI();
    });
  });
}

function renderStoryAndHints() {
  const room = currentRoom();
  const district = room ? getDistrictById(room.districtId) : null;
  const roomProgress = room ? getRoomProgress(profile, room.id) : null;
  const hintsRevealed = roomProgress?.hintsRevealed || 0;

  elements.storyTitle.textContent = district?.title || "Town Journal";
  elements.storySummary.textContent = district?.journalBody || "Restore the route, one fold at a time.";
  elements.dialogueCard.innerHTML = room?.intro
    ?.map((entry) => `<p><strong>${entry.speaker}:</strong> ${entry.text}</p>`)
    .join("") || "<p>No active story beat.</p>";

  elements.hintSummary.textContent = room
    ? `${hintsRevealed} of 3 hint tiers revealed in this room.`
    : "Hints appear once you enter a room.";
  elements.hintList.innerHTML = "";
  if (room) {
    for (let index = 0; index < hintsRevealed; index += 1) {
      const hint = document.createElement("div");
      hint.className = "hint-entry";
      hint.innerHTML = `<strong>Hint ${index + 1}</strong><p>${room.hintTiers[index]}</p>`;
      elements.hintList.append(hint);
    }
  }
}

function renderJournalAndAchievements() {
  elements.journalList.innerHTML = "";
  for (const districtId of profile.journalsUnlocked) {
    const district = getDistrictById(districtId);
    if (!district) {
      continue;
    }
    const entry = document.createElement("article");
    entry.className = "journal-entry";
    entry.innerHTML = `<h4>${district.journalTitle}</h4><p>${district.journalBody}</p>`;
    elements.journalList.append(entry);
  }
  if (!profile.journalsUnlocked.length) {
    elements.journalList.innerHTML = "<p>No journal pages unlocked yet.</p>";
  }

  elements.achievementList.innerHTML = "";
  for (const achievement of campaign.achievements) {
    const unlocked = !!profile.achievements[achievement.id];
    const entry = document.createElement("article");
    entry.className = "achievement-entry";
    entry.innerHTML = `
      <h4>${achievement.title}</h4>
      <p>${achievement.description}</p>
      <span class="badge ${unlocked ? "mandatory" : "locked"}">${unlocked ? "Unlocked" : "Locked"}</span>
    `;
    elements.achievementList.append(entry);
  }
}

function renderControls() {
  elements.controlList.innerHTML = "";
  for (const [action, code] of Object.entries(profile.settings.controls)) {
    const row = document.createElement("div");
    row.className = "control-row";
    row.innerHTML = `
      <span>${action.replace("_", " ")}</span>
      <button data-remap="${action}" class="${state.awaitingRemap === action ? "remap-pending" : ""}">
        ${state.awaitingRemap === action ? "Press a key" : code}
      </button>
    `;
    elements.controlList.append(row);
  }

  elements.controlList.querySelectorAll("[data-remap]").forEach((button) => {
    button.addEventListener("click", () => {
      state.awaitingRemap = button.dataset.remap;
      renderControls();
    });
  });
}

function syncEditorFromRoom() {
  const room = currentRoom();
  if (!room) {
    return;
  }
  elements.roomJson.value = JSON.stringify(room, null, 2);
  elements.authorHint1.value = room.hintTiers?.[0] || "";
  elements.authorHint2.value = room.hintTiers?.[1] || "";
  elements.authorHint3.value = room.hintTiers?.[2] || "";
  elements.validationOutput.textContent = "";
}

function renderActionLog() {
  const actions = currentRuntime()?.actionLog || [];
  if (!actions.length) {
    elements.actionLog.textContent = "No actions recorded yet.";
    return;
  }
  elements.actionLog.textContent = actions
    .map((action, index) => `${index + 1}. ${action.type}${action.direction ? `:${action.direction}` : ""}`)
    .join("\n");
}

function renderStatus() {
  const room = currentRoom();
  const runtime = currentRuntime();
  const postmarks = getPostmarkCount(profile, campaign);
  const solvedCount = getSolvedCount(profile);

  elements.postmarkCount.textContent = String(postmarks);
  elements.roomCount.textContent = `${solvedCount} / ${campaign.rooms.length}`;
  elements.settingContrast.checked = !!profile.settings.highContrast;
  elements.settingMotion.checked = !!profile.settings.reducedMotion;
  elements.settingFontScale.value = String(profile.settings.fontScale || 1);
  document.documentElement.style.fontSize = `${(profile.settings.fontScale || 1) * 16}px`;
  document.body.classList.toggle("high-contrast", !!profile.settings.highContrast);

  if (!room || !runtime) {
    return;
  }

  const district = getDistrictById(room.districtId);
  elements.districtName.textContent = district?.title || room.districtId;
  elements.roomName.textContent = room.title;
  elements.moveCount.textContent = String(runtime.moveCount);
  elements.activeLayerName.textContent = room.layers[runtime.activeLayer]?.name || "Unknown";
  elements.objectiveText.textContent = runtime.solved
    ? "Route restored. Pick another room from the map."
    : room.objective;
}

function renderUI() {
  renderDistrictList();
  renderStoryAndHints();
  renderJournalAndAchievements();
  renderControls();
  renderStatus();
  renderActionLog();
}

function tileColor(tile) {
  switch (tile) {
    case "#":
      return "#ad8c63";
    case "~":
      return "#d7c5a2";
    case "S":
      return "#f7efdd";
    case "G":
      return "#f7e0a1";
    default:
      return "#fff8ed";
  }
}

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

  ctx.save();
  ctx.shadowColor = "rgba(74, 43, 17, 0.18)";
  ctx.shadowBlur = active ? 18 : 8;
  ctx.shadowOffsetY = active ? 12 : 8;
  ctx.fillStyle = active ? "#fffdf8" : "#f5ebd5";
  const cardX = boardX - 18;
  const cardY = boardY - 54;
  const cardW = boardWidth + 36;
  const cardH = boardHeight + 62;
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

  ctx.fillStyle = active ? "#5d301f" : "#7d6853";
  ctx.font = active ? "700 22px Georgia" : "600 18px Georgia";
  ctx.fillText(layer.name, boardX - 2, boardY - 20);

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const tile = layer.tiles[y][x];
      const screenX = boardX + x * tileSize;
      const screenY = boardY + y * tileSize;

      ctx.fillStyle = tileColor(tile);
      ctx.fillRect(screenX, screenY, tileSize - 2, tileSize - 2);

      if (tile === "#") {
        ctx.fillStyle = "#8d6a45";
        ctx.fillRect(screenX + 6, screenY + 6, tileSize - 14, tileSize - 14);
      }
      if (tile === "S") {
        ctx.fillStyle = "rgba(247, 224, 161, 0.35)";
        ctx.fillRect(screenX + 8, screenY + 8, tileSize - 18, tileSize - 18);
        ctx.strokeStyle = "#7d3f29";
        ctx.lineWidth = 2;
        ctx.setLineDash([6, 4]);
        ctx.strokeRect(screenX + 8, screenY + 8, tileSize - 18, tileSize - 18);
        ctx.setLineDash([]);
        ctx.lineWidth = 1;
        ctx.fillStyle = "#7d3f29";
        const cx = screenX + tileSize / 2;
        const cy = screenY + tileSize / 2;
        const d = 5;
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
        ctx.moveTo(screenX + 10, screenY + 10);
        ctx.lineTo(screenX + tileSize - 12, screenY + tileSize - 12);
        ctx.moveTo(screenX + tileSize - 12, screenY + 10);
        ctx.lineTo(screenX + 10, screenY + tileSize - 12);
        ctx.stroke();
      }
      if (tile === "G") {
        ctx.fillStyle = "#d39b34";
        ctx.fillRect(screenX + tileSize * 0.25, screenY + tileSize * 0.35, tileSize * 0.5, tileSize * 0.4);
        ctx.fillStyle = "#7d3f29";
        ctx.fillRect(screenX + tileSize * 0.35, screenY + tileSize * 0.2, tileSize * 0.3, tileSize * 0.2);
      }
    }
  }

  for (const switchDef of room.switches || []) {
    if (switchDef.layer !== layerIndex) {
      continue;
    }
    const x = boardX + switchDef.x * tileSize;
    const y = boardY + switchDef.y * tileSize;
    ctx.fillStyle = runtime.dynamicState.activeSwitches.has(switchDef.id) ? "#80a768" : "#b9d3a9";
    ctx.fillRect(x + 8, y + tileSize - 18, tileSize - 18, 10);
  }

  for (const door of room.doors || []) {
    if (door.layer !== layerIndex) {
      continue;
    }
    const x = boardX + door.x * tileSize;
    const y = boardY + door.y * tileSize;
    const open = runtime.dynamicState.openDoors.has(door.id);
    if (!open) {
      ctx.fillStyle = "#7d3f29";
      ctx.fillRect(x + 8, y + 4, tileSize - 18, tileSize - 8);
    } else {
      ctx.strokeStyle = "#7d3f29";
      ctx.strokeRect(x + 10, y + 6, tileSize - 22, tileSize - 12);
    }
  }

  for (const entity of runtime.entities) {
    if (entity.layer !== layerIndex) {
      continue;
    }
    const x = boardX + entity.x * tileSize;
    const y = boardY + entity.y * tileSize;
    if (entity.type === "parcel") {
      ctx.fillStyle = "#bf5f3c";
      ctx.fillRect(x + 10, y + 10, tileSize - 22, tileSize - 22);
      ctx.fillStyle = "#fff3e7";
      ctx.fillRect(x + 18, y + 18, tileSize - 38, tileSize - 38);
    } else if (entity.type === "projector") {
      ctx.fillStyle = "#d39b34";
      ctx.beginPath();
      ctx.arc(x + tileSize / 2, y + tileSize / 2, tileSize * 0.28, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#7d3f29";
      ctx.strokeRect(x + 12, y + 12, tileSize - 24, tileSize - 24);
    } else if (entity.type === "echo") {
      ctx.fillStyle = "rgba(105, 150, 211, 0.78)";
      ctx.beginPath();
      ctx.arc(x + tileSize / 2, y + tileSize / 2, tileSize * 0.28, 0, Math.PI * 2);
      ctx.fill();
    } else if (entity.type === "shadow") {
      ctx.fillStyle = "rgba(59, 44, 36, 0.78)";
      ctx.beginPath();
      ctx.arc(x + tileSize / 2, y + tileSize / 2, tileSize * 0.3, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  if (runtime.player.layer === layerIndex) {
    const x = boardX + runtime.player.x * tileSize;
    const y = boardY + runtime.player.y * tileSize;
    ctx.fillStyle = "#2f4d6a";
    ctx.beginPath();
    ctx.arc(x + tileSize / 2, y + tileSize / 2, tileSize * 0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#f9dcb2";
    ctx.fillRect(x + tileSize * 0.4, y + tileSize * 0.22, tileSize * 0.18, tileSize * 0.18);
  }

  state.boardLayout.push({
    layerIndex,
    x: boardX,
    y: boardY,
    width: boardWidth,
    height: boardHeight,
    tileSize,
  });
}

function renderCanvas() {
  const room = currentRoom();
  const runtime = currentRuntime();
  const rect = elements.canvas.getBoundingClientRect();
  const scale = window.devicePixelRatio || 1;
  elements.canvas.width = rect.width * scale;
  elements.canvas.height = rect.height * scale;
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  ctx.clearRect(0, 0, rect.width, rect.height);
  state.boardLayout = [];

  ctx.fillStyle = "#e7d9b5";
  ctx.fillRect(0, 0, rect.width, rect.height);
  ctx.fillStyle = "rgba(255,255,255,0.35)";
  for (let index = 0; index < 9; index += 1) {
    ctx.beginPath();
    ctx.arc(140 + index * 120, 80 + (index % 3) * 36, 28, 0, Math.PI * 2);
    ctx.fill();
  }

  if (!room || !runtime) {
    ctx.fillStyle = "#5d301f";
    ctx.font = "700 34px Georgia";
    ctx.fillText("Patchwork Post", 72, 108);
    return;
  }

  const width = room.layers[0].tiles[0].length;
  const height = room.layers[0].tiles.length;
  const layerCount = room.layers.length;
  const tileSize = Math.min(78, Math.max(54, Math.floor((rect.width - 240) / (width * layerCount + 6))));
  const totalBoardWidth = layerCount * (width * tileSize + 48) - 48;
  const startX = Math.max(56, (rect.width - totalBoardWidth) / 2);
  const startY = Math.max(150, (rect.height - (height * tileSize + 90)) / 2);

  room.layers.forEach((_, index) => {
    const boardX = startX + index * (width * tileSize + 48);
    const boardY = startY + (runtime.activeLayer === index ? 0 : 28);
    drawLayerBoard(index, boardX, boardY, tileSize);
  });

  ctx.fillStyle = "#5d301f";
  ctx.font = "700 32px Georgia";
  ctx.fillText(room.title, 56, 52);
  ctx.font = "16px Trebuchet MS";
  ctx.fillStyle = "#7d6853";
  ctx.fillText(room.blurb, 56, 78);

  if (runtime.solved && state.solveBannerShown) {
    const bannerAlpha = Math.min(1, state.solveBannerTimer / 800);
    if (bannerAlpha > 0) {
      ctx.save();
      ctx.globalAlpha = bannerAlpha;
      const bannerW = 340;
      const bannerH = 110;
      const bannerX = (rect.width - bannerW) / 2;
      const bannerY = 16;
      ctx.fillStyle = "rgba(255, 248, 228, 0.96)";
      ctx.shadowColor = "rgba(74, 43, 17, 0.22)";
      ctx.shadowBlur = 24;
      ctx.shadowOffsetY = 6;
      drawRoundedRect(bannerX, bannerY, bannerW, bannerH, 22);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.shadowOffsetY = 0;
      ctx.fillStyle = "#5d301f";
      ctx.font = "700 26px Georgia";
      ctx.textAlign = "center";
      ctx.fillText("Route Restored", rect.width / 2, bannerY + 36);
      const roomProgress = getRoomProgress(profile, room.id);
      const moves = runtime.moveCount;
      const best = roomProgress.bestMoves;
      const hints = roomProgress.hintsRevealed || 0;
      ctx.font = "15px Trebuchet MS";
      ctx.fillStyle = "#7d6853";
      const isNewBest = best != null && moves <= best;
      const bestText = best != null ? `Best: ${best}${isNewBest ? " ★" : ""}` : "";
      ctx.fillText(`${moves} moves${bestText ? "  ·  " + bestText : ""}  ·  Hints: ${hints}`, rect.width / 2, bannerY + 62);
      ctx.font = "14px Trebuchet MS";
      ctx.fillStyle = "#a08870";
      ctx.fillText("Pick another room from the map.", rect.width / 2, bannerY + 86);
      ctx.textAlign = "left";
      ctx.restore();
    }
  }

  if (engine.replayState) {
    ctx.save();
    ctx.fillStyle = "rgba(255, 248, 228, 0.88)";
    const replayW = 180;
    const replayX = (rect.width - replayW) / 2;
    drawRoundedRect(replayX, 16, replayW, 40, 14);
    ctx.fill();
    ctx.fillStyle = "#5d301f";
    ctx.font = "600 15px Trebuchet MS";
    ctx.textAlign = "center";
    const step = engine.replayState.index;
    const total = engine.replayState.actions.length;
    ctx.fillText(`Replaying... ${step}/${total}`, rect.width / 2, 42);
    ctx.textAlign = "left";
    ctx.restore();
  }

  if (!runtime.solved && !engine.replayState) {
    ctx.save();
    ctx.font = "12px Trebuchet MS";
    ctx.fillStyle = "rgba(125, 104, 83, 0.55)";
    const shortcuts = "Arrows: Move  ·  Tab: Switch Layer  ·  X: Transfer  ·  Z/Y: Undo/Redo  ·  R: Reset  ·  P: Replay";
    ctx.textAlign = "center";
    ctx.fillText(shortcuts, rect.width / 2, rect.height - 12);
    ctx.textAlign = "left";
    ctx.restore();
  }
}

function renderAll() {
  renderUI();
  renderCanvas();
}

function handleHintRequest(tier) {
  const room = currentRoom();
  if (!room || engine.previewMode) {
    return;
  }
  revealHint(profile, room.id, tier);
  saveProfile(profile);
  renderUI();
}

function handleCanvasClick(event) {
  if (!state.started) {
    return;
  }
  const room = currentRoom();
  const runtime = currentRuntime();
  if (!room || !runtime) {
    return;
  }
  const rect = elements.canvas.getBoundingClientRect();
  const canvasX = event.clientX - rect.left;
  const canvasY = event.clientY - rect.top;
  const board = state.boardLayout.find(
    (entry) =>
      canvasX >= entry.x &&
      canvasX <= entry.x + entry.width &&
      canvasY >= entry.y &&
      canvasY <= entry.y + entry.height
  );
  if (!board) {
    return;
  }
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
    room.layers[runtime.player.layer].tiles[runtime.player.y][runtime.player.x] === "S" &&
    room.layers[board.layerIndex].tiles[tileY][tileX] === "S"
  ) {
    performAction({ type: "switch_layer" });
  }
}

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
  if (state.awaitingRemap) {
    event.preventDefault();
    profile.settings.controls[state.awaitingRemap] = event.code;
    state.awaitingRemap = null;
    saveProfile(profile);
    renderControls();
    return;
  }

  if (event.target instanceof HTMLTextAreaElement || event.target instanceof HTMLInputElement) {
    return;
  }

  const action = keyToAction(event.code);
  if (!action) {
    return;
  }
  event.preventDefault();
  if (action.type === "replay") {
    engine.startReplay(currentRuntime()?.actionLog || []);
    return;
  }
  performAction(action);
}

function pollGamepad() {
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
    if (!pressed || state.gamepadState[action]) {
      continue;
    }
    if (["up", "down", "left", "right"].includes(action)) {
      performAction({ type: "move", direction: action });
    } else {
      performAction({ type: action });
    }
  }

  state.gamepadState = buttons;
}

function bindEvents() {
  elements.startBtn.addEventListener("click", () => {
    ensureRoomLoaded("mailroom-01");
    syncEditorFromRoom();
    setStarted(true);
    renderAll();
  });

  elements.resumeBtn.addEventListener("click", () => {
    ensureRoomLoaded(profile.lastRoomId || "mailroom-01");
    syncEditorFromRoom();
    setStarted(true);
    renderAll();
  });

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

  document.querySelectorAll("[data-hint-tier]").forEach((button) => {
    button.addEventListener("click", () => {
      handleHintRequest(Number(button.dataset.hintTier));
    });
  });

  elements.settingContrast.addEventListener("change", () => {
    profile.settings.highContrast = elements.settingContrast.checked;
    saveProfile(profile);
    renderUI();
  });

  elements.settingMotion.addEventListener("change", () => {
    profile.settings.reducedMotion = elements.settingMotion.checked;
    saveProfile(profile);
  });

  elements.settingFontScale.addEventListener("input", () => {
    profile.settings.fontScale = Number(elements.settingFontScale.value);
    saveProfile(profile);
    renderUI();
  });

  elements.refreshRoomJson.addEventListener("click", syncEditorFromRoom);

  elements.validateRoom.addEventListener("click", () => {
    try {
      const roomData = JSON.parse(elements.roomJson.value);
      elements.validationOutput.textContent = validateRoom(roomData).join("\n");
    } catch (error) {
      elements.validationOutput.textContent = `Invalid JSON: ${error.message}`;
    }
  });

  elements.loadRoomJson.addEventListener("click", () => {
    try {
      const roomData = JSON.parse(elements.roomJson.value);
      roomData.hintTiers = [
        elements.authorHint1.value || roomData.hintTiers?.[0] || "",
        elements.authorHint2.value || roomData.hintTiers?.[1] || "",
        elements.authorHint3.value || roomData.hintTiers?.[2] || "",
      ];
      engine.loadPreviewRoom(roomData);
      state.currentRoomId = roomData.id || "__preview__";
      setStarted(true);
      renderAll();
    } catch (error) {
      elements.validationOutput.textContent = `Invalid JSON: ${error.message}`;
    }
  });

  elements.replayCurrent.addEventListener("click", () => {
    engine.startReplay(currentRuntime()?.actionLog || []);
  });

  elements.replaySolution.addEventListener("click", () => {
    const bestSolution = getRoomProgress(profile, state.currentRoomId).bestSolution || [];
    if (!bestSolution.length) {
      elements.validationOutput.textContent = "No saved best solution yet for this room.";
      return;
    }
    engine.startReplay(bestSolution);
  });

  window.addEventListener("keydown", handleKeydown);
  elements.canvas.addEventListener("click", handleCanvasClick);
}

function updateLoop(now) {
  const delta = now - state.lastRenderTime;
  state.lastRenderTime = now;
  engine.update(profile.settings.reducedMotion ? Math.max(delta, 260) : delta);
  if (state.solveBannerTimer > 0) {
    state.solveBannerTimer = Math.max(0, state.solveBannerTimer - delta);
    if (state.solveBannerTimer <= 0) {
      state.solveBannerShown = false;
    }
  }
  pollGamepad();
  renderCanvas();
  requestAnimationFrame(updateLoop);
}

function boot() {
  ensureRoomLoaded(state.currentRoomId);
  bindEvents();
  syncEditorFromRoom();
  setStarted(autoStart);
  renderAll();

  window.render_game_to_text = () =>
    JSON.stringify({
      mode: state.started ? "room" : "title",
      started: state.started,
      postmarks: getPostmarkCount(profile, campaign),
      solvedRooms: getSolvedCount(profile),
      currentRoomId: state.currentRoomId,
      ...engine.getTextState(),
    });

  window.advanceTime = (ms) => {
    engine.update(ms);
    renderCanvas();
  };

  requestAnimationFrame(updateLoop);
}

boot();
