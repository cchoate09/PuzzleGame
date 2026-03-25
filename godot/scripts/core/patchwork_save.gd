class_name PatchworkSave
extends RefCounted

const InputBindings = preload("res://scripts/core/patchwork_input.gd")

const PROFILE_VERSION := 4
const LEGACY_STORAGE_PATH := "user://patchwork-post-save-v1.json"
const FULL_STORAGE_PATH := "user://profiles/full/patchwork-post-save-v2.json"
const DEMO_STORAGE_PATH := "user://profiles/demo/patchwork-post-save-v2.json"
const DEMO_CARRYOVER_PATH := "user://profiles/shared/patchwork-post-demo-carryover.json"
const STORAGE_PATH := FULL_STORAGE_PATH
const BUILD_CHANNEL := "full"
const CONTENT_VERSION := "batch-6"

static func clone(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true, false)

static func create_default_profile() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"startedAt": _now_iso(),
		"contentVersion": CONTENT_VERSION,
		"buildChannel": BUILD_CHANNEL,
		"demoCarryoverImportedAt": null,
		"lastRoomId": "mailroom-01",
		"rooms": {},
		"achievements": {},
		"journalsUnlocked": [],
		"journalEntriesUnlocked": [],
		"steam": {
			"cloudSlot": "patchwork-post-profile",
			"pendingAchievements": [],
			"syncedAchievements": {},
		},
		"settings": {
			"highContrast": false,
			"reducedMotion": false,
			"colorblindMode": "none",
			"fontScale": 1.0,
			"masterVolume": 0.0,
			"sfxVolume": 0.0,
			"controls": InputBindings.create_default_controls(),
		},
	}

static func _hydrate_room_progress(progress: Dictionary = {}) -> Dictionary:
	return {
		"solved": progress.get("solved", false),
		"optional": progress.get("optional", false),
		"hintsRevealed": progress.get("hintsRevealed", 0),
		"attempts": progress.get("attempts", 0),
		"bestMoves": progress.get("bestMoves", null),
		"bestSolution": clone(progress.get("bestSolution", [])),
		"lastSnapshot": clone(progress.get("lastSnapshot", null)),
		"completedAt": progress.get("completedAt", null),
	}

static func hydrate_profile(raw: Variant) -> Dictionary:
	var base := create_default_profile()
	if not (raw is Dictionary):
		return base

	var raw_dict: Dictionary = raw
	var profile := {
		"version": raw_dict.get("version", base["version"]),
		"startedAt": raw_dict.get("startedAt", base["startedAt"]),
		"contentVersion": raw_dict.get("contentVersion", base["contentVersion"]),
		"buildChannel": raw_dict.get("buildChannel", base["buildChannel"]),
		"demoCarryoverImportedAt": raw_dict.get("demoCarryoverImportedAt", base["demoCarryoverImportedAt"]),
		"lastRoomId": raw_dict.get("lastRoomId", base["lastRoomId"]),
		"rooms": {},
		"achievements": clone(base["achievements"]),
		"journalsUnlocked": [],
		"journalEntriesUnlocked": [],
		"steam": {
			"cloudSlot": raw_dict.get("steam", {}).get("cloudSlot", base["steam"]["cloudSlot"]),
			"pendingAchievements": [],
			"syncedAchievements": {},
		},
		"settings": {
			"highContrast": false,
			"reducedMotion": false,
			"colorblindMode": "none",
			"fontScale": 1.0,
			"masterVolume": 0.0,
			"sfxVolume": 0.0,
			"controls": InputBindings.create_default_controls(),
		},
	}

	for achievement_id in raw_dict.get("achievements", {}).keys():
		profile["achievements"][achievement_id] = raw_dict["achievements"][achievement_id]

	for journal_id in raw_dict.get("journalsUnlocked", []):
		if not profile["journalsUnlocked"].has(journal_id):
			profile["journalsUnlocked"].append(journal_id)

	for entry_id in raw_dict.get("journalEntriesUnlocked", []):
		if not profile["journalEntriesUnlocked"].has(entry_id):
			profile["journalEntriesUnlocked"].append(entry_id)

	var raw_settings: Dictionary = raw_dict.get("settings", {})
	var settings: Dictionary = profile["settings"]
	settings["highContrast"] = raw_settings.get("highContrast", false)
	settings["reducedMotion"] = raw_settings.get("reducedMotion", false)
	settings["colorblindMode"] = String(raw_settings.get("colorblindMode", "none"))
	settings["fontScale"] = raw_settings.get("fontScale", 1.0)
	settings["masterVolume"] = float(raw_settings.get("masterVolume", 0.0))
	settings["sfxVolume"] = float(raw_settings.get("sfxVolume", 0.0))
	settings["controls"] = InputBindings.hydrate_controls(raw_settings.get("controls", {}))

	var raw_steam: Dictionary = raw_dict.get("steam", {})
	for achievement_id in raw_steam.get("pendingAchievements", []):
		if not profile["steam"]["pendingAchievements"].has(achievement_id):
			profile["steam"]["pendingAchievements"].append(achievement_id)
	for achievement_id in raw_steam.get("syncedAchievements", {}).keys():
		profile["steam"]["syncedAchievements"][achievement_id] = raw_steam["syncedAchievements"][achievement_id]

	for room_id in raw_dict.get("rooms", {}).keys():
		profile["rooms"][room_id] = _hydrate_room_progress(raw_dict["rooms"][room_id])

	return profile

