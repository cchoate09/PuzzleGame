class_name PatchworkContentRepository
extends RefCounted

const SOURCE_CAMPAIGN_RELATIVE_PATH := "data/source/campaign.json"
const GENERATED_CAMPAIGN_RELATIVE_PATH := "godot/data/generated/campaign_index.json"

static func _clone(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _repo_root_path() -> String:
	return ProjectSettings.globalize_path("res://..")

static func _source_campaign_path() -> String:
	return _repo_root_path().path_join(SOURCE_CAMPAIGN_RELATIVE_PATH)

static func _generated_campaign_path() -> String:
	return _repo_root_path().path_join(GENERATED_CAMPAIGN_RELATIVE_PATH)

static func _read_json_absolute(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}

static func _write_json_absolute(path: String, payload: Variant) -> bool:
	var directory_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("%s\n" % JSON.stringify(payload, "\t"))
	return true

static func load_source_campaign() -> Dictionary:
	var data: Variant = _read_json_absolute(_source_campaign_path())
	return data if data is Dictionary else {}

static func build_campaign_index(campaign_source: Dictionary) -> Dictionary:
	var campaign_index := {
		"achievements": _clone(campaign_source.get("achievements", [])),
		"districts": _clone(campaign_source.get("districts", [])),
		"rooms": _clone(campaign_source.get("rooms", [])),
		"roomsById": {},
	}
	for room in campaign_index["rooms"]:
		campaign_index["roomsById"][room.get("id", "")] = room
	return campaign_index

static func save_source_campaign(campaign_source: Dictionary) -> bool:
	return _write_json_absolute(_source_campaign_path(), campaign_source)

static func save_generated_campaign_index(campaign_source: Dictionary) -> bool:
	return _write_json_absolute(_generated_campaign_path(), build_campaign_index(campaign_source))

static func persist_campaign(campaign_source: Dictionary) -> bool:
	var source_saved := save_source_campaign(campaign_source)
	var generated_saved := save_generated_campaign_index(campaign_source)
	return source_saved and generated_saved

static func get_room_source_by_id(campaign_source: Dictionary, room_id: String) -> Dictionary:
	for room in campaign_source.get("rooms", []):
		if room.get("id", "") == room_id:
			return _clone(room)
	return {}

static func upsert_room(campaign_source: Dictionary, room_data: Dictionary) -> Dictionary:
	var next_campaign: Dictionary = _clone(campaign_source)
	var next_rooms: Array = next_campaign.get("rooms", [])
	var replaced := false
	for index in range(next_rooms.size()):
		if next_rooms[index].get("id", "") == room_data.get("id", ""):
			next_rooms[index] = _clone(room_data)
			replaced = true
			break
	if not replaced:
		next_rooms.append(_clone(room_data))
	next_campaign["rooms"] = next_rooms
	return next_campaign

static func remove_room(campaign_source: Dictionary, room_id: String) -> Dictionary:
	var next_campaign: Dictionary = _clone(campaign_source)
	var next_rooms: Array = []
	for room in campaign_source.get("rooms", []):
		if room.get("id", "") != room_id:
			next_rooms.append(_clone(room))
	next_campaign["rooms"] = next_rooms
	return next_campaign

static func create_blank_room(room_id: String, district_id: String = "mailroom") -> Dictionary:
	return {
		"id": room_id,
		"districtId": district_id,
		"title": "New Route",
		"optional": false,
		"unlockCost": 0,
		"postmarks": 1,
		"objective": "Reach the glowing mailbox.",
		"blurb": "A freshly drafted route.",
		"intro": [
			{
				"speaker": "Mina",
				"text": "Draft the lesson this room should teach."
			}
		],
		"hintTiers": [
			"Describe the first conceptual nudge.",
			"Describe the mechanic the player should notice.",
			"Describe the opening sequence that gets them started."
		],
		"balance": {
			"intendedLesson": "Define the room's lesson.",
			"targetDifficulty": 1,
			"expectedSolveMinutes": 2,
			"commonMisunderstanding": "Describe the likely misconception."
		},
		"layers": [
			{
				"id": "front",
				"name": "Front Sheet",
				"tiles": [
					"#######",
					"#.....#",
					"#..S..#",
					"#.....#",
					"#....G#",
					"#######"
				]
			},
			{
				"id": "back",
				"name": "Back Sheet",
				"tiles": [
					"#######",
					"#.....#",
					"#..S..#",
					"#.....#",
					"#.....#",
					"#######"
				]
			}
		],
		"start": {
			"layer": 0,
			"x": 1,
			"y": 1,
			"facing": "right"
		},
		"entities": [],
		"switches": [],
		"doors": []
	}

static func duplicate_room(campaign_source: Dictionary, source_room_id: String, new_room_id: String) -> Dictionary:
	var room := get_room_source_by_id(campaign_source, source_room_id)
	if room.is_empty():
		return {}
	room["id"] = new_room_id
	room["title"] = "%s Copy" % room.get("title", "Room")
	room.erase("achievementId")
	return room
