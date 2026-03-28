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
import { AudioManager } from "./audio/audio-manager.js";

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
  tutorialStep: 0,
  tutorialTotal: 6,
  legendOpen: false,
};

// ═══════════════════════════════════════
// Audio manager
// ═══════════════════════════════════════
const audio = new AudioManager();

// ═══════════════════════════════════════
// Animation state — visual interpolation
// ═══════════════════════════════════════
const anim = {
  playerX: 0,
  playerY: 0,
  playerLayer: 0,
  displayedActiveLayer: 0,
  cameraX: 0,            // smooth horizontal scroll offset
  enterProgress: 0,       // 0→1 room entry fade-in
  solveFlash: 0,          // 1→0 golden flash
  stampRingRadius: 0,     // expanding ring on solve
  stampRingAlpha: 0,
  confetti: [],           // { x, y, vx, vy, rot, drot, w, h, color, alpha }
  keySparkles: [],        // { x, y, alpha, radius }
  screenShake: 0,         // screen shake intensity
  goalPulse: 0,           // 0→2π cycling pulse for goal tiles
  initialized: false,
};

function moveToward(current, target, maxDelta) {
  if (Math.abs(target - current) <= maxDelta) return target;
  return current + Math.sign(target - current) * maxDelta;
}

function initAnimFromRuntime() {
  const rt = currentRuntime();
  if (!rt) return;
  anim.playerX = rt.player.x;
  anim.playerY = rt.player.y;
  anim.playerLayer = rt.player.layer;
  anim.displayedActiveLayer = rt.activeLayer;
  anim.cameraX = 0; // will be set properly on first render
  anim.enterProgress = 0;
  anim.solveFlash = 0;
  anim.stampRingRadius = 0;
  anim.stampRingAlpha = 0;
  anim.confetti = [];
  anim.keySparkles = [];
  anim.screenShake = 0;
  anim.goalPulse = 0;
  anim.initialized = true;
}

function triggerSolveEffects() {
  anim.solveFlash = 1.0;
  anim.stampRingRadius = 0;
  anim.stampRingAlpha = 1.0;
  anim.screenShake = 6;
  // Spawn confetti
  const palette = ["#d39b34", "#bf5f3c", "#2f4d6a", "#5d301f", "#8b6c42", "#c87941", "#e8c77b"];
  for (let i = 0; i < 18; i++) {
    anim.confetti.push({
      x: 0.3 + Math.random() * 0.4,  // normalized 0-1 screen coords
      y: 0.2 + Math.random() * 0.3,
      vx: (Math.random() - 0.5) * 160,
      vy: -60 - Math.random() * 120,
      rot: Math.random() * Math.PI * 2,
      drot: (Math.random() - 0.5) * 8,
      w: 3 + Math.random() * 5,
      h: 3 + Math.random() * 5,
      color: palette[i % palette.length],
      alpha: 1.0,
    });
  }
}

function spawnKeySparkles(canvasX, canvasY) {
  for (let i = 0; i < 8; i++) {
    anim.keySparkles.push({
      x: canvasX + (Math.random() - 0.5) * 20,
      y: canvasY + (Math.random() - 0.5) * 20,
      alpha: 1.0,
      radius: 2 + Math.random() * 4,
    });
  }
}

