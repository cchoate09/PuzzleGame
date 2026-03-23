extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveRuntime = preload("res://scripts/core/patchwork_save.gd")
const InputBindings = preload("res://scripts/core/patchwork_input.gd")

var failures: Array = []
var backups: Dictionary = {}

func _initialize() -> void:
	_backup_file(SaveRuntime.FULL_STORAGE_PATH)
	_backup_file(SaveRuntime.DEMO_STORAGE_PATH)
	_backup_file(SaveRuntime.DEMO_CARRYOVER_PATH)
	_backup_file(SaveRuntime.LEGACY_STORAGE_PATH)
	_clear_test_file(SaveRuntime.FULL_STORAGE_PATH)
	_clear_test_file(SaveRuntime.DEMO_STORAGE_PATH)
	_clear_test_file(SaveRuntime.DEMO_CARRYOVER_PATH)
	_clear_test_file(SaveRuntime.LEGACY_STORAGE_PATH)

	var demo_profile := SaveRuntime.create_default_profile()
	demo_profile["buildChannel"] = "demo"
	SaveRuntime.get_room_progress(demo_profile, "mailroom-01")["solved"] = true
	SaveRuntime.unlock_achievement(demo_profile, "first-stamp")
	SaveRuntime.save_profile(demo_profile, "demo")

	var imported_profile := SaveRuntime.load_profile("full")
	_expect(bool(imported_profile.get("rooms", {}).get("mailroom-01", {}).get("solved", false)), "Full profile should import solved demo progress when no full save exists.")
	_expect(String(imported_profile.get("buildChannel", "")) == "full", "Imported profile should become a full-build profile.")
	_expect(imported_profile.get("demoCarryoverImportedAt", null) != null, "Imported profile should record demo carryover import time.")

	var scene = MainScene.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	_expect(scene.hint_opening_button != null, "Main scene should create the guided opening hint button.")
	_expect(scene.input_mode_label != null, "Main scene should create the input mode status label.")
	_expect(scene.steam_status_label != null and scene.save_status_label != null, "Main scene should surface Steam/save support status.")
	_expect(not scene.authoring_dock.visible, "Developer tools should stay hidden by default in the public runtime shell.")
	_expect(scene.remap_rows.has("wait_turn"), "Main scene should create remap rows for gameplay actions.")

	scene._load_room("mailroom-01", false)
	scene._handle_hint_request(1)
	scene._handle_hint_request(2)
	scene._handle_hint_request(3)
	_expect(scene.hint_opening_button.visible, "Guided opening button should appear after the third hint tier.")
	_expect(scene.hint_opening_actions.size() > 0, "Guided opening should derive opening actions from saved or canonical solutions.")

	scene._handle_guided_opening_requested()
	for _index in range(scene.hint_opening_actions.size() + 2):
		scene.engine.update(300.0)
	_expect(int(scene.engine.get_runtime().get("moveCount", -1)) == scene.hint_opening_actions.size(), "Guided opening replay should advance the room by the opening action count.")

	scene._start_control_rebind("wait_turn", "keyboard")
	scene._complete_control_rebind({"kind": "key", "keycode": KEY_Q, "physicalKeycode": KEY_Q})
	var controls: Dictionary = scene.profile.get("settings", {}).get("controls", {})
	_expect(int(controls.get("wait_turn", {}).get("keyboard", [{}])[0].get("keycode", 0)) == KEY_Q, "Control remap flow should persist the updated keyboard binding.")
	_expect(scene.controls_label.text.find("Q") != -1, "Controls summary should reflect remapped keys.")

	if OS.is_debug_build():
		scene._toggle_developer_tools()
		_expect(scene.authoring_dock.visible, "Developer tools should toggle open in debug builds.")

	_restore_files()

	if failures.is_empty():
		print("Batch 4 support tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _backup_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			backups[absolute_path] = file.get_as_text()
	else:
		backups[absolute_path] = null

func _restore_files() -> void:
	for absolute_path in backups.keys():
		var contents = backups[absolute_path]
		if contents == null:
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)
			continue
		var file := FileAccess.open(absolute_path, FileAccess.WRITE)
		if file != null:
			file.store_string(String(contents))

func _clear_test_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
