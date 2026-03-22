class_name PatchworkPlaytestLogger
extends RefCounted

const LOG_PATH := "user://patchwork-post-playtests.json"

var entries: Array = []
var current_session: Dictionary = {}

func _init() -> void:
	entries = load_entries()

static func _clone(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true, false)

static func _now_unix_seconds() -> int:
	return int(Time.get_unix_time_from_system())

func load_entries() -> Array:
	if not FileAccess.file_exists(LOG_PATH):
		return []
	var file := FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []

func save_entries() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("%s\n" % JSON.stringify(entries, "\t"))

func clear_entries() -> void:
	entries = []
	current_session = {}
	save_entries()

func begin_room(room: Dictionary) -> void:
	if room.is_empty():
		return
	_finalize_current_session("room_switch")
	current_session = {
		"roomId": room.get("id", ""),
		"districtId": room.get("districtId", ""),
		"title": room.get("title", ""),
		"optional": room.get("optional", false),
		"startedAt": _now_iso(),
		"startedAtUnix": _now_unix_seconds(),
		"completed": false,
		"abandonReason": "",
		"actionCount": 0,
		"moveCount": 0,
		"resetCount": 0,
		"hintTiersUsed": [],
	}

func record_action(action: Dictionary) -> void:
	if current_session.is_empty():
		return
	current_session["actionCount"] = int(current_session.get("actionCount", 0)) + 1
	if String(action.get("type", "")) != "undo" and String(action.get("type", "")) != "redo":
		current_session["moveCount"] = int(current_session.get("moveCount", 0)) + 1

func record_reset() -> void:
	if current_session.is_empty():
		return
	current_session["resetCount"] = int(current_session.get("resetCount", 0)) + 1

func record_hint(tier: int) -> void:
	if current_session.is_empty():
		return
	var hint_tiers: Array = current_session.get("hintTiersUsed", [])
	if not hint_tiers.has(tier):
		hint_tiers.append(tier)
	current_session["hintTiersUsed"] = hint_tiers

func complete_room(runtime: Dictionary) -> void:
	if current_session.is_empty():
		return
	current_session["completed"] = true
	current_session["solveMoveCount"] = int(runtime.get("moveCount", current_session.get("moveCount", 0)))
	_finalize_current_session("")

func abandon_current(reason: String = "quit") -> void:
	_finalize_current_session(reason)

func summarize(campaign: Dictionary = {}) -> Dictionary:
	var by_room := {}
	for entry in entries:
		var room_id := String(entry.get("roomId", ""))
		if room_id.is_empty():
			continue
		if not by_room.has(room_id):
			by_room[room_id] = {
				"attempts": 0,
				"completions": 0,
				"abandonments": 0,
				"totalDurationSeconds": 0,
				"totalResets": 0,
				"totalHints": 0,
				"totalMoves": 0,
				"averageDurationSeconds": null,
				"averageResets": null,
				"averageHints": null,
				"averageMoves": null,
			}
		var aggregate: Dictionary = by_room[room_id]
		aggregate["attempts"] = int(aggregate.get("attempts", 0)) + 1
		aggregate["totalDurationSeconds"] = int(aggregate.get("totalDurationSeconds", 0)) + int(entry.get("durationSeconds", 0))
		aggregate["totalResets"] = int(aggregate.get("totalResets", 0)) + int(entry.get("resetCount", 0))
		aggregate["totalHints"] = int(aggregate.get("totalHints", 0)) + int(entry.get("hintTiersUsed", []).size())
		aggregate["totalMoves"] = int(aggregate.get("totalMoves", 0)) + int(entry.get("solveMoveCount", entry.get("moveCount", 0)))
		if bool(entry.get("completed", false)):
			aggregate["completions"] = int(aggregate.get("completions", 0)) + 1
		else:
			aggregate["abandonments"] = int(aggregate.get("abandonments", 0)) + 1

	for room_id in by_room.keys():
		var aggregate: Dictionary = by_room[room_id]
		var attempts: int = maxi(1, int(aggregate.get("attempts", 1)))
		aggregate["averageDurationSeconds"] = snapped(float(aggregate.get("totalDurationSeconds", 0)) / float(attempts), 0.1)
		aggregate["averageResets"] = snapped(float(aggregate.get("totalResets", 0)) / float(attempts), 0.1)
		aggregate["averageHints"] = snapped(float(aggregate.get("totalHints", 0)) / float(attempts), 0.1)
		aggregate["averageMoves"] = snapped(float(aggregate.get("totalMoves", 0)) / float(attempts), 0.1)

	return {
		"entries": _clone(entries),
		"byRoom": by_room,
		"entryCount": entries.size(),
		"roomCount": by_room.size(),
		"campaignRoomCount": campaign.get("rooms", []).size(),
	}

func _finalize_current_session(abandon_reason: String) -> void:
	if current_session.is_empty():
		return
	current_session["endedAt"] = _now_iso()
	current_session["endedAtUnix"] = _now_unix_seconds()
	current_session["durationSeconds"] = int(current_session.get("endedAtUnix", 0)) - int(current_session.get("startedAtUnix", 0))
	if not bool(current_session.get("completed", false)):
		current_session["abandonReason"] = abandon_reason
	entries.append(_clone(current_session))
	current_session = {}
	save_entries()
