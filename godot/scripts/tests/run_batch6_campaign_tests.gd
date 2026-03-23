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

	var canonical_solutions: Dictionary = ContentLoader.load_solutions().get("canonicalSolutions", {})
	var main_campaign: Dictionary = scene.campaign.get("mainCampaign", {})
	var secret_route: Dictionary = scene.campaign.get("secretRoute", {})
	var journal_entries: Array = scene.campaign.get("journalEntries", [])

	_expect(main_campaign.get("mainRoomIds", []).size() == 21, "Batch 6 should expose a 21-room main route.")
	_expect(secret_route.get("roomIds", []).size() == 3, "Batch 6 should expose a 3-room secret route.")
	_expect(journal_entries.size() == 5, "Batch 6 should expose five hidden journal entries.")
	_expect(scene.route_buttons.has("attic-01") and scene.route_buttons["attic-01"].disabled, "Attic should stay locked until the three secret side routes are solved.")

	for room_id_variant in main_campaign.get("mainRoomIds", []):
		var room_id := String(room_id_variant)
		scene._load_room(room_id, false)
		await process_frame
		for action in canonical_solutions.get(room_id, []):
			scene._dispatch_room_action(action)
		_expect(scene.engine.get_runtime().get("solved", false), "%s should solve through the main runtime." % room_id)

	_expect(scene._is_main_campaign_complete(), "Solving every main-route room should satisfy the main campaign completion gate.")
	_expect(scene.demo_panel.visible, "Main campaign finale should raise the shared completion panel.")
	_expect(scene.demo_title_label.text == "Festival Line Restored", "Main campaign finale should use the festival completion title.")
	_expect(scene.profile.get("achievements", {}).has("festival-line"), "Main campaign finale should unlock the festival-line achievement.")
	_expect(scene.route_buttons.has("attic-01") and scene.route_buttons["attic-01"].disabled, "Attic should still require the three secret side routes even after credits.")

	for room_id_variant in secret_route.get("requiredRoomIds", []):
		var room_id := String(room_id_variant)
		scene._load_room(room_id, false)
		await process_frame
		for action in canonical_solutions.get(room_id, []):
			scene._dispatch_room_action(action)
		_expect(scene.engine.get_runtime().get("solved", false), "%s should solve as a secret-route prerequisite." % room_id)

	_expect(scene.profile.get("journalEntriesUnlocked", []).size() >= 3, "Secret side routes should unlock hidden journal entries.")
	_expect(scene.route_buttons.has("attic-01") and not scene.route_buttons["attic-01"].disabled, "Attic should unlock after the three secret side routes are solved.")

	for room_id_variant in secret_route.get("roomIds", []):
		var room_id := String(room_id_variant)
		scene._load_room(room_id, false)
		await process_frame
		for action in canonical_solutions.get(room_id, []):
			scene._dispatch_room_action(action)
		_expect(scene.engine.get_runtime().get("solved", false), "%s should solve along the secret route." % room_id)

	_expect(scene._is_secret_route_complete(), "Solving every attic room should satisfy the secret-route completion gate.")
	_expect(scene.demo_panel.visible and scene.demo_title_label.text == "Secret Line Complete", "Secret finale should raise the secret-line completion panel.")
	_expect(scene.profile.get("journalEntriesUnlocked", []).size() == journal_entries.size(), "Secret route completion should unlock every hidden journal entry.")
	_expect(scene.profile.get("achievements", {}).has("secret-line"), "Secret finale should unlock the secret-line achievement.")
	_expect(scene.profile.get("achievements", {}).has("archivist"), "Unlocking every journal entry should award Archivist.")

	_restore_files()

	if failures.is_empty():
		print("Batch 6 campaign tests passed.")
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
