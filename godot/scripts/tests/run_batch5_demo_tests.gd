extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveRuntime = preload("res://scripts/core/patchwork_save.gd")
const ContentLoader = preload("res://scripts/core/content_loader.gd")

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

	var scene = MainScene.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var demo_config: Dictionary = scene.campaign.get("demo", {})
	var main_room_ids: Array = demo_config.get("mainRoomIds", [])
	var optional_room_ids: Array = demo_config.get("optionalRoomIds", [])
	_expect(main_room_ids.size() == 11, "Batch 5 demo slice should define 11 main rooms.")
	_expect(optional_room_ids.size() == 4, "Batch 5 demo slice should define 4 optional rooms.")
	_expect(scene.progress_label.text.find("Demo route: 0 / 11 main") != -1, "Progress label should surface demo-slice progress.")
	_expect(scene.route_buttons.has("market-01") and scene.route_buttons["market-01"].disabled, "Market should start locked until two mailroom postmarks are earned.")

	var canonical_solutions: Dictionary = ContentLoader.load_solutions().get("canonicalSolutions", {})
	for room_id_variant in main_room_ids:
		var room_id := String(room_id_variant)
		scene._load_room(room_id, false)
		await process_frame
		for action in canonical_solutions.get(room_id, []):
			scene._dispatch_room_action(action)
		_expect(scene.engine.get_runtime().get("solved", false), "%s should solve through the main runtime." % room_id)
		if room_id == "mailroom-02":
			_expect(not scene.route_buttons["market-01"].disabled, "Market should unlock after the second mailroom solve.")
		if room_id == "market-03":
			_expect(not scene.route_buttons["greenhouse-01"].disabled, "Greenhouse should unlock during the market stretch of the demo.")

	_expect(scene._is_demo_complete(), "Completing the demo mainline should satisfy the demo-complete gate.")
	_expect(scene.demo_time_left > 0.0 and scene.demo_panel.visible, "Final demo solve should raise the demo completion panel.")
	_expect(scene.demo_title_label.text == "Demo Route Complete", "Demo panel should use the configured completion title.")
	_expect(scene.progress_label.text.find("Demo route: 11 / 11 main") != -1, "Progress label should report a complete demo route after the finale.")
	_expect(scene.route_buttons.has("clocktower-01") and not scene.route_buttons["clocktower-01"].disabled, "Clocktower should unlock after the demo finale.")
	_expect(scene.dialogue_text_label.text.find("bell echoes") != -1, "Demo ending dialogue should tease later mechanics.")

	_restore_files()

	if failures.is_empty():
		print("Batch 5 demo tests passed.")
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
