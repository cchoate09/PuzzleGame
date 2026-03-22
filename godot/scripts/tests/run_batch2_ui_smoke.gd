extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveRuntime = preload("res://scripts/core/patchwork_save.gd")
const ContentLoader = preload("res://scripts/core/content_loader.gd")

var failures: Array = []
var had_original_save := false
var original_save_text := ""

func _initialize() -> void:
	_backup_save()
	SaveRuntime.save_profile(SaveRuntime.create_default_profile())

	var scene = MainScene.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	_expect(scene.room_view != null, "Main scene should create the room view.")
	_expect(scene.district_list != null, "Main scene should create the district route list.")
	_expect(scene.district_list.get_child_count() == scene.campaign.get("districts", []).size(), "Every district should appear in the route list.")
	_expect(scene.setting_contrast_button != null and scene.setting_motion_button != null and scene.setting_font_scale_slider != null, "Settings controls should be present.")
	_expect(scene.dialogue_panel != null and scene.toast_panel != null and scene.solve_panel != null, "Overlay panels should be present.")

	scene._handle_high_contrast_toggled(true)
	scene._handle_reduced_motion_toggled(true)
	scene._handle_font_scale_changed(1.2)
	_expect(scene.profile.get("settings", {}).get("highContrast", false), "High contrast toggle should persist to the profile.")
	_expect(scene.profile.get("settings", {}).get("reducedMotion", false), "Reduced motion toggle should persist to the profile.")
	_expect(absf(float(scene.profile.get("settings", {}).get("fontScale", 1.0)) - 1.2) < 0.001, "Font scale should persist to the profile.")

	scene._load_room("mailroom-01", false)
	await process_frame
	_expect(scene.dialogue_panel.visible, "Loading a room should surface the dialogue card.")
	scene._show_toast("Smoke toast")
	_expect(scene.toast_panel.visible and scene.toast_label.text == "Smoke toast", "Toast overlay should show the supplied message.")

	var canonical_solutions: Dictionary = ContentLoader.load_solutions().get("canonicalSolutions", {})
	for action in canonical_solutions.get("mailroom-01", []):
		scene._dispatch_room_action(action)

	_expect(scene.engine.get_runtime().get("solved", false), "Canonical mailroom solution should solve inside the main scene.")
	_expect(scene.solve_time_left > 0.0, "Solving a new room should raise the solve banner.")
	_expect(scene.route_buttons.has("market-01"), "Route list should include the newly unlocked market room button.")
	_expect(not scene.route_buttons["market-01"].disabled, "Market room button should unlock after the opening solve.")

	_restore_save()

	if failures.is_empty():
		print("Batch 2 UI smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _backup_save() -> void:
	if FileAccess.file_exists(SaveRuntime.STORAGE_PATH):
		had_original_save = true
		var file := FileAccess.open(SaveRuntime.STORAGE_PATH, FileAccess.READ)
		if file != null:
			original_save_text = file.get_as_text()

func _restore_save() -> void:
	if had_original_save:
		var file := FileAccess.open(SaveRuntime.STORAGE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(original_save_text)
	elif FileAccess.file_exists(SaveRuntime.STORAGE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveRuntime.STORAGE_PATH))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
