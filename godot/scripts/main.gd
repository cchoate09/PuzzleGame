extends Control

const DEV_PROOF_ROOM_ID := "proof-three-layer-01"
const ContentLoader = preload("res://scripts/core/content_loader.gd")
const SaveRuntime = preload("res://scripts/core/patchwork_save.gd")
const EngineScript = preload("res://scripts/core/patchwork_engine.gd")
const RoomViewScript = preload("res://scripts/ui/room_view.gd")

var campaign: Dictionary = {}
var dev_rooms: Dictionary = {}
var solutions: Dictionary = {}
var profile: Dictionary = {}
var engine
var room_ids: Array = []
var current_room_index := 0

var title_label: Label
var subtitle_label: Label
var room_view
var info_label: Label
var controls_label: Label

func _ready() -> void:
	_bootstrap_input_map()
	_build_ui()

	campaign = ContentLoader.load_campaign_index()
	dev_rooms = ContentLoader.load_dev_rooms()
	solutions = ContentLoader.load_solutions()
	profile = SaveRuntime.load_profile()

	if campaign.is_empty():
		title_label.text = "Generated content is missing."
		subtitle_label.text = "Run `npm run sync:godot-data` from the repo root, then reopen the project."
		return

	engine = EngineScript.new(campaign)
	room_ids = ContentLoader.get_room_order(campaign)
	var initial_room_id := String(profile.get("lastRoomId", room_ids[0] if not room_ids.is_empty() else "mailroom-01"))
	_load_room(initial_room_id, true)

func _process(delta: float) -> void:
	if engine == null:
		return
	if engine.is_replaying():
		engine.update(delta * 1000.0)
		_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if engine == null or event.is_echo():
		return

	if event.is_action_pressed("next_room"):
		_cycle_room(1)
		return
	if event.is_action_pressed("prev_room"):
		_cycle_room(-1)
		return
	if event.is_action_pressed("load_proof_room"):
		_load_room(DEV_PROOF_ROOM_ID, false)
		return
	if event.is_action_pressed("replay_room"):
		_play_replay()
		return

	var action: Dictionary = {}
	if event.is_action_pressed("move_up"):
		action = {"type": "move", "direction": "up"}
	elif event.is_action_pressed("move_down"):
		action = {"type": "move", "direction": "down"}
	elif event.is_action_pressed("move_left"):
		action = {"type": "move", "direction": "left"}
	elif event.is_action_pressed("move_right"):
		action = {"type": "move", "direction": "right"}
	elif event.is_action_pressed("wait_turn"):
		action = {"type": "wait"}
	elif event.is_action_pressed("switch_layer"):
		action = {"type": "switch_layer"}
	elif event.is_action_pressed("transfer_object"):
		action = {"type": "transfer"}
	elif event.is_action_pressed("undo_action"):
		action = {"type": "undo"}
	elif event.is_action_pressed("redo_action"):
		action = {"type": "redo"}
	elif event.is_action_pressed("reset_room"):
		action = {"type": "reset"}

	if action.is_empty():
		return

	var changed: bool = engine.dispatch(action)
	if changed:
		_after_state_change()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.text = "Patchwork Post Shipping Runtime"
	title_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Loading native gameplay core..."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.modulate = Color("d7cab7")
	layout.add_child(subtitle_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	layout.add_child(content_row)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(board_panel)

	room_view = RoomViewScript.new()
	room_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_child(room_view)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(330, 400)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_panel)

	var side_margin := MarginContainer.new()
	side_margin.add_theme_constant_override("margin_left", 16)
	side_margin.add_theme_constant_override("margin_top", 16)
	side_margin.add_theme_constant_override("margin_right", 16)
	side_margin.add_theme_constant_override("margin_bottom", 16)
	side_panel.add_child(side_margin)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_margin.add_child(info_label)

	controls_label = Label.new()
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.modulate = Color("d7cab7")
	layout.add_child(controls_label)

func _bootstrap_input_map() -> void:
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("wait_turn", [KEY_SPACE])
	_bind_keys("switch_layer", [KEY_TAB])
	_bind_keys("transfer_object", [KEY_X])
	_bind_keys("undo_action", [KEY_Z])
	_bind_keys("redo_action", [KEY_Y])
	_bind_keys("reset_room", [KEY_R])
	_bind_keys("replay_room", [KEY_P])
	_bind_keys("next_room", [KEY_BRACKETRIGHT, KEY_PAGEDOWN])
	_bind_keys("prev_room", [KEY_BRACKETLEFT, KEY_PAGEUP])
	_bind_keys("load_proof_room", [KEY_F8])