function updateAnimations(deltaSec) {
  const rt = currentRuntime();
  if (!rt) return;
  const reducedMotion = profile.settings.reducedMotion;
  const speed = reducedMotion ? 999 : 14;
  const layerSpeed = reducedMotion ? 999 : 5.2;

  // Lerp player position
  anim.playerX = moveToward(anim.playerX, rt.player.x, deltaSec * speed);
  anim.playerY = moveToward(anim.playerY, rt.player.y, deltaSec * speed);
  anim.playerLayer = rt.player.layer;
  anim.displayedActiveLayer = moveToward(anim.displayedActiveLayer, rt.activeLayer, deltaSec * layerSpeed);

  // Room entry animation
  if (anim.enterProgress < 1) {
    anim.enterProgress = Math.min(1, anim.enterProgress + deltaSec * 3.6);
  }

  // Solve flash decay
  if (anim.solveFlash > 0) {
    anim.solveFlash = Math.max(0, anim.solveFlash - deltaSec * 1.9);
  }

  // Stamp ring expansion
  if (anim.stampRingAlpha > 0) {
    anim.stampRingRadius += deltaSec * 200;
    anim.stampRingAlpha = Math.max(0, anim.stampRingAlpha - deltaSec * 1.6);
  }

  // Screen shake decay
  if (anim.screenShake > 0) {
    anim.screenShake = Math.max(0, anim.screenShake - deltaSec * 18);
  }

  // Goal tile pulse cycle
  anim.goalPulse = (anim.goalPulse + deltaSec * 2.5) % (Math.PI * 2);

  // Confetti physics
  for (const p of anim.confetti) {
    p.x += (p.vx / 800) * deltaSec;
    p.y += (p.vy / 800) * deltaSec;
    p.vy += 110 * deltaSec;
    p.rot += p.drot * deltaSec;
    p.alpha = Math.max(0, p.alpha - deltaSec * 1.2);
  }
  anim.confetti = anim.confetti.filter(p => p.alpha > 0.01);

  // Key sparkle decay
  for (const s of anim.keySparkles) {
    s.alpha = Math.max(0, s.alpha - deltaSec * 3);
    s.radius += deltaSec * 8;
  }
  anim.keySparkles = anim.keySparkles.filter(s => s.alpha > 0.01);
}

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
  settingAudio: document.getElementById("setting-audio"),
  settingVolume: document.getElementById("setting-volume"),
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
  // Tutorial overlay
  tutorialOverlay: document.getElementById("tutorial-overlay"),
  tutorialPrev: document.getElementById("tutorial-prev"),
  tutorialNext: document.getElementById("tutorial-next"),
  tutorialDots: document.getElementById("tutorial-dots"),
  // Intro overlay
  introOverlay: document.getElementById("intro-overlay"),
  introSpeaker: document.getElementById("intro-speaker"),
  introText: document.getElementById("intro-text"),
  introDismiss: document.getElementById("intro-dismiss"),
  // Legend
  hudLegend: document.getElementById("hud-legend"),
  legendOverlay: document.getElementById("legend-overlay"),
  legendClose: document.getElementById("legend-close"),
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
    audio.stopAmbient();
  }
  if (screen === "play") {
    el.solveOverlay.classList.add("hidden");
    state.hintOpen = false;
    el.hintOverlay.classList.add("hidden");
    updateHUD();
    audio.startAmbient();
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
  initAnimFromRuntime();
  audio.play("enter");
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
  // Solve effects already triggered in performAction
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
  // Snapshot entity/key state before dispatch for change detection
  const prevEntities = currentRuntime()?.entities?.map(e => `${e.x}:${e.y}`) || [];
  const prevKeys = currentRuntime()?.collectedKeys?.length || 0;

  const changed = engine.dispatch(action);
  if (!changed) return;

  // Determine audio event
  const rt = currentRuntime();
  const newEntities = rt?.entities?.map(e => `${e.x}:${e.y}`) || [];
  const entityMoved = prevEntities.some((pos, i) => newEntities[i] !== pos);
  const keyCollected = (rt?.collectedKeys?.length || 0) > prevKeys;

  if (rt?.solved) {
    audio.play("solve");
    triggerSolveEffects();
  } else if (entityMoved && action.type === "move") {
    audio.play("push");
  } else if (action.type === "switch_layer") {
    audio.play("switch_layer");
  } else if (action.type === "transfer") {
    audio.play("transfer");
  } else if (action.type === "wait") {
    audio.play("wait");
  } else if (action.type === "undo") {
    audio.play("undo");
  } else if (action.type === "redo") {
    audio.play("redo");
  } else if (action.type === "reset") {
    audio.play("reset");
    initAnimFromRuntime();
  } else if (action.type === "move") {
    audio.play("move");
  }

  if (keyCollected) {
    spawnKeySparkles(0, 0); // position updated at render time
  }

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
      showRoomIntro();
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
  el.settingAudio.checked = profile.settings.audioEnabled !== false;
  el.settingVolume.value = String(profile.settings.audioVolume ?? 0.6);
  document.documentElement.style.fontSize = `${(profile.settings.fontScale || 1) * 16}px`;
  document.body.classList.toggle("high-contrast", !!profile.settings.highContrast);
  audio.setEnabled(profile.settings.audioEnabled !== false);
  audio.setVolume(profile.settings.audioVolume ?? 0.6);
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
  // Show objective with contextual mechanic tip
  if (runtime.solved) {
    el.hudObjective.textContent = "Route restored!";
  } else {
    let tip = room.objective;
    // Add contextual tips based on room entities and tiles
    const entities = runtime.entities || [];
    const hasParcel = entities.some(e => e.type === "parcel");
    const hasProjector = entities.some(e => e.type === "projector");
    const hasSwitches = (room.switches || []).length > 0;
    const hasDoors = (room.doors || []).length > 0;
    const layerCount = room.layers?.length || 1;
    const hints = [];
    if (hasParcel && hasSwitches) hints.push("Push parcels onto green switches to open doors.");
    else if (hasParcel) hints.push("Push parcels by walking into them.");
    if (hasProjector) hints.push("Projectors create bridges on other layers.");
    if (layerCount > 1 && !tip.toLowerCase().includes("layer")) hints.push("Press Tab to switch layers at stitch markers (⬡).");
    tip += hints.length > 0 ? (" · " + hints[0]) : "";
    el.hudObjective.textContent = tip;
  }
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
  } else {
    // Subtle border for inactive layers
    ctx.save();
    ctx.strokeStyle = "rgba(109, 78, 47, 0.12)";
    ctx.lineWidth = 1;
    drawRoundedRect(cardX + 1, cardY + 1, cardW - 2, cardH - 2, 27);
    ctx.stroke();
    ctx.restore();
  }

  // Layer name with layer number indicator
  ctx.fillStyle = active ? "#5d301f" : "#7d6853";
  ctx.font = active ? "700 20px Georgia" : "600 16px Georgia";
  ctx.fillText(layer.name, boardX - 2, boardY - 16);
  if (active) {
    // Small active dot next to name
    ctx.fillStyle = "#d39b34";
    const nameW = ctx.measureText(layer.name).width;
    ctx.beginPath();
    ctx.arc(boardX + nameW + 8, boardY - 22, 4, 0, Math.PI * 2);
    ctx.fill();
  }

  // Tiles
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const tile = layer.tiles[y][x];
      const sx = boardX + x * tileSize;
      const sy = boardY + y * tileSize;

      // Tile base with subtle rounded corners
      ctx.fillStyle = tileColor(tile);
      const tGap = 1;
      const tRad = Math.max(2, tileSize * 0.06);
      ctx.beginPath();
      ctx.moveTo(sx + tRad, sy);
      ctx.arcTo(sx + tileSize - tGap, sy, sx + tileSize - tGap, sy + tileSize - tGap, tRad);
      ctx.arcTo(sx + tileSize - tGap, sy + tileSize - tGap, sx, sy + tileSize - tGap, tRad);
      ctx.arcTo(sx, sy + tileSize - tGap, sx, sy, tRad);
      ctx.arcTo(sx, sy, sx + tileSize - tGap, sy, tRad);
      ctx.closePath();
      ctx.fill();

      // Subtle inner highlight on floor tiles
      if (tile === "." || tile === "S" || tile === "G") {
        ctx.fillStyle = "rgba(255, 255, 255, 0.3)";
        ctx.fillRect(sx + 1, sy + 1, tileSize - 3, 2);
      }

      if (tile === "#") {
        ctx.fillStyle = "#8d6a45";
        const wInset = Math.max(4, tileSize * 0.1);
        ctx.beginPath();
        ctx.moveTo(sx + wInset + 2, sy + wInset);
        ctx.arcTo(sx + tileSize - wInset - tGap, sy + wInset, sx + tileSize - wInset - tGap, sy + tileSize - wInset - tGap, 2);
        ctx.arcTo(sx + tileSize - wInset - tGap, sy + tileSize - wInset - tGap, sx + wInset, sy + tileSize - wInset - tGap, 2);
        ctx.arcTo(sx + wInset, sy + tileSize - wInset - tGap, sx + wInset, sy + wInset, 2);
        ctx.arcTo(sx + wInset, sy + wInset, sx + tileSize - wInset - tGap, sy + wInset, 2);
        ctx.closePath();
        ctx.fill();
        // Wall highlight
        ctx.fillStyle = "rgba(255, 255, 255, 0.08)";
        ctx.fillRect(sx + wInset, sy + wInset, tileSize - wInset * 2 - tGap, 2);
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
        // Pulsing glow around goal
        const pulse = 0.2 + 0.15 * Math.sin(anim.goalPulse);
        ctx.fillStyle = `rgba(211, 155, 52, ${pulse})`;
        ctx.beginPath();
        ctx.arc(sx + tileSize / 2, sy + tileSize / 2, tileSize * 0.52, 0, Math.PI * 2);
        ctx.fill();
        // Mailbox body
        ctx.fillStyle = "#d39b34";
        ctx.fillRect(sx + tileSize * 0.2, sy + tileSize * 0.28, tileSize * 0.6, tileSize * 0.48);
        // Mailbox flag/top
        ctx.fillStyle = "#7d3f29";
        ctx.fillRect(sx + tileSize * 0.28, sy + tileSize * 0.12, tileSize * 0.44, tileSize * 0.2);
        // Slot
        ctx.fillStyle = "rgba(255, 243, 231, 0.7)";
        ctx.fillRect(sx + tileSize * 0.35, sy + tileSize * 0.46, tileSize * 0.3, tileSize * 0.06);
        // "GOAL" label below if tile is large enough
        if (tileSize >= 42) {
          ctx.fillStyle = "rgba(211, 155, 52, 0.85)";
          ctx.font = `700 ${Math.max(8, Math.floor(tileSize * 0.17))}px sans-serif`;
          ctx.textAlign = "center";
          ctx.fillText("GOAL", sx + tileSize / 2, sy + tileSize - 2);
          ctx.textAlign = "left";
        }
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
    const isActive = runtime.dynamicState.activeSwitches.has(switchDef.id);
    // More prominent pressure plate
    ctx.fillStyle = isActive ? "#6a9e50" : "#a8c893";
    drawRoundedRect(sx + 5, sy + tileSize * 0.6, tileSize - 12, tileSize * 0.3, 3);
    ctx.fill();
    ctx.strokeStyle = isActive ? "#4a7a30" : "#7d9e68";
    ctx.lineWidth = 1.5;
    drawRoundedRect(sx + 5, sy + tileSize * 0.6, tileSize - 12, tileSize * 0.3, 3);
    ctx.stroke();
    ctx.lineWidth = 1;
  }

  // Doors
  for (const door of room.doors || []) {
    if (door.layer !== layerIndex) continue;
    const sx = boardX + door.x * tileSize;
    const sy = boardY + door.y * tileSize;
    const open = runtime.dynamicState.openDoors.has(door.id);
    if (!open) {
      // Closed door: solid with knob
      ctx.fillStyle = "#7d3f29";
      drawRoundedRect(sx + 5, sy + 2, tileSize - 12, tileSize - 4, 3);
      ctx.fill();
      // Door panel detail
      ctx.strokeStyle = "rgba(255, 240, 210, 0.25)";
      ctx.lineWidth = 1;
      ctx.strokeRect(sx + 9, sy + 6, tileSize - 20, (tileSize - 12) * 0.4);
      ctx.strokeRect(sx + 9, sy + 6 + (tileSize - 12) * 0.5, tileSize - 20, (tileSize - 12) * 0.4);
      // Knob
      ctx.fillStyle = "#d39b34";
      ctx.beginPath();
      ctx.arc(sx + tileSize - 12, sy + tileSize / 2, 2.5, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.strokeStyle = "rgba(125, 63, 41, 0.35)";
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 3]);
      drawRoundedRect(sx + 7, sy + 4, tileSize - 16, tileSize - 8, 3);
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  // Entities
  for (const entity of runtime.entities) {
    if (entity.layer !== layerIndex) continue;
    const ex = boardX + entity.x * tileSize;
    const ey = boardY + entity.y * tileSize;
    const ecx = ex + tileSize / 2;
    const ecy = ey + tileSize / 2;

    if (entity.type === "parcel") {
      const pi = Math.max(6, tileSize * 0.14);
      // Shadow
      ctx.fillStyle = "rgba(120, 60, 30, 0.12)";
      ctx.beginPath();
      ctx.ellipse(ecx, ey + tileSize - pi + 2, tileSize * 0.3, tileSize * 0.08, 0, 0, Math.PI * 2);
      ctx.fill();
      // Outer box
      ctx.fillStyle = "#bf5f3c";
      drawRoundedRect(ex + pi, ey + pi, tileSize - pi * 2 - 1, tileSize - pi * 2 - 1, 4);
      ctx.fill();
      // Inner label area
      ctx.fillStyle = "#fff3e7";
      const li = pi + Math.max(5, tileSize * 0.08);
      drawRoundedRect(ex + li, ey + li, tileSize - li * 2 - 1, tileSize - li * 2 - 1, 2);
      ctx.fill();
      // Cross string
      ctx.strokeStyle = "rgba(191, 95, 60, 0.4)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(ex + pi, ecy); ctx.lineTo(ex + tileSize - pi - 1, ecy);
      ctx.moveTo(ecx, ey + pi); ctx.lineTo(ecx, ey + tileSize - pi - 1);
      ctx.stroke();
    } else if (entity.type === "projector") {
      // Glow
      ctx.fillStyle = "rgba(211, 155, 52, 0.15)";
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.4, 0, Math.PI * 2);
      ctx.fill();
      // Lens body
      ctx.fillStyle = "#d39b34";
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.26, 0, Math.PI * 2);
      ctx.fill();
      // Lens highlight
      ctx.fillStyle = "rgba(255, 240, 200, 0.45)";
      ctx.beginPath();
      ctx.arc(ecx - tileSize * 0.06, ecy - tileSize * 0.08, tileSize * 0.13, 0, Math.PI * 2);
      ctx.fill();
      // Housing
      ctx.strokeStyle = "#7d3f29";
      ctx.lineWidth = 1.5;
      drawRoundedRect(ex + tileSize * 0.2, ey + tileSize * 0.2, tileSize * 0.6, tileSize * 0.6, 4);
      ctx.stroke();
      ctx.lineWidth = 1;
    } else if (entity.type === "echo") {
      // Trailing ghost
      ctx.fillStyle = "rgba(105, 150, 211, 0.2)";
      ctx.beginPath();
      ctx.arc(ecx - 3, ecy, tileSize * 0.3, 0, Math.PI * 2);
      ctx.fill();
      // Main body
      ctx.fillStyle = "rgba(105, 150, 211, 0.78)";
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.28, 0, Math.PI * 2);
      ctx.fill();
      // Highlight
      ctx.fillStyle = "rgba(200, 220, 255, 0.4)";
      ctx.beginPath();
      ctx.arc(ecx - tileSize * 0.06, ecy - tileSize * 0.08, tileSize * 0.12, 0, Math.PI * 2);
      ctx.fill();
      // Ripple rings
      ctx.strokeStyle = "rgba(105, 150, 211, 0.25)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.38, 0, Math.PI * 2);
      ctx.stroke();
    } else if (entity.type === "shadow") {
      // Dark aura
      ctx.fillStyle = "rgba(40, 30, 20, 0.1)";
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.38, 0, Math.PI * 2);
      ctx.fill();
      // Main body
      ctx.fillStyle = "rgba(59, 44, 36, 0.78)";
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.3, 0, Math.PI * 2);
      ctx.fill();
      // Inner dark
      ctx.fillStyle = "rgba(30, 20, 15, 0.3)";
      ctx.beginPath();
      ctx.arc(ecx + tileSize * 0.04, ecy + tileSize * 0.04, tileSize * 0.16, 0, Math.PI * 2);
      ctx.fill();
    } else if (entity.type === "key") {
      const kc = KEY_LOCK_COLORS[entity.color] || KEY_LOCK_COLORS.red;
      // Sparkle glow
      ctx.fillStyle = kc.light;
      ctx.globalAlpha = 0.2;
      ctx.beginPath();
      ctx.arc(ecx, ecy, tileSize * 0.35, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
      // Key head
      ctx.fillStyle = kc.fill;
      ctx.beginPath();
      ctx.arc(ecx, ey + tileSize * 0.35, tileSize * 0.16, 0, Math.PI * 2);
      ctx.fill();
      // Key hole
      ctx.fillStyle = tileColor(".");
      ctx.beginPath();
      ctx.arc(ecx, ey + tileSize * 0.35, tileSize * 0.06, 0, Math.PI * 2);
      ctx.fill();
      // Key shaft
      ctx.fillStyle = kc.fill;
      ctx.fillRect(ecx - tileSize * 0.04, ey + tileSize * 0.48, tileSize * 0.08, tileSize * 0.28);
      // Key teeth
      ctx.fillRect(ecx, ey + tileSize * 0.6, tileSize * 0.1, tileSize * 0.04);
      ctx.fillRect(ecx, ey + tileSize * 0.68, tileSize * 0.08, tileSize * 0.04);
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
      const lcx = lx + tileSize / 2;
      const lcy = ly + tileSize / 2;
      ctx.fillStyle = lc.fill;
      ctx.globalAlpha = 0.7;
      drawRoundedRect(lx + 4, ly + 4, tileSize - 10, tileSize - 10, 4);
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.strokeStyle = lc.fill;
      ctx.lineWidth = 2;
      drawRoundedRect(lx + 4, ly + 4, tileSize - 10, tileSize - 10, 4);
      ctx.stroke();
      ctx.lineWidth = 1;
      // Drawn lock icon
      ctx.fillStyle = "#fff";
      // Lock body
      const lbw = tileSize * 0.3;
      const lbh = tileSize * 0.22;
      drawRoundedRect(lcx - lbw / 2, lcy, lbw, lbh, 2);
      ctx.fill();
      // Lock shackle
      ctx.strokeStyle = "#fff";
      ctx.lineWidth = tileSize * 0.05;
      ctx.beginPath();
      ctx.arc(lcx, lcy, tileSize * 0.12, Math.PI, 0);
      ctx.stroke();
      ctx.lineWidth = 1;
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
    const px = boardX + (anim.initialized ? anim.playerX : runtime.player.x) * tileSize;
    const py = boardY + (anim.initialized ? anim.playerY : runtime.player.y) * tileSize;
    const pcx = px + tileSize / 2;
    const pcy = py + tileSize / 2;
    const pr = tileSize * 0.32;

    // Body shadow
    ctx.fillStyle = "rgba(30, 40, 60, 0.15)";
    ctx.beginPath();
    ctx.ellipse(pcx, pcy + pr + 2, pr * 0.85, pr * 0.3, 0, 0, Math.PI * 2);
    ctx.fill();

    // Body
    ctx.fillStyle = "#2f4d6a";
    ctx.beginPath();
    ctx.arc(pcx, pcy, pr, 0, Math.PI * 2);
    ctx.fill();

    // Body highlight
    ctx.fillStyle = "rgba(158, 186, 212, 0.35)";
    ctx.beginPath();
    ctx.arc(pcx - pr * 0.15, pcy - pr * 0.2, pr * 0.55, 0, Math.PI * 2);
    ctx.fill();

    // Face
    const fw = tileSize * 0.2;
    const fh = tileSize * 0.18;
    const fx = pcx - fw / 2;
    const fy = pcy - pr * 0.5;
    ctx.fillStyle = "#f9dcb2";
    ctx.beginPath();
    ctx.moveTo(fx + 2, fy);
    ctx.arcTo(fx + fw, fy, fx + fw, fy + fh, 2);
    ctx.arcTo(fx + fw, fy + fh, fx, fy + fh, 2);
    ctx.arcTo(fx, fy + fh, fx, fy, 2);
    ctx.arcTo(fx, fy, fx + fw, fy, 2);
    ctx.closePath();
    ctx.fill();

    // Eyes
    ctx.fillStyle = "#32261a";
    const eyeY = fy + fh * 0.45;
    const eyeGap = fw * 0.28;
    ctx.beginPath();
    ctx.arc(pcx - eyeGap, eyeY, tileSize * 0.025, 0, Math.PI * 2);
    ctx.arc(pcx + eyeGap, eyeY, tileSize * 0.025, 0, Math.PI * 2);
    ctx.fill();

    // Direction indicator
    const facing = runtime.player.facing;
    const dirs = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
    const [fdx, fdy] = dirs[facing] || [0, -1];
    ctx.fillStyle = "rgba(211, 155, 52, 0.7)";
    ctx.beginPath();
    ctx.arc(pcx + fdx * (pr + 3), pcy + fdy * (pr + 3), tileSize * 0.05, 0, Math.PI * 2);
    ctx.fill();
  }

  // Floating labels on active layer for key entities (helps players understand mechanics)
  if (active && tileSize >= 38) {
    const labelFont = `600 ${Math.max(8, Math.floor(tileSize * 0.18))}px sans-serif`;
    ctx.font = labelFont;
    ctx.textAlign = "center";

    const drawEntityLabel = (cx, topY, text, color) => {
      const tw = ctx.measureText(text).width;
      const lx = cx - tw / 2 - 4;
      const ly = topY - 14;
      ctx.fillStyle = "rgba(255, 252, 244, 0.88)";
      drawRoundedRect(lx, ly, tw + 8, 14, 4);
      ctx.fill();
      ctx.fillStyle = color;
      ctx.fillText(text, cx, topY - 3);
    };

    for (const entity of runtime.entities) {
      if (entity.layer !== layerIndex) continue;
      const ex = boardX + entity.x * tileSize;
      const ey = boardY + entity.y * tileSize;
      const ecx = ex + tileSize / 2;
      if (entity.type === "parcel") drawEntityLabel(ecx, ey, "PARCEL", "#bf5f3c");
      else if (entity.type === "projector") drawEntityLabel(ecx, ey, "PROJECTOR", "#b8862d");
      else if (entity.type === "echo") drawEntityLabel(ecx, ey, "ECHO", "#4a7db5");
      else if (entity.type === "shadow") drawEntityLabel(ecx, ey, "SHADOW", "#4a3528");
      else if (entity.type === "key") drawEntityLabel(ecx, ey, "KEY", (KEY_LOCK_COLORS[entity.color] || KEY_LOCK_COLORS.red).fill);
    }

    ctx.textAlign = "left";
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
  // Screen shake offset
  const shakeX = anim.screenShake > 0.1 ? (Math.random() - 0.5) * anim.screenShake : 0;
  const shakeY = anim.screenShake > 0.1 ? (Math.random() - 0.5) * anim.screenShake : 0;
  ctx.setTransform(scale, 0, 0, scale, shakeX * scale, shakeY * scale);
  ctx.clearRect(-10, -10, rect.width + 20, rect.height + 20);
  state.boardLayout = [];

  // Background — warm craft-paper gradient
  const bgGrad = ctx.createLinearGradient(0, 0, rect.width, rect.height);
  bgGrad.addColorStop(0, "#efe3c5");
  bgGrad.addColorStop(0.5, "#e7d9b5");
  bgGrad.addColorStop(1, "#ddd0a8");
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, rect.width, rect.height);

  // Subtle craft-paper texture dots
  ctx.fillStyle = "rgba(255, 255, 255, 0.12)";
  for (let i = 0; i < 18; i++) {
    const bx = (i * 97 + 40) % (rect.width + 60);
    const by = (i * 53 + 30) % (rect.height + 40);
    ctx.beginPath();
    ctx.arc(bx, by, 16 + (i % 5) * 6, 0, Math.PI * 2);
    ctx.fill();
  }

  // Decorative stitch-line running across top
  ctx.save();
  ctx.strokeStyle = "rgba(125, 63, 41, 0.08)";
  ctx.lineWidth = 1;
  ctx.setLineDash([8, 6]);
  ctx.beginPath();
  ctx.moveTo(0, 28);
  ctx.lineTo(rect.width, 28);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.restore();

  if (!room || !runtime) {
    ctx.fillStyle = "#5d301f";
    ctx.font = "700 34px Georgia";
    ctx.fillText("Patchwork Post", 72, 108);
    return;
  }

  const w = room.layers[0].tiles[0].length;
  const h = room.layers[0].tiles.length;
  const layerCount = room.layers.length;

  // Calculate tile size: fit ONE layer comfortably, then scroll if needed
  const availW = rect.width - 80;
  const availH = rect.height - 100;
  // Try to fit all layers first
  const maxTileAllLayers = Math.floor(availW / (w * layerCount + (layerCount - 1) * 1.2));
  const maxTileSingleLayer = Math.floor(availW / (w + 2));
  const maxTileByHeight = Math.floor((availH - 60) / h);
  // Use the all-layers size if it's reasonable (>= 36px), otherwise size for one layer and scroll
  const allFit = Math.min(maxTileAllLayers, maxTileByHeight) >= 36;
  const tileSize = allFit
    ? Math.min(78, Math.max(36, Math.min(maxTileAllLayers, maxTileByHeight)))
    : Math.min(78, Math.max(36, Math.min(maxTileSingleLayer, maxTileByHeight)));

  const layerGap = 48;
  const totalBoardWidth = layerCount * (w * tileSize + layerGap) - layerGap;
  const totalBoardHeight = h * tileSize + 60;
  const needsScroll = totalBoardWidth > rect.width - 40;

  // Camera: smoothly center the active layer in the viewport
  let cameraOffset = 0;
  if (needsScroll) {
    const activeIdx = anim.initialized ? anim.displayedActiveLayer : runtime.activeLayer;
    const layerCenterX = activeIdx * (w * tileSize + layerGap) + (w * tileSize) / 2;
    const targetCamera = layerCenterX - rect.width / 2;
    const maxCamera = totalBoardWidth - rect.width + 60;
    const clampedTarget = Math.max(-30, Math.min(maxCamera, targetCamera));
    // Smooth lerp for camera
    if (!anim.initialized || anim.cameraX === 0) {
      anim.cameraX = clampedTarget;
    } else {
      const cameraSpeed = profile.settings.reducedMotion ? 999 : 8;
      anim.cameraX = moveToward(anim.cameraX, clampedTarget, Math.abs(clampedTarget - anim.cameraX) * Math.min(1, cameraSpeed * (1 / 60)));
    }
    cameraOffset = -anim.cameraX;
  }

  const startX = needsScroll ? 30 + cameraOffset : Math.max(40, (rect.width - totalBoardWidth) / 2);
  const startY = Math.max(50, (rect.height - totalBoardHeight) / 2);

  room.layers.forEach((_, index) => {
    const boardX = startX + index * (w * tileSize + layerGap);
    // Smooth layer elevation: active layer rises, others descend
    const activeDist = Math.abs(index - (anim.initialized ? anim.displayedActiveLayer : runtime.activeLayer));
    const layerOffset = Math.min(1, activeDist) * 22;
    // Entry animation: layers slide down from top
    const entrySlide = anim.initialized ? (1 - anim.enterProgress) * (50 + index * 20) : 0;
    const boardY = startY + layerOffset + entrySlide;
    drawLayerBoard(index, boardX, boardY, tileSize);
  });

  // Replay indicator
  if (engine.replayState) {
    ctx.save();
    const rw = 200;
    const rx = (rect.width - rw) / 2;
    ctx.fillStyle = "rgba(255, 248, 228, 0.92)";
    ctx.shadowColor = "rgba(74, 43, 17, 0.12)";
    ctx.shadowBlur = 10;
    ctx.shadowOffsetY = 4;
    drawRoundedRect(rx, 12, rw, 38, 16);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.shadowOffsetY = 0;
    ctx.strokeStyle = "rgba(211, 155, 52, 0.4)";
    ctx.lineWidth = 1;
    drawRoundedRect(rx, 12, rw, 38, 16);
    ctx.stroke();
    // Progress bar
    const prog = engine.replayState.index / Math.max(1, engine.replayState.actions.length);
    ctx.fillStyle = "rgba(211, 155, 52, 0.25)";
    drawRoundedRect(rx + 4, 42, (rw - 8) * prog, 4, 2);
    ctx.fill();
    ctx.fillStyle = "#5d301f";
    ctx.font = "600 13px Trebuchet MS";
    ctx.textAlign = "center";
    ctx.fillText(`Replaying... ${engine.replayState.index}/${engine.replayState.actions.length}`, rect.width / 2, 36);
    ctx.textAlign = "left";
    ctx.restore();
  }

  // Keyboard shortcuts at bottom — only shown when not in replay
  if (!runtime.solved && !engine.replayState) {
    ctx.save();
    ctx.font = "11px Trebuchet MS";
    ctx.fillStyle = "rgba(125, 104, 83, 0.35)";
    ctx.textAlign = "center";
    ctx.fillText("\u2190\u2191\u2192\u2193 Move  \u00B7  Tab: Layer  \u00B7  X: Transfer  \u00B7  Z/Y: Undo/Redo  \u00B7  R: Reset  \u00B7  ?: Legend", rect.width / 2, rect.height - 8);
    ctx.textAlign = "left";
    ctx.restore();
  }

  // ── Contextual "how to play" banner for first 6 moves ──
  if (!runtime.solved && !engine.replayState && runtime.moveCount < 6) {
    const entities = runtime.entities || [];
    const hasParcel = entities.some(e => e.type === "parcel");
    const hasProjector = entities.some(e => e.type === "projector");
    const hasSwitches = (room.switches || []).length > 0;
    const hasGoal = room.layers.some(l => l.tiles.some(row => row.includes("G")));
    const lines = [];
    if (hasGoal) lines.push("🏁 Reach the GOAL mailbox to complete this room");
    if (hasParcel && hasSwitches) lines.push("📦 Push PARCELS onto green SWITCHES to open doors");
    else if (hasParcel) lines.push("📦 Push PARCELS by walking into them");
    if (hasProjector) lines.push("🔦 PROJECTORS create bridges on other layers when on a stitch");
    if (layerCount > 1) lines.push("⬡ Stand on a STITCH MARKER and press Tab to switch layers");
    if (lines.length > 0) {
      const bannerAlpha = Math.max(0, 1 - runtime.moveCount * 0.2);
      const bannerW = Math.min(rect.width - 40, 480);
      const bannerH = 18 + lines.length * 18;
      const bannerX = (rect.width - bannerW) / 2;
      const bannerY = 42;
      ctx.save();
      ctx.globalAlpha = bannerAlpha * 0.92;
      ctx.fillStyle = "rgba(255, 252, 240, 0.95)";
      ctx.shadowColor = "rgba(74, 43, 17, 0.12)";
      ctx.shadowBlur = 8;
      ctx.shadowOffsetY = 3;
      drawRoundedRect(bannerX, bannerY, bannerW, bannerH, 12);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.shadowOffsetY = 0;
      ctx.strokeStyle = "rgba(211, 155, 52, 0.35)";
      ctx.lineWidth = 1;
      drawRoundedRect(bannerX, bannerY, bannerW, bannerH, 12);
      ctx.stroke();
      ctx.fillStyle = "#5d301f";
      ctx.font = "600 12px Trebuchet MS, sans-serif";
      ctx.textAlign = "center";
      lines.forEach((line, i) => {
        ctx.fillText(line, rect.width / 2, bannerY + 16 + i * 18);
      });
      ctx.textAlign = "left";
      ctx.restore();
    }
  }

  // ── Visual effects overlay ──

  // Solve golden flash
  if (anim.solveFlash > 0.01) {
    ctx.save();
    ctx.fillStyle = `rgba(211, 155, 52, ${anim.solveFlash * 0.15})`;
    ctx.fillRect(0, 0, rect.width, rect.height);
    ctx.restore();
  }

  // Stamp ring
  if (anim.stampRingAlpha > 0.01) {
    ctx.save();
    ctx.strokeStyle = `rgba(211, 155, 52, ${anim.stampRingAlpha * 0.6})`;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(rect.width / 2, rect.height / 2, anim.stampRingRadius, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  // Confetti particles
  for (const p of anim.confetti) {
    ctx.save();
    ctx.globalAlpha = p.alpha;
    ctx.translate(p.x * rect.width, p.y * rect.height);
    ctx.rotate(p.rot);
    ctx.fillStyle = p.color;
    ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
    ctx.restore();
  }

  // Key collection sparkles
  for (const s of anim.keySparkles) {
    ctx.save();
    ctx.globalAlpha = s.alpha;
    ctx.fillStyle = "#ffd700";
    ctx.beginPath();
    ctx.arc(s.x, s.y, s.radius, 0, Math.PI * 2);
    ctx.fill();
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
  // Lazy-init audio on first user interaction (browser autoplay policy)
  audio.init();

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

  // Don't handle game input when overlays are showing
  if (!el.solveOverlay.classList.contains("hidden")) return;
  if (!el.tutorialOverlay.classList.contains("hidden")) return;
  if (!el.introOverlay.classList.contains("hidden")) return;
  if (!el.legendOverlay.classList.contains("hidden")) {
    if (event.code === "Escape") {
      state.legendOpen = false;
      el.legendOverlay.classList.add("hidden");
      event.preventDefault();
    }
    return;
  }

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
  audio.init();
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
    if (!profile.tutorialSeen) {
      openTutorial();
    } else {
      showRoomIntro();
    }
  });

  el.resumeBtn.addEventListener("click", () => {
    ensureRoomLoaded(profile.lastRoomId || "mailroom-01");
    syncEditorFromRoom();
    setScreen("play");
    showRoomIntro();
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
      audio.play("hint");
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
  el.settingAudio.addEventListener("change", () => {
    profile.settings.audioEnabled = el.settingAudio.checked;
    audio.setEnabled(el.settingAudio.checked);
    saveProfile(profile);
  });
  el.settingVolume.addEventListener("input", () => {
    profile.settings.audioVolume = Number(el.settingVolume.value);
    audio.setVolume(Number(el.settingVolume.value));
    saveProfile(profile);
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

  // Tutorial
  el.tutorialNext.addEventListener("click", () => {
    if (state.tutorialStep >= state.tutorialTotal - 1) {
      closeTutorial();
    } else {
      showTutorialStep(state.tutorialStep + 1);
    }
  });
  el.tutorialPrev.addEventListener("click", () => {
    showTutorialStep(state.tutorialStep - 1);
  });

  // Intro dialogue
  el.introDismiss.addEventListener("click", dismissIntro);

  // Legend
  el.hudLegend.addEventListener("click", () => {
    state.legendOpen = !state.legendOpen;
    el.legendOverlay.classList.toggle("hidden", !state.legendOpen);
    if (state.legendOpen) renderAllTilePreviews();
  });
  el.legendClose.addEventListener("click", () => {
    state.legendOpen = false;
    el.legendOverlay.classList.add("hidden");
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
  const deltaSec = Math.min(delta / 1000, 0.1); // cap to avoid huge jumps

  if (state.screen === "play") {
    engine.update(profile.settings.reducedMotion ? Math.max(delta, 260) : delta);
    pollGamepad();
    updateAnimations(deltaSec);
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
// Tutorial / Onboarding
// ═══════════════════════════════════════

function drawTilePreview(canvas, tileType) {
  const size = canvas.width;
  const c = canvas.getContext("2d");
  c.clearRect(0, 0, size, size);

  if (tileType === "player") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#2f4d6a";
    c.beginPath();
    c.arc(size / 2, size / 2, size * 0.3, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = "#f9dcb2";
    c.fillRect(size * 0.4, size * 0.22, size * 0.18, size * 0.18);
  } else if (tileType === "parcel") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#bf5f3c";
    c.fillRect(size * 0.16, size * 0.16, size * 0.68, size * 0.68);
    c.fillStyle = "#fff3e7";
    c.fillRect(size * 0.3, size * 0.3, size * 0.4, size * 0.4);
  } else if (tileType === "projector") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#d39b34";
    c.beginPath();
    c.arc(size / 2, size / 2, size * 0.28, 0, Math.PI * 2);
    c.fill();
    c.strokeStyle = "#7d3f29";
    c.strokeRect(size * 0.22, size * 0.22, size * 0.56, size * 0.56);
  } else if (tileType === "echo") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "rgba(105, 150, 211, 0.78)";
    c.beginPath();
    c.arc(size / 2, size / 2, size * 0.28, 0, Math.PI * 2);
    c.fill();
  } else if (tileType === "shadow") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "rgba(59, 44, 36, 0.78)";
    c.beginPath();
    c.arc(size / 2, size / 2, size * 0.3, 0, Math.PI * 2);
    c.fill();
  } else if (tileType === "switch") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#b9d3a9";
    c.fillRect(size * 0.15, size * 0.6, size * 0.7, size * 0.2);
  } else if (tileType === "door") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#7d3f29";
    c.fillRect(size * 0.15, size * 0.06, size * 0.7, size * 0.88);
  } else if (tileType === "key") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#e04040";
    c.beginPath();
    c.arc(size / 2, size * 0.38, size * 0.18, 0, Math.PI * 2);
    c.fill();
    c.fillRect(size * 0.44, size * 0.45, size * 0.12, size * 0.32);
  } else if (tileType === "lock") {
    c.fillStyle = "#fff8ed";
    c.fillRect(0, 0, size, size);
    c.fillStyle = "#e04040";
    c.globalAlpha = 0.7;
    c.fillRect(size * 0.1, size * 0.1, size * 0.8, size * 0.8);
    c.globalAlpha = 1;
    c.fillStyle = "#fff";
    c.font = `${Math.floor(size * 0.4)}px sans-serif`;
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.fillText("\u{1F512}", size / 2, size / 2);
    c.textAlign = "left";
    c.textBaseline = "alphabetic";
  } else {
    // Tile type from tile character
    const colors = {
      "#": "#ad8c63", "~": "#d7c5a2", S: "#f7efdd", G: "#f7e0a1",
      I: "#c8dff0", T: "#d8c4f0", ">": "#f0e4c8", ".": "#fff8ed",
    };
    c.fillStyle = colors[tileType] || "#fff8ed";
    c.fillRect(0, 0, size, size);
    if (tileType === "#") {
      c.fillStyle = "#8d6a45";
      c.fillRect(size * 0.12, size * 0.12, size * 0.76, size * 0.76);
    }
    if (tileType === "S") {
      c.strokeStyle = "#7d3f29";
      c.lineWidth = 1.5;
      c.setLineDash([3, 2]);
      c.strokeRect(size * 0.18, size * 0.18, size * 0.64, size * 0.64);
      c.setLineDash([]);
      c.fillStyle = "#7d3f29";
      const cx = size / 2, cy = size / 2, d = size * 0.1;
      c.beginPath();
      c.moveTo(cx, cy - d); c.lineTo(cx + d, cy); c.lineTo(cx, cy + d); c.lineTo(cx - d, cy);
      c.closePath(); c.fill();
    }
    if (tileType === "G") {
      c.fillStyle = "#d39b34";
      c.fillRect(size * 0.25, size * 0.3, size * 0.5, size * 0.45);
      c.fillStyle = "#7d3f29";
      c.fillRect(size * 0.35, size * 0.15, size * 0.3, size * 0.2);
    }
    if (tileType === "~") {
      c.strokeStyle = "#a98964";
      c.beginPath();
      c.moveTo(size * 0.18, size * 0.18); c.lineTo(size * 0.82, size * 0.82);
      c.moveTo(size * 0.82, size * 0.18); c.lineTo(size * 0.18, size * 0.82);
      c.stroke();
    }
    if (tileType === "I") {
      c.strokeStyle = "rgba(100, 160, 210, 0.45)";
      for (let i = 0; i < 3; i++) {
        const lx = size * 0.15 + i * size * 0.35;
        c.beginPath(); c.moveTo(lx, size * 0.15); c.lineTo(lx, size * 0.85); c.stroke();
      }
    }
    if (tileType === "T") {
      c.fillStyle = "rgba(150, 120, 200, 0.35)";
      c.beginPath(); c.arc(size / 2, size / 2, size * 0.3, 0, Math.PI * 2); c.fill();
      c.strokeStyle = "#7d5faa"; c.lineWidth = 2;
      c.beginPath(); c.arc(size / 2, size / 2, size * 0.3, 0, Math.PI * 2); c.stroke();
    }
    if (tileType === ">") {
      c.fillStyle = "rgba(109, 78, 47, 0.35)";
      c.font = `${Math.floor(size * 0.5)}px sans-serif`;
      c.textAlign = "center"; c.textBaseline = "middle";
      c.fillText("\u2192", size / 2, size / 2);
      c.textAlign = "left"; c.textBaseline = "alphabetic";
    }
  }
}

function renderAllTilePreviews() {
  document.querySelectorAll(".tutorial-tile-preview").forEach((canvas) => {
    drawTilePreview(canvas, canvas.dataset.tile);
  });
}

function showTutorialStep(step) {
  state.tutorialStep = Math.max(0, Math.min(step, state.tutorialTotal - 1));
  el.tutorialOverlay.querySelectorAll(".tutorial-step").forEach((el) => {
    el.classList.toggle("active", Number(el.dataset.step) === state.tutorialStep);
  });
  // Update dots
  el.tutorialDots.innerHTML = "";
  for (let i = 0; i < state.tutorialTotal; i++) {
    const dot = document.createElement("span");
    dot.className = `tutorial-dot${i === state.tutorialStep ? " active" : ""}`;
    el.tutorialDots.append(dot);
  }
  // Update buttons
  el.tutorialPrev.style.visibility = state.tutorialStep === 0 ? "hidden" : "visible";
  el.tutorialNext.textContent = state.tutorialStep === state.tutorialTotal - 1 ? "Start Playing!" : "Next \u2192";
}

function openTutorial() {
  el.tutorialOverlay.classList.remove("hidden");
  showTutorialStep(0);
  renderAllTilePreviews();
}

function closeTutorial() {
  el.tutorialOverlay.classList.add("hidden");
  profile.tutorialSeen = true;
  saveProfile(profile);
  // Show room intro if available
  showRoomIntro();
}

function showRoomIntro() {
  const room = currentRoom();
  if (!room?.intro?.length) return;
  const introKey = `intro_${room.id}`;
  if (profile[introKey]) return;
  const intro = room.intro[0];
  el.introSpeaker.textContent = intro.speaker || "";
  el.introText.textContent = intro.text || "";
  el.introOverlay.classList.remove("hidden");
}

function dismissIntro() {
  const room = currentRoom();
  if (room) {
    profile[`intro_${room.id}`] = true;
    saveProfile(profile);
  }
  el.introOverlay.classList.add("hidden");
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