static func _read_profile_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return hydrate_profile(parsed)

static func get_storage_path(channel: String = BUILD_CHANNEL) -> String:
	return DEMO_STORAGE_PATH if channel == "demo" else FULL_STORAGE_PATH

static func has_demo_carryover() -> bool:
	return FileAccess.file_exists(DEMO_CARRYOVER_PATH) or FileAccess.file_exists(DEMO_STORAGE_PATH)

static func build_demo_carryover(profile: Dictionary) -> Dictionary:
	var carryover := hydrate_profile(profile)
	carryover["buildChannel"] = "full"
	carryover["demoCarryoverImportedAt"] = _now_iso()
	carryover["contentVersion"] = CONTENT_VERSION
	return carryover

static func load_profile(channel: String = BUILD_CHANNEL) -> Dictionary:
	var storage_path := get_storage_path(channel)
	var profile := _read_profile_file(storage_path)
	if not profile.is_empty():
		return profile
	if channel == "full":
		var imported := _read_profile_file(DEMO_CARRYOVER_PATH)
		if imported.is_empty():
			imported = _read_profile_file(DEMO_STORAGE_PATH)
		if not imported.is_empty():
			var carryover := build_demo_carryover(imported)
			save_profile(carryover, channel)
			return carryover
	if FileAccess.file_exists(LEGACY_STORAGE_PATH):
		var legacy := _read_profile_file(LEGACY_STORAGE_PATH)
		if not legacy.is_empty():
			legacy["buildChannel"] = channel
			legacy["contentVersion"] = CONTENT_VERSION
			save_profile(legacy, channel)
			return legacy
	return create_default_profile()

static func save_profile(profile: Dictionary, channel: String = BUILD_CHANNEL) -> void:
	var target_path := get_storage_path(channel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path).get_base_dir())
	profile["version"] = PROFILE_VERSION
	profile["contentVersion"] = CONTENT_VERSION
	profile["buildChannel"] = channel
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save profile to %s" % target_path)
		return
	file.store_string(JSON.stringify(profile, "\t"))
	if channel == "demo":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEMO_CARRYOVER_PATH).get_base_dir())
		var carryover_file := FileAccess.open(DEMO_CARRYOVER_PATH, FileAccess.WRITE)
		if carryover_file != null:
			carryover_file.store_string(JSON.stringify(build_demo_carryover(profile), "\t"))

static func get_room_progress(profile: Dictionary, room_id: String) -> Dictionary:
	var rooms: Dictionary = profile.get("rooms", {})
	if not rooms.has(room_id):
		rooms[room_id] = _hydrate_room_progress()
	return rooms[room_id]

static func set_room_snapshot(profile: Dictionary, room_id: String, snapshot: Variant) -> void:
	var progress := get_room_progress(profile, room_id)
	progress["lastSnapshot"] = clone(snapshot)