func _bind_keys(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for keycode in keycodes:
		if _action_has_key(action_name, keycode):
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _action_has_key(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and int(event.keycode) == keycode:
			return true
	return false

func _cycle_room(delta: int) -> void:
	if room_ids.is_empty():
		return

	if engine.get_room().get("id", "") == DEV_PROOF_ROOM_ID:
		current_room_index = 0 if delta > 0 else room_ids.size() - 1
	else:
		current_room_index = wrapi(current_room_index + delta, 0, room_ids.size())
	_load_room(room_ids[current_room_index], true)

func _load_room(room_id: String, restore_snapshot: bool) -> void:
	if room_id == DEV_PROOF_ROOM_ID:
		var proof_room: Dictionary = dev_rooms.get("threeLayerProofRoom", {})
		if not proof_room.is_empty():
			engine.load_preview_room(proof_room)
			_refresh_ui()
		return

	var room: Dictionary = ContentLoader.get_room_by_id(campaign, room_id)
	if room.is_empty():
		return

	current_room_index = maxi(room_ids.find(room_id), 0)
	var snapshot: Variant = null
	var progress: Dictionary = SaveRuntime.get_room_progress(profile, room_id)
	if restore_snapshot:
		snapshot = progress.get("lastSnapshot", null)
	progress["attempts"] = int(progress.get("attempts", 0)) + 1
	engine.load_room(room_id, snapshot)
	profile["lastRoomId"] = room_id
	SaveRuntime.save_profile(profile)
	_refresh_ui()

func _play_replay() -> void:
	var room_id := String(engine.get_room().get("id", ""))
	var actions: Array = []
	if room_id == DEV_PROOF_ROOM_ID:
		actions = solutions.get("threeLayerProofSolution", [])
	else:
		var progress := SaveRuntime.get_room_progress(profile, room_id)
		actions = progress.get("bestSolution", [])
		if actions.is_empty():
			actions = solutions.get("canonicalSolutions", {}).get(room_id, [])
	if engine.start_replay(actions):
		_refresh_ui()

func _after_state_change() -> void:
	var room: Dictionary = engine.get_room()
	if room.is_empty():
		return

	var room_id := String(room.get("id", ""))
	if room_id != DEV_PROOF_ROOM_ID:
		if engine.get_runtime().get("solved", false):
			SaveRuntime.complete_room(profile, room, engine.get_runtime())
			SaveRuntime.unlock_journal(profile, String(room.get("districtId", "")))
			SaveRuntime.unlock_achievement(profile, String(room.get("achievementId", "")))
			SaveRuntime.set_room_snapshot(profile, room_id, null)
		else:
			SaveRuntime.set_room_snapshot(profile, room_id, engine.get_room_snapshot())
		profile["lastRoomId"] = room_id
		SaveRuntime.save_profile(profile)

	_refresh_ui()

func _refresh_ui() -> void:
	var room: Dictionary = engine.get_room()
	var runtime: Dictionary = engine.get_runtime()
	room_view.set_room_state(room, runtime)

	var district_id := String(room.get("districtId", ""))
	var district: Dictionary = {}
	for candidate in campaign.get("districts", []):
		if candidate.get("id", "") == district_id:
			district = candidate
			break

	title_label.text = "%s%s" % [room.get("title", "Patchwork Post"), " (Preview)" if room.get("id", "") == DEV_PROOF_ROOM_ID else ""]
	subtitle_label.text = "%s\n%s" % [
		district.get("title", "Shipping Runtime"),
		room.get("objective", "Reach the mailbox.")
	]

	var state: Dictionary = engine.get_text_state()
	var player: Dictionary = state.get("player", {})
	var layer_names: Array = state.get("layerNames", [])
	var active_layer := int(state.get("activeLayer", 0))
	var layer_name: String = String(layer_names[active_layer]) if active_layer >= 0 and active_layer < layer_names.size() else "Layer"
	var room_id := String(room.get("id", ""))
	var progress := SaveRuntime.get_room_progress(profile, room_id) if room_id != DEV_PROOF_ROOM_ID else {}

	var lines := [
		"Room: %s" % room.get("id", ""),
		"Layer: %s (%d/%d)" % [layer_name, active_layer + 1, layer_names.size()],
		"Player: x%s y%s facing %s" % [player.get("x", 0), player.get("y", 0), player.get("facing", "right")],
		"Moves: %s" % state.get("moveCount", 0),
		"Solved: %s" % ("yes" if state.get("solved", false) else "no"),
	]

	if room_id != DEV_PROOF_ROOM_ID:
		lines.append("Postmarks earned: %d" % SaveRuntime.get_postmark_count(profile, campaign))
		lines.append("Rooms solved: %d" % SaveRuntime.get_solved_count(profile))
		lines.append("Attempts on this room: %d" % int(progress.get("attempts", 0)))
		lines.append("Best moves: %s" % ("-" if progress.get("bestMoves", null) == null else str(progress.get("bestMoves"))))

	lines.append("")
	lines.append("Switches and doors:")
	for switch_def in state.get("switches", []):
		lines.append("  %s at L%d (%d,%d): %s" % [
			switch_def.get("id", ""),
			int(switch_def.get("layer", 0)) + 1,
			switch_def.get("x", 0),
			switch_def.get("y", 0),
			"active" if switch_def.get("active", false) else "idle",
		])
	for door in state.get("doors", []):
		lines.append("  %s at L%d (%d,%d): %s" % [
			door.get("id", ""),
			int(door.get("layer", 0)) + 1,
			door.get("x", 0),
			door.get("y", 0),
			"open" if door.get("open", false) else "closed",
		])
	if state.get("switches", []).is_empty() and state.get("doors", []).is_empty():
		lines.append("  No linked mechanisms in this room.")

	lines.append("")
	lines.append("Entities:")
	for entity in state.get("entities", []):
		lines.append("  %s (%s) on L%d at (%d,%d)" % [
			entity.get("id", ""),
			entity.get("type", ""),
			int(entity.get("layer", 0)) + 1,
			entity.get("x", 0),
			entity.get("y", 0),
		])
	if state.get("entities", []).is_empty():
		lines.append("  No entities in this room.")

	info_label.text = "\n".join(lines)
	controls_label.text = "Move: arrows/WASD | Wait: Space | Switch: Tab | Transfer: X | Undo/Redo: Z/Y | Reset: R | Replay: P | Rooms: [ and ] | Proof room: F8"
