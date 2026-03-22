class_name PatchworkContentLoader
extends RefCounted

const CAMPAIGN_PATH := "res://data/generated/campaign_index.json"
const DEV_ROOMS_PATH := "res://data/generated/dev_rooms.json"
const SOLUTIONS_PATH := "res://data/generated/solutions.json"

static func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open JSON file: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Unable to parse JSON file: %s" % path)
		return {}
	return parsed

static func load_campaign_index() -> Dictionary:
	var data: Variant = _load_json(CAMPAIGN_PATH)
	return data if data is Dictionary else {}

static func load_dev_rooms() -> Dictionary:
	var data: Variant = _load_json(DEV_ROOMS_PATH)
	return data if data is Dictionary else {}

static func load_solutions() -> Dictionary:
	var data: Variant = _load_json(SOLUTIONS_PATH)
	return data if data is Dictionary else {}

static func get_room_by_id(campaign: Dictionary, room_id: String) -> Dictionary:
	var rooms_by_id: Dictionary = campaign.get("roomsById", {})
	var room: Variant = rooms_by_id.get(room_id, {})
	return room if room is Dictionary else {}

static func get_room_order(campaign: Dictionary) -> Array:
	var ids: Array = []
	for room in campaign.get("rooms", []):
		if room is Dictionary and room.has("id"):
			ids.append(room["id"])
	return ids