static func reveal_hint(profile: Dictionary, room_id: String, tier: int) -> int:
	var progress := get_room_progress(profile, room_id)
	progress["hintsRevealed"] = maxi(int(progress.get("hintsRevealed", 0)), tier)
	return int(progress["hintsRevealed"])

static func complete_room(profile: Dictionary, room: Dictionary, runtime: Dictionary) -> Dictionary:
	var progress := get_room_progress(profile, room.get("id", ""))
	var move_count := int(runtime.get("moveCount", 0))
	progress["solved"] = true
	progress["optional"] = room.get("optional", false)
	progress["completedAt"] = progress.get("completedAt", _now_iso())
	var best_moves = progress.get("bestMoves", null)
	if best_moves == null:
		progress["bestMoves"] = move_count
	else:
		progress["bestMoves"] = mini(int(best_moves), move_count)
	if progress.get("bestSolution", []).is_empty() or move_count <= int(progress["bestMoves"]):
		progress["bestSolution"] = clone(runtime.get("actionLog", []))
	progress["lastSnapshot"] = null
	profile["lastRoomId"] = room.get("id", profile.get("lastRoomId", "mailroom-01"))
	return progress

static func unlock_journal(profile: Dictionary, district_id: String) -> void:
	var journals: Array = profile.get("journalsUnlocked", [])
	if not journals.has(district_id):
		journals.append(district_id)

static func unlock_journal_entry(profile: Dictionary, entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	var entries: Array = profile.get("journalEntriesUnlocked", [])
	if entries.has(entry_id):
		return false
	entries.append(entry_id)
	return true

static func get_unlocked_journal_entries(profile: Dictionary, district_id: String = "") -> Array:
	var entries: Array = []
	for entry_id in profile.get("journalEntriesUnlocked", []):
		if district_id.is_empty():
			entries.append(entry_id)
		else:
			entries.append(entry_id)
	return entries

static func unlock_achievement(profile: Dictionary, achievement_id: String) -> bool:
	if achievement_id.is_empty():
		return false

	var achievements: Dictionary = profile.get("achievements", {})
	if achievements.has(achievement_id):
		return false

	achievements[achievement_id] = _now_iso()
	var pending: Array = profile.get("steam", {}).get("pendingAchievements", [])
	if not pending.has(achievement_id):
		pending.append(achievement_id)
	return true

static func get_pending_steam_achievements(profile: Dictionary) -> Array:
	return clone(profile.get("steam", {}).get("pendingAchievements", []))

static func mark_steam_achievement_synced(profile: Dictionary, achievement_id: String) -> void:
	var pending: Array = profile.get("steam", {}).get("pendingAchievements", [])
	if pending.has(achievement_id):
		pending.erase(achievement_id)
	profile.get("steam", {}).get("syncedAchievements", {})[achievement_id] = _now_iso()

static func get_storage_diagnostics(profile: Dictionary) -> Dictionary:
	return {
		"buildChannel": profile.get("buildChannel", BUILD_CHANNEL),
		"contentVersion": profile.get("contentVersion", CONTENT_VERSION),
		"storagePath": get_storage_path(String(profile.get("buildChannel", BUILD_CHANNEL))),
		"demoCarryoverPath": DEMO_CARRYOVER_PATH,
		"hasDemoCarryover": has_demo_carryover(),
		"cloudSlot": profile.get("steam", {}).get("cloudSlot", "patchwork-post-profile"),
	}

static func get_postmark_count(profile: Dictionary, campaign: Dictionary) -> int:
	var total := 0
	for room in campaign.get("rooms", []):
		if not (room is Dictionary):
			continue
		var progress: Dictionary = profile.get("rooms", {}).get(room.get("id", ""), {})
		if progress.get("solved", false):
			total += int(room.get("postmarks", 0))
	return total

static func get_solved_count(profile: Dictionary) -> int:
	var solved := 0
	for room_id in profile.get("rooms", {}).keys():
		if profile["rooms"][room_id].get("solved", false):
			solved += 1
	return solved
