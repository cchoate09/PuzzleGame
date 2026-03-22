class_name PatchworkSave
extends RefCounted

const STORAGE_PATH := "user://patchwork-post-save-v1.json"
const DEFAULT_CONTROLS := {
	"up": "ArrowUp",
	"down": "ArrowDown",
	"left": "ArrowLeft",
	"right": "ArrowRight",
	"wait": "Space",
	"switch_layer": "Tab",
	"transfer": "KeyX",
	"undo": "KeyZ",
	"redo": "KeyY",
	"reset": "KeyR",
	"replay": "KeyP",
}

static func clone(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true, false)

static func create_default_profile() -> Dictionary:
	return {
		"version": 1,
		"startedAt": _now_iso(),
		"lastRoomId": "mailroom-01",
		"rooms": {},
		"achievements": {},
		"journalsUnlocked": [],
		"settings": {
			"highContrast": false,
			"reducedMotion": false,
			"fontScale": 1.0,
			"controls": clone(DEFAULT_CONTROLS),
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
		"lastRoomId": raw_dict.get("lastRoomId", base["lastRoomId"]),
		"rooms": {},
		"achievements": clone(base["achievements"]),
		"journalsUnlocked": [],
		"settings": {
			"highContrast": false,
			"reducedMotion": false,
			"fontScale": 1.0,
			"controls": clone(DEFAULT_CONTROLS),
		},
	}

	for achievement_id in raw_dict.get("achievements", {}).keys():
		profile["achievements"][achievement_id] = raw_dict["achievements"][achievement_id]

	for journal_id in raw_dict.get("journalsUnlocked", []):
		if not profile["journalsUnlocked"].has(journal_id):
			profile["journalsUnlocked"].append(journal_id)

	var raw_settings: Dictionary = raw_dict.get("settings", {})
	var settings: Dictionary = profile["settings"]
	settings["highContrast"] = raw_settings.get("highContrast", false)
	settings["reducedMotion"] = raw_settings.get("reducedMotion", false)
	settings["fontScale"] = raw_settings.get("fontScale", 1.0)
	var controls: Dictionary = settings["controls"]
	for control_name in raw_settings.get("controls", {}).keys():
		controls[control_name] = raw_settings["controls"][control_name]

	for room_id in raw_dict.get("rooms", {}).keys():
		profile["rooms"][room_id] = _hydrate_room_progress(raw_dict["rooms"][room_id])

	return profile

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(STORAGE_PATH):
		return create_default_profile()

	var file := FileAccess.open(STORAGE_PATH, FileAccess.READ)
	if file == null:
		return create_default_profile()

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return hydrate_profile(parsed)

static func save_profile(profile: Dictionary) -> void:
	var file := FileAccess.open(STORAGE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save profile to %s" % STORAGE_PATH)
		return
	file.store_string(JSON.stringify(profile, "\t"))

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

static func unlock_achievement(profile: Dictionary, achievement_id: String) -> bool:
	if achievement_id.is_empty():
		return false

	var achievements: Dictionary = profile.get("achievements", {})
	if achievements.has(achievement_id):
		return false

	achievements[achievement_id] = _now_iso()
	return true

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
