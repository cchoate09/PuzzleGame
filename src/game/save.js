export const STORAGE_KEY = "patchwork-post-save-v1";

export const DEFAULT_CONTROLS = {
  up: "ArrowUp",
  down: "ArrowDown",
  left: "ArrowLeft",
  right: "ArrowRight",
  wait: "Space",
  switch_layer: "Tab",
  transfer: "KeyX",
  undo: "KeyZ",
  redo: "KeyY",
  reset: "KeyR",
  replay: "KeyP",
};

export function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

export function createDefaultProfile() {
  return {
    version: 1,
    startedAt: new Date().toISOString(),
    lastRoomId: "mailroom-01",
    rooms: {},
    achievements: {},
    journalsUnlocked: [],
    settings: {
      highContrast: false,
      reducedMotion: false,
      fontScale: 1,
      controls: clone(DEFAULT_CONTROLS),
    },
  };
}

function hydrateRoomProgress(progress = {}) {
  return {
    solved: false,
    optional: false,
    hintsRevealed: 0,
    attempts: 0,
    bestMoves: null,
    bestSolution: [],
    lastSnapshot: null,
    completedAt: null,
    ...progress,
  };
}

export function hydrateProfile(raw) {
  const base = createDefaultProfile();
  if (!raw || typeof raw !== "object") {
    return base;
  }

  const profile = {
    ...base,
    ...raw,
    rooms: {},
    achievements: { ...base.achievements, ...(raw.achievements || {}) },
    journalsUnlocked: Array.isArray(raw.journalsUnlocked)
      ? [...new Set(raw.journalsUnlocked)]
      : [],
    settings: {
      ...base.settings,
      ...(raw.settings || {}),
      controls: {
        ...DEFAULT_CONTROLS,
        ...((raw.settings && raw.settings.controls) || {}),
      },
    },
  };

  for (const [roomId, roomProgress] of Object.entries(raw.rooms || {})) {
    profile.rooms[roomId] = hydrateRoomProgress(roomProgress);
  }

  return profile;
}

export function loadProfile() {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return hydrateProfile(raw ? JSON.parse(raw) : null);
  } catch (error) {
    return createDefaultProfile();
  }
}

export function saveProfile(profile) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(profile));
}

export function getRoomProgress(profile, roomId) {
  if (!profile.rooms[roomId]) {
    profile.rooms[roomId] = hydrateRoomProgress();
  }
  return profile.rooms[roomId];
}

export function setRoomSnapshot(profile, roomId, snapshot) {
  const progress = getRoomProgress(profile, roomId);
  progress.lastSnapshot = snapshot ? clone(snapshot) : null;
}

export function revealHint(profile, roomId, tier) {
  const progress = getRoomProgress(profile, roomId);
  progress.hintsRevealed = Math.max(progress.hintsRevealed || 0, tier);
  return progress.hintsRevealed;
}

export function completeRoom(profile, room, runtime) {
  const progress = getRoomProgress(profile, room.id);
  const moveCount = runtime.moveCount;
  progress.solved = true;
  progress.optional = !!room.optional;
  progress.completedAt = progress.completedAt || new Date().toISOString();
  progress.bestMoves = progress.bestMoves == null ? moveCount : Math.min(progress.bestMoves, moveCount);
  if (!progress.bestSolution.length || moveCount <= progress.bestMoves) {
    progress.bestSolution = clone(runtime.actionLog);
  }
  progress.lastSnapshot = null;
  profile.lastRoomId = room.id;
  return progress;
}

export function unlockJournal(profile, districtId) {
  if (!profile.journalsUnlocked.includes(districtId)) {
    profile.journalsUnlocked.push(districtId);
  }
}

export function unlockAchievement(profile, achievementId) {
  if (!achievementId) {
    return false;
  }
  if (profile.achievements[achievementId]) {
    return false;
  }
  profile.achievements[achievementId] = new Date().toISOString();
  return true;
}

export function getPostmarkCount(profile, campaign) {
  return campaign.rooms.reduce((count, room) => {
    const progress = profile.rooms[room.id];
    return progress?.solved ? count + (room.postmarks || 0) : count;
  }, 0);
}

export function getSolvedCount(profile) {
  return Object.values(profile.rooms).filter((room) => room.solved).length;
}
