extends SceneTree

const ContentLoader = preload("res://scripts/core/content_loader.gd")
const ContentRepository = preload("res://scripts/core/content_repository.gd")
const Validator = preload("res://scripts/core/patchwork_validator.gd")
const PlaytestLoggerScript = preload("res://scripts/tools/playtest_logger.gd")
const AuthoringDockScript = preload("res://scripts/tools/room_authoring_dock.gd")

var failures: Array = []
var backups: Dictionary = {}

func _initialize() -> void:
	_backup_file(ContentRepository._source_campaign_path())
	_backup_file(ContentRepository._generated_campaign_path())
	_backup_file(ProjectSettings.globalize_path(PlaytestLoggerScript.LOG_PATH))

	var campaign_index := ContentLoader.load_campaign_index()
	var source_campaign := ContentRepository.load_source_campaign()
	_expect(not source_campaign.is_empty(), "Source campaign should load for Batch 3 tool tests.")
	_expect(not campaign_index.is_empty(), "Generated campaign index should load for Batch 3 tool tests.")

	for room in source_campaign.get("rooms", []):
		var balance: Dictionary = room.get("balance", {})
		_expect(not balance.is_empty(), "%s should include balance metadata." % room.get("id", "room"))
		_expect(not String(balance.get("intendedLesson", "")).is_empty(), "%s should define an intended lesson." % room.get("id", "room"))

	var logger = PlaytestLoggerScript.new()
	logger.entries = [
		{"roomId": "mailroom-01", "completed": true, "durationSeconds": 120, "resetCount": 1, "hintTiersUsed": [1], "solveMoveCount": 5},
		{"roomId": "mailroom-01", "completed": false, "durationSeconds": 60, "resetCount": 0, "hintTiersUsed": [], "solveMoveCount": 2},
	]
	var summary: Dictionary = logger.summarize(campaign_index)
	_expect(int(summary.get("byRoom", {}).get("mailroom-01", {}).get("attempts", 0)) == 2, "Playtest logger should summarize attempts by room.")
	_expect(float(summary.get("byRoom", {}).get("mailroom-01", {}).get("averageDurationSeconds", 0.0)) > 0.0, "Playtest logger should compute average duration.")

	var dock = AuthoringDockScript.new()
	root.add_child(dock)
	await process_frame
	dock.live_preview_button.button_pressed = false
	dock.set_context(campaign_index, source_campaign, "mailroom-01", summary)
	await process_frame

	_expect(dock.room_tree != null, "Authoring dock should build a room browser.")
	_expect(dock.layer_grid_container.get_child_count() > 0, "Authoring dock should build visual layer grids.")
	_expect(dock.structure_width_spin != null and dock.structure_height_spin != null, "Authoring dock should expose structural grid controls.")

	dock._handle_new_room()
	await process_frame
	var new_room_id := String(dock.draft_room.get("id", ""))
	_expect(not new_room_id.is_empty(), "New room flow should create a draft id.")
	dock._handle_title_changed("Tooling Draft")
	dock.structure_width_spin.value = 9
	dock.structure_height_spin.value = 8
	dock._handle_apply_resize()
	_expect(String(dock.draft_room.get("layers", [])[0].get("tiles", [])[0]).length() == 9, "Room resize should update layer width.")
	_expect(dock.draft_room.get("layers", [])[0].get("tiles", []).size() == 8, "Room resize should update layer height.")
	dock._handle_layer_name_changed("Front Draft")
	dock._handle_layer_id_changed("front-draft")
	dock._handle_add_layer()
	_expect(dock.draft_room.get("layers", []).size() == 3, "Authoring dock should support adding a third layer.")
	dock._handle_add_entity()
	dock._handle_add_switch()
	dock._handle_add_door()
	if not dock.draft_room.get("switches", []).is_empty():
		var switch_id := String(dock.draft_room.get("switches", [])[0].get("id", ""))
		dock.selected_door_index = 0
		dock._handle_door_switch_link_toggled(true, switch_id)
	dock._handle_save_room()

	var updated_source := ContentRepository.load_source_campaign()
	var saved_room := ContentRepository.get_room_source_by_id(updated_source, new_room_id)
	_expect(not saved_room.is_empty(), "Saved draft room should be written to data/source/campaign.json.")
	_expect(saved_room.get("layers", []).size() == 3, "Saved draft room should persist layer additions.")
	_expect(String(saved_room.get("layers", [])[0].get("id", "")) == "front-draft", "Saved draft room should persist layer id edits.")
	_expect(String(saved_room.get("layers", [])[0].get("name", "")) == "Front Draft", "Saved draft room should persist layer name edits.")
	_expect(String(saved_room.get("layers", [])[0].get("tiles", [])[0]).length() == 9 and saved_room.get("layers", [])[0].get("tiles", []).size() == 8, "Saved draft room should persist grid resize edits.")
	_expect(saved_room.get("entities", []).size() == 1, "Saved draft room should persist entity edits.")
	_expect(saved_room.get("switches", []).size() == 1 and saved_room.get("doors", []).size() == 1, "Saved draft room should persist switch and door edits.")

	var report: Dictionary = Validator.validate_room_report(saved_room)
	_expect(report.get("metrics", {}).get("entityCount", 0) == 1, "Validator report should expose metrics for saved draft rooms.")

	_restore_files()

	if failures.is_empty():
		print("Batch 3 tool tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _backup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			backups[path] = file.get_as_text()
	else:
		backups[path] = null

func _restore_files() -> void:
	for path in backups.keys():
		var contents = backups[path]
		if contents == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(String(contents))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
