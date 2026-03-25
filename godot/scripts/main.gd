extends Control

const DEV_PROOF_ROOM_ID := "proof-three-layer-01"
const BACKDROP := Color("efe1c4")
const CARD_FILL := Color("fff8eb")
const CARD_BORDER := Color("d3b98c")
const ACCENT_INK := Color("452b24")
const ACCENT_MUTED := Color("7e6454")
const ACCENT_GOLD := Color("d49f3d")
const ACCENT_GREEN := Color("7aa37c")
const ACCENT_RUST := Color("cf6d49")

const ContentLoader = preload("res://scripts/core/content_loader.gd")
const InputBindings = preload("res://scripts/core/patchwork_input.gd")
const SaveRuntime = preload("res://scripts/core/patchwork_save.gd")
const EngineScript = preload("res://scripts/core/patchwork_engine.gd")
const ContentRepository = preload("res://scripts/core/content_repository.gd")
const SteamBridgeScript = preload("res://scripts/platform/steam_bridge.gd")
const RoomViewScript = preload("res://scripts/ui/room_view.gd")
const AudioManagerScript = preload("res://scripts/ui/audio_manager.gd")
const PlaytestLoggerScript = preload("res://scripts/tools/playtest_logger.gd")
const AuthoringDockScript = preload("res://scripts/tools/room_authoring_dock.gd")

var campaign: Dictionary = {}
var dev_rooms: Dictionary = {}
var solutions: Dictionary = {}
var source_campaign: Dictionary = {}
var profile: Dictionary = {}
var engine
var audio_manager
var playtest_logger
var steam_bridge
var steam_status: Dictionary = {}
var authoring_dock
var room_ids: Array = []
var current_room_index: int = 0
var current_font_scale: float = 1.0
var last_input_source := "keyboard"
var last_room_id: String = ""
var authoring_context_room_id: String = ""
var last_solved_state := false
var transition_time_left := 0.0
var toast_time_left := 0.0
var dialogue_time_left := 0.0
var solve_time_left := 0.0
var demo_time_left := 0.0
var route_unlock_snapshot: Dictionary = {"districts": [], "rooms": []}
var remap_pending_action := ""
var remap_pending_source := "keyboard"
var hint_opening_actions: Array = []
var developer_tools_visible := false

var eyebrow_label: Label
var title_label: Label
var subtitle_label: Label
var move_label: Label
var progress_label: Label
var route_status_label: Label
var room_view
var district_list: VBoxContainer
var objective_label: Label
var blurb_label: Label
var hint_status_label: Label
var hint_text_label: Label
var hint_opening_label: Label
var hint_opening_button: Button
var journal_label: Label
var stats_label: Label
var controls_label: Label
var input_mode_label: Label
var setting_contrast_button: CheckButton
var setting_motion_button: CheckButton
var setting_font_scale_slider: HSlider
var setting_font_scale_value: Label
var setting_colorblind_option: OptionButton
var setting_master_volume_slider: HSlider
var setting_sfx_volume_slider: HSlider
var remap_rows: Dictionary = {}
var steam_status_label: Label
var save_status_label: Label
var authoring_toggle_button: Button
var remap_overlay: PanelContainer
var remap_prompt_label: Label
var footer_label: Label
var layer_chip_row: HBoxContainer
var dialogue_panel: PanelContainer
var dialogue_speaker_label: Label
var dialogue_text_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var solve_panel: PanelContainer
var solve_title_label: Label
var solve_subtitle_label: Label
var solve_record_label: Label
var solve_replay_button: Button
var demo_panel: PanelContainer
var demo_title_label: Label
var demo_body_label: Label
var demo_teaser_label: Label
var pause_panel: PanelContainer
var pause_resume_button: Button
var transition_overlay: ColorRect
var card_title_labels: Array = []
var scalable_controls: Array = []
var route_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var hint_buttons: Array = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKDROP)
	profile = SaveRuntime.load_profile()
	_bootstrap_input_map()
	_build_ui()
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	steam_bridge = SteamBridgeScript.new()
	steam_status = steam_bridge.initialize()

	campaign = ContentLoader.load_campaign_index()
	dev_rooms = ContentLoader.load_dev_rooms()
	solutions = ContentLoader.load_solutions()
	source_campaign = ContentRepository.load_source_campaign()
	playtest_logger = PlaytestLoggerScript.new()
	_apply_profile_settings()
	_sync_steam_state()

	if campaign.is_empty():
		title_label.text = "Generated content is missing."
		subtitle_label.text = "Run `npm run sync:content` from the repo root, then reopen the project."
		return

	engine = EngineScript.new(campaign)
	room_ids = ContentLoader.get_room_order(campaign)
	route_unlock_snapshot = _capture_unlock_snapshot()
	var fallback_room_id: String = room_ids[0] if not room_ids.is_empty() else "mailroom-01"
	var initial_room_id: String = String(profile.get("lastRoomId", fallback_room_id))
	_load_room(initial_room_id, true)
	call_deferred("_prime_controller_focus")

func _process(delta: float) -> void:
	_update_overlay_state(delta)
	if engine == null:
		return
	if engine.is_replaying():
		engine.update(delta * 1000.0)
		_refresh_ui()

func _exit_tree() -> void:
	if playtest_logger != null:
		playtest_logger.abandon_current("quit")

func _input(event: InputEvent) -> void:
	if event == null or event.is_echo():
		return
	var detected_source := InputBindings.detect_input_source(event)
	if detected_source != "mouse":
		last_input_source = detected_source
	if remap_pending_action.is_empty():
		return
	if event is InputEventKey and bool(event.pressed) and int(event.keycode) == KEY_ESCAPE:
		_cancel_control_rebind()
		get_viewport().set_input_as_handled()
		return
	if InputBindings.is_bindable_event(event):
		_complete_control_rebind(InputBindings.serialize_event(event))
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if engine == null or event.is_echo():
		return
	if event is InputEventKey and bool(event.pressed) and int(event.keycode) == KEY_F9 and OS.is_debug_build():
		_toggle_developer_tools()
		return
	if not remap_pending_action.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var ui_focus_locked: bool = focus_owner != null and focus_owner != room_view
	if ui_focus_locked:
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

	_dispatch_room_action(action)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var header_card: Dictionary = _create_card("Town Route")
	layout.add_child(header_card["panel"])

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 16)
	header_card["body"].add_child(header_row)

	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_left.add_theme_constant_override("separation", 6)
	header_row.add_child(header_left)

	eyebrow_label = Label.new()
	eyebrow_label.text = "PATCHWORK POST"
	_register_scaled_font(eyebrow_label, 14)
	eyebrow_label.add_theme_color_override("font_color", ACCENT_RUST)
	header_left.add_child(eyebrow_label)

	title_label = Label.new()
	title_label.text = "Patchwork Post Shipping Runtime"
	_register_scaled_font(title_label, 32)
	title_label.add_theme_color_override("font_color", ACCENT_INK)
	header_left.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Loading native gameplay core..."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_register_scaled_font(subtitle_label, 16)
	subtitle_label.add_theme_color_override("font_color", ACCENT_MUTED)
	header_left.add_child(subtitle_label)

	var header_right := VBoxContainer.new()
	header_right.custom_minimum_size = Vector2(250, 0)
	header_right.add_theme_constant_override("separation", 10)
	header_row.add_child(header_right)

	move_label = _create_metric_label()
	header_right.add_child(move_label)

	progress_label = _create_metric_label()
	header_right.add_child(progress_label)

	route_status_label = _create_metric_label()
	header_right.add_child(route_status_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	layout.add_child(content_row)

	var route_column := VBoxContainer.new()
	route_column.custom_minimum_size = Vector2(320, 0)
	route_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_column.add_theme_constant_override("separation", 14)
	content_row.add_child(route_column)

	var route_card: Dictionary = _create_card("Town Map")
	route_card["panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_column.add_child(route_card["panel"])

	var route_intro := _create_body_label(14, ACCENT_MUTED)
	route_intro.text = "Restore one district at a time. Mandatory rooms reopen the main route; side rooms deepen mastery and hide extra notes."
	route_card["body"].add_child(route_intro)

	var route_scroll := ScrollContainer.new()
	route_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_scroll.custom_minimum_size = Vector2(0, 440)
	route_card["body"].add_child(route_scroll)

	district_list = VBoxContainer.new()
	district_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	district_list.add_theme_constant_override("separation", 12)
	route_scroll.add_child(district_list)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _make_card_style(CARD_FILL, CARD_BORDER, 24))
	content_row.add_child(board_panel)

	var board_shell := Control.new()
	board_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_child(board_shell)

	room_view = RoomViewScript.new()
	room_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	room_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_view.focus_mode = Control.FOCUS_ALL
	board_shell.add_child(room_view)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	dialogue_panel.offset_left = 22
	dialogue_panel.offset_top = 20
	dialogue_panel.offset_right = -220
	dialogue_panel.offset_bottom = 140
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.visible = false
	dialogue_panel.modulate.a = 0.0
	dialogue_panel.add_theme_stylebox_override("panel", _make_card_style(Color("fff8ef"), Color("d9c2a0"), 22))
	board_shell.add_child(dialogue_panel)

	var dialogue_margin := MarginContainer.new()
	dialogue_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_margin.add_theme_constant_override("margin_left", 18)
	dialogue_margin.add_theme_constant_override("margin_top", 14)
	dialogue_margin.add_theme_constant_override("margin_right", 18)
	dialogue_margin.add_theme_constant_override("margin_bottom", 14)
	dialogue_panel.add_child(dialogue_margin)

	var dialogue_body := VBoxContainer.new()
	dialogue_body.add_theme_constant_override("separation", 6)
	dialogue_margin.add_child(dialogue_body)

	dialogue_speaker_label = _create_body_label(13, ACCENT_RUST)
	dialogue_body.add_child(dialogue_speaker_label)

	dialogue_text_label = _create_body_label(17, ACCENT_INK)
	dialogue_body.add_child(dialogue_text_label)

	solve_panel = PanelContainer.new()
	solve_panel.set_anchors_preset(Control.PRESET_CENTER)
	solve_panel.custom_minimum_size = Vector2(360, 0)
	solve_panel.position = Vector2(-180, -72)
	solve_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	solve_panel.visible = false
	solve_panel.modulate.a = 0.0
	solve_panel.add_theme_stylebox_override("panel", _make_card_style(Color("fff4d4"), Color("d3a74b"), 26))
	board_shell.add_child(solve_panel)

	var solve_margin := MarginContainer.new()
	solve_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	solve_margin.add_theme_constant_override("margin_left", 20)
	solve_margin.add_theme_constant_override("margin_top", 16)
	solve_margin.add_theme_constant_override("margin_right", 20)
	solve_margin.add_theme_constant_override("margin_bottom", 16)
	solve_panel.add_child(solve_margin)

	var solve_body := VBoxContainer.new()
	solve_body.add_theme_constant_override("separation", 6)
	solve_margin.add_child(solve_body)

	solve_title_label = _create_body_label(24, ACCENT_INK)
	solve_title_label.text = "Route Restored"
	solve_body.add_child(solve_title_label)

	solve_subtitle_label = _create_body_label(14, ACCENT_MUTED)
	solve_subtitle_label.text = "Pick another room from the map."
	solve_body.add_child(solve_subtitle_label)

	var solve_divider := ColorRect.new()
	solve_divider.custom_minimum_size = Vector2(0, 1)
	solve_divider.color = Color("d3a74b")
	solve_divider.modulate.a = 0.4
	solve_body.add_child(solve_divider)

	solve_record_label = _create_body_label(13, ACCENT_MUTED)
	solve_record_label.text = ""
	solve_body.add_child(solve_record_label)

	solve_replay_button = Button.new()
	solve_replay_button.text = "Replay Solution"
	solve_replay_button.pressed.connect(_play_replay)
	_style_button(solve_replay_button, Color("eaf0e2"), Color("a9c089"), ACCENT_INK)
	solve_body.add_child(solve_replay_button)

	demo_panel = PanelContainer.new()
	demo_panel.set_anchors_preset(Control.PRESET_CENTER)
	demo_panel.custom_minimum_size = Vector2(440, 0)
	demo_panel.position = Vector2(-220, -112)
	demo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_panel.visible = false
	demo_panel.modulate.a = 0.0
	demo_panel.add_theme_stylebox_override("panel", _make_card_style(Color("fff7e4"), Color("c79f55"), 28))
	board_shell.add_child(demo_panel)

	var demo_margin := MarginContainer.new()
	demo_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	demo_margin.add_theme_constant_override("margin_left", 22)
	demo_margin.add_theme_constant_override("margin_top", 18)
	demo_margin.add_theme_constant_override("margin_right", 22)
	demo_margin.add_theme_constant_override("margin_bottom", 18)
	demo_panel.add_child(demo_margin)

	var demo_body := VBoxContainer.new()
	demo_body.add_theme_constant_override("separation", 8)
	demo_margin.add_child(demo_body)

	demo_title_label = _create_body_label(26, ACCENT_INK)
	demo_title_label.text = "Demo Route Complete"
	demo_body.add_child(demo_title_label)

	demo_body_label = _create_body_label(14, ACCENT_MUTED)
	demo_body_label.text = "The first three districts are back in circulation."
	demo_body.add_child(demo_body_label)

	demo_teaser_label = _create_body_label(14, ACCENT_INK)
	demo_teaser_label.text = ""
	demo_body.add_child(demo_teaser_label)

	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_panel.offset_left = 22
	toast_panel.offset_top = -90
	toast_panel.offset_right = -260
	toast_panel.offset_bottom = -22
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	toast_panel.modulate.a = 0.0
	toast_panel.add_theme_stylebox_override("panel", _make_card_style(Color("f5edd8"), Color("ceb48a"), 20))
	board_shell.add_child(toast_panel)

	var toast_margin := MarginContainer.new()
	toast_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_margin.add_theme_constant_override("margin_left", 16)
	toast_margin.add_theme_constant_override("margin_top", 12)
	toast_margin.add_theme_constant_override("margin_right", 16)
	toast_margin.add_theme_constant_override("margin_bottom", 12)
	toast_panel.add_child(toast_margin)

	toast_label = _create_body_label(14, ACCENT_INK)
	toast_margin.add_child(toast_label)

	transition_overlay = ColorRect.new()
	transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.color = Color(0.97, 0.92, 0.82, 0.0)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_shell.add_child(transition_overlay)

	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(360, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_scroll)

	var side_column := VBoxContainer.new()
	side_column.custom_minimum_size = Vector2(336, 0)
	side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_column.add_theme_constant_override("separation", 14)
	side_scroll.add_child(side_column)

	var objective_card: Dictionary = _create_card("Route Objective")
	side_column.add_child(objective_card["panel"])

	objective_label = _create_body_label(20, ACCENT_INK)
	objective_card["body"].add_child(objective_label)

	blurb_label = _create_body_label(15, ACCENT_MUTED)
	objective_card["body"].add_child(blurb_label)

	hint_status_label = _create_body_label(14, ACCENT_RUST)
	objective_card["body"].add_child(hint_status_label)

	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 8)
	objective_card["body"].add_child(hint_row)

	for tier in range(1, 4):
		var button := Button.new()
		button.text = "Hint %d" % tier
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_handle_hint_request.bind(tier))
		_style_button(button, Color("f4ead1"), CARD_BORDER, ACCENT_INK)
		hint_row.add_child(button)
		hint_buttons.append(button)

	hint_text_label = _create_body_label(14, ACCENT_MUTED)
	objective_card["body"].add_child(hint_text_label)

	hint_opening_label = _create_body_label(13, ACCENT_MUTED)
	objective_card["body"].add_child(hint_opening_label)

	hint_opening_button = Button.new()
	hint_opening_button.text = "Play Guided Opening"
	hint_opening_button.pressed.connect(_handle_guided_opening_requested)
	_style_button(hint_opening_button, Color("e5efd8"), Color("a9c089"), ACCENT_INK)
	objective_card["body"].add_child(hint_opening_button)

	var notes_card: Dictionary = _create_card("Town Notes")
	side_column.add_child(notes_card["panel"])

	layer_chip_row = HBoxContainer.new()
	layer_chip_row.add_theme_constant_override("separation", 8)
	notes_card["body"].add_child(layer_chip_row)

	journal_label = _create_body_label(14, ACCENT_INK)
	notes_card["body"].add_child(journal_label)

	stats_label = _create_body_label(14, ACCENT_MUTED)
	notes_card["body"].add_child(stats_label)

	var settings_card: Dictionary = _create_card("Courier Settings")
	side_column.add_child(settings_card["panel"])

	setting_contrast_button = CheckButton.new()
	setting_contrast_button.text = "High Contrast"
	setting_contrast_button.focus_mode = Control.FOCUS_ALL
	_register_scaled_font(setting_contrast_button, 14)
	setting_contrast_button.toggled.connect(_handle_high_contrast_toggled)
	settings_card["body"].add_child(setting_contrast_button)

	setting_motion_button = CheckButton.new()
	setting_motion_button.text = "Reduced Motion"
	setting_motion_button.focus_mode = Control.FOCUS_ALL
	_register_scaled_font(setting_motion_button, 14)
	setting_motion_button.toggled.connect(_handle_reduced_motion_toggled)
	settings_card["body"].add_child(setting_motion_button)

	var colorblind_row := HBoxContainer.new()
	colorblind_row.add_theme_constant_override("separation", 10)
	settings_card["body"].add_child(colorblind_row)

	var colorblind_label := _create_body_label(14, ACCENT_INK)
	colorblind_label.text = "Colorblind Mode"
	colorblind_row.add_child(colorblind_label)

	setting_colorblind_option = OptionButton.new()
	setting_colorblind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_colorblind_option.focus_mode = Control.FOCUS_ALL
	setting_colorblind_option.add_item("None", 0)
	setting_colorblind_option.add_item("Deuteranopia", 1)
	setting_colorblind_option.add_item("Protanopia", 2)
	setting_colorblind_option.add_item("Tritanopia", 3)
	_register_scaled_font(setting_colorblind_option, 13)
	setting_colorblind_option.item_selected.connect(_handle_colorblind_mode_changed)
	colorblind_row.add_child(setting_colorblind_option)

	var font_row := HBoxContainer.new()
	font_row.add_theme_constant_override("separation", 10)
	settings_card["body"].add_child(font_row)

	var font_label := _create_body_label(14, ACCENT_INK)
	font_label.text = "Font Scale"
	font_row.add_child(font_label)

	setting_font_scale_slider = HSlider.new()
	setting_font_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_font_scale_slider.min_value = 0.9
	setting_font_scale_slider.max_value = 1.35
	setting_font_scale_slider.step = 0.05
	setting_font_scale_slider.focus_mode = Control.FOCUS_ALL
	setting_font_scale_slider.value_changed.connect(_handle_font_scale_changed)
	font_row.add_child(setting_font_scale_slider)

	setting_font_scale_value = _create_body_label(13, ACCENT_MUTED)
	setting_font_scale_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	font_row.add_child(setting_font_scale_value)

	var master_volume_row := HBoxContainer.new()
	master_volume_row.add_theme_constant_override("separation", 10)
	settings_card["body"].add_child(master_volume_row)

	var master_volume_label := _create_body_label(14, ACCENT_INK)
	master_volume_label.text = "Master Vol"
	master_volume_row.add_child(master_volume_label)

	setting_master_volume_slider = HSlider.new()
	setting_master_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_master_volume_slider.min_value = -30.0
	setting_master_volume_slider.max_value = 0.0
	setting_master_volume_slider.step = 1.0
	setting_master_volume_slider.focus_mode = Control.FOCUS_ALL
	setting_master_volume_slider.value_changed.connect(_handle_master_volume_changed)
	master_volume_row.add_child(setting_master_volume_slider)

	var sfx_volume_row := HBoxContainer.new()
	sfx_volume_row.add_theme_constant_override("separation", 10)
	settings_card["body"].add_child(sfx_volume_row)

	var sfx_volume_label := _create_body_label(14, ACCENT_INK)
	sfx_volume_label.text = "SFX Vol"
	sfx_volume_row.add_child(sfx_volume_label)

	setting_sfx_volume_slider = HSlider.new()
	setting_sfx_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_sfx_volume_slider.min_value = -30.0
	setting_sfx_volume_slider.max_value = 0.0
	setting_sfx_volume_slider.step = 1.0
	setting_sfx_volume_slider.focus_mode = Control.FOCUS_ALL
	setting_sfx_volume_slider.value_changed.connect(_handle_sfx_volume_changed)
	sfx_volume_row.add_child(setting_sfx_volume_slider)

	input_mode_label = _create_body_label(13, ACCENT_RUST)
	settings_card["body"].add_child(input_mode_label)

	controls_label = _create_body_label(13, ACCENT_MUTED)
	settings_card["body"].add_child(controls_label)

	_build_control_remap_rows(settings_card["body"])

	var reset_controls_button := Button.new()
	reset_controls_button.text = "Reset Controls To Default"
	reset_controls_button.pressed.connect(_handle_reset_controls_pressed)
	_style_button(reset_controls_button, Color("f0e7d4"), CARD_BORDER, ACCENT_INK)
	settings_card["body"].add_child(reset_controls_button)

	var accessibility_card: Dictionary = _create_card("Accessibility")
	side_column.add_child(accessibility_card["panel"])

	var accessibility_info := _create_body_label(13, ACCENT_MUTED)
	accessibility_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accessibility_info.text = "High Contrast: Increases color separation for all game elements.\n\nReduced Motion: Disables animations; transitions play instantly.\n\nFont Scale: Adjusts text size throughout the game.\n\nColorblind Modes: Optimized color palettes for common color vision deficiencies (deuteranopia, protanopia, tritanopia).\n\nVolume Controls: Independent master and SFX volume sliders.\n\nKeyboard Remapping: All controls can be rebound in the Controls section above."
	accessibility_card["body"].add_child(accessibility_info)

	var support_card: Dictionary = _create_card("Steam And Saves")
	side_column.add_child(support_card["panel"])

	steam_status_label = _create_body_label(13, ACCENT_INK)
	support_card["body"].add_child(steam_status_label)

	save_status_label = _create_body_label(13, ACCENT_MUTED)
	support_card["body"].add_child(save_status_label)

	var action_card: Dictionary = _create_card("Courier Tools")
	side_column.add_child(action_card["panel"])

	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 10)
	action_grid.add_theme_constant_override("v_separation", 10)
	action_card["body"].add_child(action_grid)

	_add_action_button(action_grid, "prev_room", "Prev Room", Color("ead8b8"), _cycle_room.bind(-1))
	_add_action_button(action_grid, "next_room", "Next Room", Color("ead8b8"), _cycle_room.bind(1))
	_add_action_button(action_grid, "undo", "Undo", Color("f2e7cf"), _dispatch_room_action.bind({"type": "undo"}))
	_add_action_button(action_grid, "redo", "Redo", Color("f2e7cf"), _dispatch_room_action.bind({"type": "redo"}))
	_add_action_button(action_grid, "reset", "Reset", Color("f7ddd4"), _dispatch_room_action.bind({"type": "reset"}))
	_add_action_button(action_grid, "replay", "Replay", Color("dbead8"), _play_replay)
	_add_action_button(action_grid, "story", "Story Beat", Color("efe2f0"), _show_dialogue_for_current_room)

	if OS.is_debug_build():
		authoring_toggle_button = Button.new()
		authoring_toggle_button.text = "Show Developer Tools"
		authoring_toggle_button.pressed.connect(_toggle_developer_tools)
		_style_button(authoring_toggle_button, Color("ede4f0"), CARD_BORDER, ACCENT_INK)
		action_card["body"].add_child(authoring_toggle_button)

	authoring_dock = AuthoringDockScript.new()
	authoring_dock.custom_minimum_size = Vector2(0, 320)
	authoring_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	authoring_dock.campaign_saved.connect(_handle_authoring_campaign_saved)
	authoring_dock.preview_requested.connect(_handle_authoring_preview_requested)
	authoring_dock.room_load_requested.connect(_handle_authoring_room_load_requested)
	authoring_dock.visible = developer_tools_visible and OS.is_debug_build()
	layout.add_child(authoring_dock)

	footer_label = Label.new()
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_register_scaled_font(footer_label, 13)
	footer_label.add_theme_color_override("font_color", ACCENT_MUTED)
	layout.add_child(footer_label)

	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(280, 0)
	pause_panel.position = Vector2(-140, -120)
	pause_panel.visible = false
	pause_panel.z_index = 50
	pause_panel.add_theme_stylebox_override("panel", _make_card_style(Color("fff8ef"), Color("d6bd96"), 24))
	add_child(pause_panel)

	var pause_margin := MarginContainer.new()
	pause_margin.add_theme_constant_override("margin_left", 20)
	pause_margin.add_theme_constant_override("margin_top", 18)
	pause_margin.add_theme_constant_override("margin_right", 20)
	pause_margin.add_theme_constant_override("margin_bottom", 18)
	pause_panel.add_child(pause_margin)

	var pause_body := VBoxContainer.new()
	pause_body.add_theme_constant_override("separation", 8)
	pause_margin.add_child(pause_body)

	var pause_title := _create_body_label(16, ACCENT_INK)
	pause_title.text = "Paused"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_body.add_child(pause_title)

	pause_resume_button = Button.new()
	pause_resume_button.text = "Resume"
	pause_resume_button.pressed.connect(_toggle_pause)
	_style_button(pause_resume_button, Color("f0e7d4"), CARD_BORDER, ACCENT_INK)
	pause_body.add_child(pause_resume_button)

	var pause_reset_button := Button.new()
	pause_reset_button.text = "Reset Room"
	pause_reset_button.pressed.connect(func(): _toggle_pause(); _dispatch_room_action({"type": "reset"}))
	_style_button(pause_reset_button, Color("f0e7d4"), CARD_BORDER, ACCENT_INK)
	pause_body.add_child(pause_reset_button)

	var pause_hint_button := Button.new()
	pause_hint_button.text = "Hints"
	pause_hint_button.pressed.connect(func(): _toggle_pause(); _pause_reveal_hint())
	_style_button(pause_hint_button, Color("f0e7d4"), CARD_BORDER, ACCENT_INK)
	pause_body.add_child(pause_hint_button)

	var pause_map_button := Button.new()
	pause_map_button.text = "Back to Map"
	pause_map_button.pressed.connect(func(): _toggle_pause(); _scroll_to_route_list())
	_style_button(pause_map_button, Color("f0e7d4"), CARD_BORDER, ACCENT_INK)
	pause_body.add_child(pause_map_button)

	remap_overlay = PanelContainer.new()
	remap_overlay.set_anchors_preset(Control.PRESET_CENTER)
	remap_overlay.custom_minimum_size = Vector2(420, 0)
	remap_overlay.position = Vector2(-210, -90)
	remap_overlay.visible = false
	remap_overlay.z_index = 50
	remap_overlay.add_theme_stylebox_override("panel", _make_card_style(Color("fff8ef"), Color("d6bd96"), 24))
	add_child(remap_overlay)

	var remap_margin := MarginContainer.new()
	remap_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	remap_margin.add_theme_constant_override("margin_left", 20)
	remap_margin.add_theme_constant_override("margin_top", 18)
	remap_margin.add_theme_constant_override("margin_right", 20)
	remap_margin.add_theme_constant_override("margin_bottom", 18)
	remap_overlay.add_child(remap_margin)

	remap_prompt_label = _create_body_label(15, ACCENT_INK)
	remap_prompt_label.text = "Press a key or controller input to bind this action. Press Escape to cancel."
	remap_margin.add_child(remap_prompt_label)

func _register_scaled_font(control: Control, base_size: int, property_name: String = "font_size") -> void:
	control.set_meta("patchwork_font_property", property_name)
	control.set_meta("patchwork_font_base", base_size)
	scalable_controls.append(control)
	control.add_theme_font_size_override(property_name, int(round(base_size * current_font_scale)))

func _create_card(title_text: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_card_style(CARD_FILL, CARD_BORDER, 22))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	var title := Label.new()
	title.text = title_text
	_register_scaled_font(title, 17)
	title.add_theme_color_override("font_color", ACCENT_RUST)
	body.add_child(title)
	card_title_labels.append(title)

	return {"panel": panel, "body": body}

func _create_body_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_register_scaled_font(label, font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _create_metric_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_register_scaled_font(label, 15)
	label.add_theme_color_override("font_color", ACCENT_INK)
	return label

func _make_card_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(radius)
	return style

func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(16)
	return style

func _style_button(button: Button, fill: Color, border: Color, font_color: Color) -> void:
	button.custom_minimum_size = Vector2(0, 42)
	button.focus_mode = Control.FOCUS_ALL
	_register_scaled_font(button, 14)
	button.add_theme_stylebox_override("normal", _make_button_style(fill, border))
	button.add_theme_stylebox_override("hover", _make_button_style(fill.lightened(0.05), border))
	button.add_theme_stylebox_override("pressed", _make_button_style(fill.darkened(0.08), border))
	button.add_theme_stylebox_override("disabled", _make_button_style(fill.darkened(0.12), border.darkened(0.1)))
	button.add_theme_stylebox_override("focus", _make_button_style(fill.lightened(0.02), ACCENT_GOLD))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_disabled_color", ACCENT_MUTED)

func _add_action_button(parent: GridContainer, key: String, text: String, fill: Color, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	_style_button(button, fill, CARD_BORDER, ACCENT_INK)
	parent.add_child(button)
	action_buttons[key] = button

func _build_control_remap_rows(parent: VBoxContainer) -> void:
	var remap_caption := _create_body_label(13, ACCENT_MUTED)
	remap_caption.text = "Remap the core puzzle actions below. Keyboard and controller bindings are stored separately."
	parent.add_child(remap_caption)

	for spec in InputBindings.get_action_specs():
		var action_name := String(spec.get("name", ""))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _make_card_style(Color("fbf3e3"), CARD_BORDER, 16))
		parent.add_child(row)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		row.add_child(margin)

		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 6)
		margin.add_child(body)

		var header := _create_body_label(13, ACCENT_INK)
		header.text = String(spec.get("label", action_name))
		body.add_child(header)

		var description := _create_body_label(12, ACCENT_MUTED)
		description.text = String(spec.get("description", ""))
		body.add_child(description)

		var binding_row := HBoxContainer.new()
		binding_row.add_theme_constant_override("separation", 8)
		body.add_child(binding_row)

		var keyboard_button := Button.new()
		keyboard_button.text = "Keyboard"
		keyboard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keyboard_button.pressed.connect(_start_control_rebind.bind(action_name, "keyboard"))
		_style_button(keyboard_button, Color("f1e6cf"), CARD_BORDER, ACCENT_INK)
		binding_row.add_child(keyboard_button)

		var controller_button := Button.new()
		controller_button.text = "Controller"
		controller_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controller_button.pressed.connect(_start_control_rebind.bind(action_name, "controller"))
		_style_button(controller_button, Color("e2ebdd"), CARD_BORDER, ACCENT_INK)
		binding_row.add_child(controller_button)

		remap_rows[action_name] = {
			"keyboard": keyboard_button,
			"controller": controller_button,
		}

func _bootstrap_input_map() -> void:
	InputBindings.ensure_input_map(profile.get("settings", {}).get("controls", {}))

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

func _prime_controller_focus() -> void:
	if room_view != null:
		room_view.grab_focus()

func _start_control_rebind(action_name: String, source: String) -> void:
	remap_pending_action = action_name
	remap_pending_source = source
	remap_overlay.visible = true
	remap_prompt_label.text = "Listening for %s (%s). Press a key, button, or stick direction. Press Escape to cancel." % [
		InputBindings.get_action_label(action_name),
		source.capitalize(),
	]
	_show_toast("Waiting for a %s binding for %s." % [source, InputBindings.get_action_label(action_name)])

func _cancel_control_rebind() -> void:
	remap_pending_action = ""
	remap_pending_source = "keyboard"
	if remap_overlay != null:
		remap_overlay.visible = false
	_show_toast("Control remap cancelled.")
	_refresh_ui()

func _complete_control_rebind(binding: Dictionary) -> void:
	profile.get("settings", {})["controls"] = InputBindings.set_binding(
		profile.get("settings", {}).get("controls", {}),
		remap_pending_action,
		remap_pending_source,
		binding
	)
	InputBindings.ensure_input_map(profile.get("settings", {}).get("controls", {}))
	SaveRuntime.save_profile(profile)
	var bound_action := remap_pending_action
	var bound_source := remap_pending_source
	remap_pending_action = ""
	remap_pending_source = "keyboard"
	if remap_overlay != null:
		remap_overlay.visible = false
	_show_toast("%s %s binding set to %s." % [
		InputBindings.get_action_label(bound_action),
		bound_source,
		InputBindings.describe_binding(binding),
	])
	_refresh_ui()

func _handle_reset_controls_pressed() -> void:
	profile.get("settings", {})["controls"] = InputBindings.reset_to_defaults()
	InputBindings.ensure_input_map(profile.get("settings", {}).get("controls", {}))
	SaveRuntime.save_profile(profile)
	_show_toast("Controls restored to the default keyboard and controller layout.")
	_refresh_ui()

func _toggle_developer_tools() -> void:
	if not OS.is_debug_build() or authoring_dock == null:
		return
	developer_tools_visible = not developer_tools_visible
	authoring_dock.visible = developer_tools_visible
	if authoring_toggle_button != null:
		authoring_toggle_button.text = "Hide Developer Tools" if developer_tools_visible else "Show Developer Tools"
	_show_toast("Developer tools %s." % ("opened" if developer_tools_visible else "hidden"))

func _get_district_by_id(district_id: String) -> Dictionary:
	for candidate in campaign.get("districts", []):
		if candidate.get("id", "") == district_id:
			return candidate
	return {}

func _get_demo_config() -> Dictionary:
	var demo_config: Variant = campaign.get("demo", {})
	return demo_config if demo_config is Dictionary else {}

func _get_main_campaign_config() -> Dictionary:
	var config: Variant = campaign.get("mainCampaign", {})
	return config if config is Dictionary else {}

func _get_secret_route_config() -> Dictionary:
	var config: Variant = campaign.get("secretRoute", {})
	return config if config is Dictionary else {}

func _get_journal_entries() -> Array:
	var entries: Variant = campaign.get("journalEntries", [])
	return entries if entries is Array else []

func _get_demo_room_ids(key: String) -> Array:
	var ids: Array = []
	var demo_config := _get_demo_config()
	for room_id in demo_config.get(key, []):
		ids.append(String(room_id))
	return ids

func _get_arc_room_ids(config: Dictionary, key: String = "mainRoomIds") -> Array:
	var ids: Array = []
	for room_id in config.get(key, []):
		ids.append(String(room_id))
	return ids

func _requirements_met(required_room_ids: Array) -> bool:
	for room_id_variant in required_room_ids:
		if not _room_solved(String(room_id_variant)):
			return false
	return true

func _get_lock_label(required_room_ids: Array) -> String:
	if required_room_ids.is_empty():
		return ""
	var titles: Array = []
	for room_id_variant in required_room_ids:
		var required_room := ContentLoader.get_room_by_id(campaign, String(room_id_variant))
		var title := String(required_room.get("title", room_id_variant))
		titles.append(title)
	return "Solve: %s" % ", ".join(titles)

func _count_solved_subset(room_ids_subset: Array) -> int:
	var solved := 0
	for room_id in room_ids_subset:
		if _room_solved(String(room_id)):
			solved += 1
	return solved

func _get_rooms_for_district(district_id: String) -> Array:
	var rooms: Array = []
	for candidate in campaign.get("rooms", []):
		if candidate.get("districtId", "") == district_id:
			rooms.append(candidate)
	return rooms

func _room_solved(room_id: String) -> bool:
	return bool(profile.get("rooms", {}).get(room_id, {}).get("solved", false))

func _is_district_unlocked(district: Dictionary) -> bool:
	if SaveRuntime.get_postmark_count(profile, campaign) < int(district.get("unlockPostmarks", 0)):
		return false
	return _requirements_met(district.get("requiresRooms", []))

func _is_room_unlocked(room: Dictionary) -> bool:
	var district := _get_district_by_id(String(room.get("districtId", "")))
	if district.is_empty() or not _is_district_unlocked(district):
		return false
	if not _requirements_met(room.get("requiresRooms", [])):
		return false

	var district_rooms: Array = _get_rooms_for_district(String(room.get("districtId", "")))
	var mandatory_rooms: Array = []
	for candidate in district_rooms:
		if not candidate.get("optional", false):
			mandatory_rooms.append(candidate)

	if room.get("optional", false):
		if not room.get("requiresRooms", []).is_empty():
			return true
		if mandatory_rooms.is_empty():
			return true
		for candidate in mandatory_rooms:
			if _room_solved(String(candidate.get("id", ""))):
				return true
		return false

	var room_index := -1
	for index in range(mandatory_rooms.size()):
		if String(mandatory_rooms[index].get("id", "")) == String(room.get("id", "")):
			room_index = index
			break
	if room_index <= 0:
		return true
	for index in range(room_index):
		if not _room_solved(String(mandatory_rooms[index].get("id", ""))):
			return false
	return true

func _capture_unlock_snapshot() -> Dictionary:
	var unlocked_districts: Array = []
	var unlocked_rooms: Array = []
	for district in campaign.get("districts", []):
		if _is_district_unlocked(district):
			unlocked_districts.append(String(district.get("id", "")))
	for room in campaign.get("rooms", []):
		if _is_room_unlocked(room):
			unlocked_rooms.append(String(room.get("id", "")))
	return {"districts": unlocked_districts, "rooms": unlocked_rooms}

func _is_demo_complete() -> bool:
	var main_room_ids := _get_demo_room_ids("mainRoomIds")
	if main_room_ids.is_empty():
		return false
	return _count_solved_subset(main_room_ids) >= main_room_ids.size()

func _is_main_campaign_complete() -> bool:
	var config := _get_main_campaign_config()
	var main_room_ids := _get_arc_room_ids(config)
	if main_room_ids.is_empty():
		return false
	return _count_solved_subset(main_room_ids) >= main_room_ids.size()

func _is_secret_route_complete() -> bool:
	var config := _get_secret_route_config()
	var route_room_ids := _get_arc_room_ids(config, "roomIds")
	if route_room_ids.is_empty():
		return false
	return _count_solved_subset(route_room_ids) >= route_room_ids.size()

func _should_show_demo_completion(room_id: String) -> bool:
	var demo_config := _get_demo_config()
	if demo_config.is_empty():
		return false
	if String(demo_config.get("finalRoomId", "")) != room_id:
		return false
	return _is_demo_complete()

func _should_show_main_campaign_completion(room_id: String) -> bool:
	var config := _get_main_campaign_config()
	if config.is_empty():
		return false
	if String(config.get("finalRoomId", "")) != room_id:
		return false
	return _is_main_campaign_complete()

func _should_show_secret_route_completion(room_id: String) -> bool:
	var config := _get_secret_route_config()
	if config.is_empty():
		return false
	if String(config.get("finalRoomId", "")) != room_id:
		return false
	return _is_secret_route_complete()

func _cycle_room(delta: int) -> void:
	if room_ids.is_empty() or campaign.is_empty():
		return

	var unlocked_room_ids: Array = []
	for room in campaign.get("rooms", []):
		if _is_room_unlocked(room):
			unlocked_room_ids.append(String(room.get("id", "")))
	if unlocked_room_ids.is_empty():
		unlocked_room_ids = room_ids.duplicate()

	var current_room_id := String(engine.get_room().get("id", ""))
	var current_index := unlocked_room_ids.find(current_room_id)
	if current_room_id == DEV_PROOF_ROOM_ID or current_index == -1:
		current_index = 0 if delta > 0 else unlocked_room_ids.size() - 1
	else:
		current_index = wrapi(current_index + delta, 0, unlocked_room_ids.size())
	_load_room(String(unlocked_room_ids[current_index]), true)

func _load_room(room_id: String, restore_snapshot: bool) -> void:
	if room_id == DEV_PROOF_ROOM_ID:
		var proof_room: Dictionary = dev_rooms.get("threeLayerProofRoom", {})
		if not proof_room.is_empty():
			if playtest_logger != null:
				playtest_logger.abandon_current("proof_room")
			engine.load_preview_room(proof_room)
			last_room_id = DEV_PROOF_ROOM_ID
			last_solved_state = false
			room_view.begin_room_intro()
			_show_dialogue_for_current_room()
			_show_toast("Developer proof room loaded. Use this slice to verify three-sheet routing and active-layer readability.")
			if audio_manager != null:
				audio_manager.play_event("enter")
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
	last_room_id = room_id
	authoring_context_room_id = room_id
	last_solved_state = bool(engine.get_runtime().get("solved", false))
	if playtest_logger != null:
		playtest_logger.begin_room(room)
	profile["lastRoomId"] = room_id
	SaveRuntime.save_profile(profile)
	room_view.begin_room_intro()
	_show_dialogue_for_current_room()
	_start_room_transition()
	if audio_manager != null:
		audio_manager.play_event("enter")
	_refresh_ui()

func _dispatch_room_action(action: Dictionary) -> void:
	if engine == null or engine.get_room().is_empty():
		return
	var previous_runtime: Dictionary = engine.get_runtime().duplicate(true)
	var changed: bool = engine.dispatch(action)
	if not changed:
		return
	dialogue_time_left = minf(dialogue_time_left, 0.18)
	if playtest_logger != null:
		playtest_logger.record_action(action)
		if String(action.get("type", "")) == "reset":
			playtest_logger.record_reset()
	var audio_event := _determine_audio_event(action, previous_runtime, engine.get_runtime())
	if audio_manager != null and not audio_event.is_empty():
		audio_manager.play_event(audio_event)
	_after_state_change(action, previous_runtime)

func _play_replay() -> void:
	var room_id: String = String(engine.get_room().get("id", ""))
	var actions: Array = _get_solution_actions(room_id)
	if engine.start_replay(actions):
		_show_toast("Replaying the saved route. Watch how the layer relationships unfold.")
		_refresh_ui()

func _get_solution_actions(room_id: String) -> Array:
	if room_id == DEV_PROOF_ROOM_ID:
		return solutions.get("threeLayerProofSolution", [])
	var progress: Dictionary = SaveRuntime.get_room_progress(profile, room_id)
	var actions: Array = progress.get("bestSolution", [])
	if actions.is_empty():
		actions = solutions.get("canonicalSolutions", {}).get(room_id, [])
	return actions

func _build_guided_opening_actions(room_id: String) -> Array:
	var solution_actions: Array = _get_solution_actions(room_id)
	if solution_actions.is_empty():
		return []
	var opening_length := mini(4, solution_actions.size())
	return solution_actions.slice(0, opening_length)

func _describe_hint_action(action: Dictionary) -> String:
	match String(action.get("type", "")):
		"move":
			return "Move %s" % String(action.get("direction", ""))
		"switch_layer":
			return "Switch layers"
		"transfer":
			return "Transfer the parcel"
		"wait":
			return "Wait a beat"
		"undo":
			return "Undo"
		"redo":
			return "Redo"
		"reset":
			return "Reset the room"
		_:
			return "Act"

func _handle_guided_opening_requested() -> void:
	if engine == null or _is_preview_runtime():
		return
	var room_id: String = String(engine.get_room().get("id", ""))
	var opening_actions: Array = _build_guided_opening_actions(room_id)
	if opening_actions.is_empty():
		_show_toast("No guided opening is available for this room yet.")
		return
	engine.start_replay(opening_actions)
	_show_toast("Guided opening started. Watch the first moves, then take over from there.")
	_refresh_ui()

func _is_preview_runtime() -> bool:
	return engine != null and String(engine.get_text_state().get("mode", "")) == "preview"

func _handle_hint_request(tier: int) -> void:
	var room: Dictionary = engine.get_room()
	var room_id: String = String(room.get("id", ""))
	if room_id.is_empty() or _is_preview_runtime():
		return
	SaveRuntime.reveal_hint(profile, room_id, tier)
	SaveRuntime.save_profile(profile)
	if playtest_logger != null:
		playtest_logger.record_hint(tier)
	if audio_manager != null:
		audio_manager.play_event("hint")
	_show_toast("Hint %d revealed. The help escalates from reframing to a guided opening." % tier)
	_refresh_ui()

func _handle_authoring_preview_requested(room_data: Dictionary) -> void:
	if engine == null or room_data.is_empty():
		return
	engine.load_preview_room(room_data)
	room_view.begin_room_intro()
	_start_room_transition()
	_show_toast("Previewing draft room %s." % room_data.get("id", ""))
	_refresh_ui()

func _handle_authoring_room_load_requested(room_id: String) -> void:
	if ContentLoader.get_room_by_id(campaign, room_id).is_empty():
		_show_toast("Save the draft first to load it into the campaign runtime.")
		return
	_load_room(room_id, false)

func _handle_authoring_campaign_saved(next_campaign: Dictionary, next_source_campaign: Dictionary, active_room_id: String) -> void:
	campaign = next_campaign.duplicate(true)
	source_campaign = next_source_campaign.duplicate(true)
	engine = EngineScript.new(campaign)
	room_ids = ContentLoader.get_room_order(campaign)
	route_unlock_snapshot = _capture_unlock_snapshot()
	authoring_context_room_id = active_room_id
	_show_toast("Saved authoring changes for %s." % active_room_id)
	_load_room(active_room_id, false)

func _determine_audio_event(action: Dictionary, previous_runtime: Dictionary, current_runtime: Dictionary) -> String:
	match String(action.get("type", "")):
		"move":
			return "push" if _did_push_entity(previous_runtime, current_runtime) else "move"
		"wait":
			return "wait"
		"switch_layer":
			return "switch_layer"
		"transfer":
			return "transfer"
		"undo":
			return "undo"
		"redo":
			return "redo"
		"reset":
			return "reset"
		_:
			return ""

func _did_push_entity(previous_runtime: Dictionary, current_runtime: Dictionary) -> bool:
	var previous_positions := {}
	for entity in previous_runtime.get("entities", []):
		if entity.get("pushable", false):
			previous_positions[entity.get("id", "")] = "%s:%s:%s" % [entity.get("layer", 0), entity.get("x", 0), entity.get("y", 0)]
	for entity in current_runtime.get("entities", []):
		if not entity.get("pushable", false):
			continue
		var entity_id := String(entity.get("id", ""))
		if not previous_positions.has(entity_id):
			continue
		var current_position := "%s:%s:%s" % [entity.get("layer", 0), entity.get("x", 0), entity.get("y", 0)]
		if current_position != String(previous_positions[entity_id]):
			return true
	return false

func _unlock_room_journal_entries(room_id: String) -> Array:
	var unlocked_titles: Array = []
	for entry in _get_journal_entries():
		var unlock_room_ids: Array = entry.get("unlockRoomIds", [])
		if not unlock_room_ids.has(room_id):
			continue
		var entry_id := String(entry.get("id", ""))
		if SaveRuntime.unlock_journal_entry(profile, entry_id):
			unlocked_titles.append(String(entry.get("title", entry_id)))
	return unlocked_titles

func _get_unlocked_journal_entries_for_district(district_id: String) -> Array:
	var unlocked_ids: Array = profile.get("journalEntriesUnlocked", [])
	var entries: Array = []
	for entry in _get_journal_entries():
		var entry_id := String(entry.get("id", ""))
		if not unlocked_ids.has(entry_id):
			continue
		var entry_district := String(entry.get("districtId", ""))
		if not entry_district.is_empty() and entry_district != district_id:
			continue
		entries.append(entry)
	return entries

func _after_state_change(action: Dictionary = {}, previous_runtime: Dictionary = {}) -> void:
	var room: Dictionary = engine.get_room()
	if room.is_empty():
		return

	var room_id: String = String(room.get("id", ""))
	var unlocked_before: Dictionary = route_unlock_snapshot.duplicate(true)
	var was_solved := _room_solved(room_id)
	if not _is_preview_runtime():
		var progress_before: Dictionary = SaveRuntime.get_room_progress(profile, room_id)
		if engine.get_runtime().get("solved", false):
			SaveRuntime.complete_room(profile, room, engine.get_runtime())
			SaveRuntime.unlock_journal(profile, String(room.get("districtId", "")))
			var journal_unlocks := _unlock_room_journal_entries(room_id)
			SaveRuntime.unlock_achievement(profile, String(room.get("achievementId", "")))
			if int(progress_before.get("hintsRevealed", 0)) == 0:
				SaveRuntime.unlock_achievement(profile, "careful-hands")
			if profile.get("journalEntriesUnlocked", []).size() >= _get_journal_entries().size() and not _get_journal_entries().is_empty():
				SaveRuntime.unlock_achievement(profile, "archivist")
			SaveRuntime.set_room_snapshot(profile, room_id, null)
			if not journal_unlocks.is_empty():
				_show_toast("Hidden notes unlocked: %s." % ", ".join(journal_unlocks))
		else:
			SaveRuntime.set_room_snapshot(profile, room_id, engine.get_room_snapshot())
		profile["lastRoomId"] = room_id
		SaveRuntime.save_profile(profile)
		_sync_steam_state()

	route_unlock_snapshot = _capture_unlock_snapshot()
	if bool(engine.get_runtime().get("solved", false)) and not was_solved:
		if playtest_logger != null:
			playtest_logger.complete_room(engine.get_runtime())
		room_view.trigger_solve_flash()
		_show_solve_banner(room)
		_handle_unlock_changes(unlocked_before, route_unlock_snapshot)
		if _should_show_demo_completion(room_id):
			_show_demo_completion(room)
		elif _should_show_main_campaign_completion(room_id):
			_show_main_campaign_completion(room)
		elif _should_show_secret_route_completion(room_id):
			_show_secret_route_completion(room)
		elif not room.get("outro", []).is_empty():
			_show_dialogue_beat(room.get("outro", [])[0], 7.2 if not bool(profile.get("settings", {}).get("reducedMotion", false)) else 4.0)
	elif String(action.get("type", "")) == "reset":
		_show_toast("Room reset. The papers are back in their original alignment.")

	last_solved_state = bool(engine.get_runtime().get("solved", false))
	_refresh_ui()

func _refresh_ui() -> void:
	var room: Dictionary = engine.get_room()
	var runtime: Dictionary = engine.get_runtime()
	room_view.set_accessibility(
		bool(profile.get("settings", {}).get("highContrast", false)),
		bool(profile.get("settings", {}).get("reducedMotion", false))
	)
	room_view.set_colorblind_mode(String(profile.get("settings", {}).get("colorblindMode", "none")))
	room_view.set_room_state(room, runtime)

	var district_id: String = String(room.get("districtId", ""))
	var district: Dictionary = _get_district_by_id(district_id)
	_apply_district_palette(district_id)

	var state: Dictionary = engine.get_text_state()
	var player: Dictionary = state.get("player", {})
	var room_id: String = String(room.get("id", ""))
	var layer_names: Array = state.get("layerNames", [])
	var active_layer: int = int(state.get("activeLayer", 0))
	var is_preview: bool = _is_preview_runtime()
	var progress: Dictionary = SaveRuntime.get_room_progress(profile, room_id) if not is_preview else {}
	var hints_revealed: int = int(progress.get("hintsRevealed", 0)) if not is_preview else 0
	hint_opening_actions = [] if is_preview else _build_guided_opening_actions(room_id)
	var progress_lines := [
		"Postmarks: %d" % SaveRuntime.get_postmark_count(profile, campaign),
		"Solved rooms: %d / %d%s" % [
			SaveRuntime.get_solved_count(profile),
			campaign.get("rooms", []).size(),
			"\nRoute restored" if runtime.get("solved", false) else "",
		],
	]
	var demo_main_room_ids := _get_demo_room_ids("mainRoomIds")
	if not demo_main_room_ids.is_empty():
		progress_lines.append("Demo route: %d / %d main" % [_count_solved_subset(demo_main_room_ids), demo_main_room_ids.size()])
	var main_campaign_config := _get_main_campaign_config()
	var main_route_ids := _get_arc_room_ids(main_campaign_config)
	if not main_route_ids.is_empty():
		progress_lines.append("Main route: %d / %d" % [_count_solved_subset(main_route_ids), main_route_ids.size()])
	var secret_route_config := _get_secret_route_config()
	var secret_route_ids := _get_arc_room_ids(secret_route_config, "roomIds")
	if not secret_route_ids.is_empty():
		progress_lines.append("Secret line: %d / %d" % [_count_solved_subset(secret_route_ids), secret_route_ids.size()])

	title_label.text = room.get("title", "Patchwork Post")
	subtitle_label.text = "%s\n%s" % [
		district.get("title", "Development Preview"),
		district.get("summary", room.get("objective", "Reach the mailbox.")),
	]

	move_label.text = "Moves: %d\nActive layer: %s" % [
		int(state.get("moveCount", 0)),
		String(layer_names[active_layer]) if active_layer >= 0 and active_layer < layer_names.size() else "Layer",
	]
	progress_label.text = "\n".join(progress_lines)
	route_status_label.text = _build_route_status_text(district, room, is_preview)

	objective_label.text = room.get("objective", "Reach the mailbox.")
	blurb_label.text = room.get("blurb", "Restore the route and keep the folds aligned.")
	hint_status_label.text = "Hints revealed: %d / 3" % hints_revealed if not is_preview else "Hints are disabled in the proof room."
	hint_text_label.text = _build_hint_text(room, hints_revealed, is_preview)
	hint_opening_label.text = _build_hint_opening_text(hints_revealed, is_preview)
	hint_opening_button.visible = not is_preview and hints_revealed >= 3
	hint_opening_button.disabled = hint_opening_actions.is_empty() or engine.is_replaying()

	for index in range(hint_buttons.size()):
		var button: Button = hint_buttons[index]
		var tier := index + 1
		button.disabled = is_preview or tier <= hints_revealed
		match tier:
			1:
				button.text = "Shown" if tier <= hints_revealed else "Reframe"
			2:
				button.text = "Shown" if tier <= hints_revealed else "Mechanic"
			3:
				button.text = "Shown" if tier <= hints_revealed else "Opening"

	_rebuild_layer_chips(layer_names, active_layer)
	_rebuild_route_list(room_id)
	journal_label.text = _build_notes_text(room, district, player)
	stats_label.text = _build_stats_text(progress, is_preview)
	_apply_settings_ui()
	_refresh_control_rows()
	input_mode_label.text = "Input mode: %s. Use D-Pad to move focus, A to confirm, and shoulder buttons to cycle focus groups." % ("Controller" if last_input_source == "controller" else "Keyboard")
	controls_label.text = _build_controls_text()
	if steam_status_label != null:
		steam_status_label.text = _build_steam_status_text()
	if save_status_label != null:
		save_status_label.text = _build_save_status_text()

	footer_label.text = _build_footer_text()

	var can_replay: bool = is_preview or not SaveRuntime.get_room_progress(profile, room_id).get("bestSolution", []).is_empty() or solutions.get("canonicalSolutions", {}).has(room_id)
	action_buttons["undo"].disabled = not engine.can_undo()
	action_buttons["redo"].disabled = not engine.can_redo()
	action_buttons["replay"].disabled = not can_replay
	action_buttons["story"].disabled = room.get("intro", []).is_empty()
	if authoring_dock != null and not source_campaign.is_empty():
		var target_room_id: String = room_id if not is_preview else authoring_context_room_id
		var telemetry_summary: Dictionary = playtest_logger.summarize(campaign) if playtest_logger != null else {}
		if target_room_id != authoring_context_room_id:
			authoring_context_room_id = target_room_id
			authoring_dock.set_context(campaign, source_campaign, target_room_id, telemetry_summary)
		else:
			authoring_dock.update_playtest_summary(telemetry_summary)

func _build_hint_text(room: Dictionary, hints_revealed: int, is_preview: bool) -> String:
	if is_preview:
		return room.get("intro", [])[0].get("text", "This room exists to verify three-layer support.") if not room.get("intro", []).is_empty() else "Development proof room."
	if hints_revealed == 0:
		return "Need a nudge? Start with a reframe, then a mechanic read, then a guided opening. The goal is to preserve the aha, not replace it."
	var hint_lines: Array = []
	for index in range(hints_revealed):
		var label := "Reframe"
		if index == 1:
			label = "Mechanic"
		elif index == 2:
			label = "Opening"
		hint_lines.append("%s: %s" % [label, room.get("hintTiers", [])[index]])
	return "\n\n".join(hint_lines)

func _build_hint_opening_text(hints_revealed: int, is_preview: bool) -> String:
	if is_preview:
		return ""
	if hints_revealed < 3:
		return "Reveal the third hint tier to unlock a guided opening replay."
	if hint_opening_actions.is_empty():
		return "No guided opening is available for this room yet."
	var steps: Array = []
	for index in range(hint_opening_actions.size()):
		steps.append("%d. %s" % [index + 1, _describe_hint_action(hint_opening_actions[index])])
	return "Guided opening:\n%s" % "\n".join(steps)

func _build_controls_text() -> String:
	var controls: Dictionary = profile.get("settings", {}).get("controls", {})
	var action_names := ["move_up", "wait_turn", "switch_layer", "transfer_object", "undo_action", "redo_action", "reset_room", "replay_room"]
	var parts: Array = []
	for action_name in action_names:
		var summary := InputBindings.summarize_action_bindings(controls, action_name)
		parts.append("%s: %s | %s" % [
			summary.get("label", action_name),
			summary.get("keyboard", "-"),
			summary.get("controller", "-"),
		])
	return "\n".join(parts)

func _build_footer_text() -> String:
	var focus_hint := "Shoulder buttons cycle UI focus." if last_input_source == "controller" else "Tab cycles focus between the board and menus."
	return "%s Use the D-Pad for menu navigation, or return focus to the board to move through the puzzle. F8 opens the proof room and F9 toggles developer tools in debug builds." % focus_hint

func _refresh_control_rows() -> void:
	var controls: Dictionary = profile.get("settings", {}).get("controls", {})
	for action_name in remap_rows.keys():
		var summary := InputBindings.summarize_action_bindings(controls, String(action_name))
		var row: Dictionary = remap_rows[action_name]
		if row.has("keyboard") and row["keyboard"] != null:
			row["keyboard"].text = "Keyboard: %s" % summary.get("keyboard", "-")
		if row.has("controller") and row["controller"] != null:
			row["controller"].text = "Controller: %s" % summary.get("controller", "-")

func _build_steam_status_text() -> String:
	var provider := String(steam_status.get("provider", "Local Preview"))
	var pending := SaveRuntime.get_pending_steam_achievements(profile).size()
	var availability := "Connected" if bool(steam_status.get("available", false)) else "Offline stub"
	return "Steam runtime: %s\nAchievement sync: %s\nPending unlocks: %d\nInput manifest: %s" % [
		provider,
		availability,
		pending,
		String(steam_status.get("manifestPath", "steam/input/patchwork-post-steam-input.json")),
	]

func _build_save_status_text() -> String:
	var diagnostics := SaveRuntime.get_storage_diagnostics(profile)
	return "Build channel: %s\nContent version: %s\nCloud slot: %s\nDemo carryover detected: %s" % [
		diagnostics.get("buildChannel", "full"),
		diagnostics.get("contentVersion", SaveRuntime.CONTENT_VERSION),
		diagnostics.get("cloudSlot", "patchwork-post-profile"),
		"Yes" if diagnostics.get("hasDemoCarryover", false) else "No",
	]

func _build_route_status_text(district: Dictionary, room: Dictionary, is_preview: bool) -> String:
	if is_preview:
		return "Preview room\nNot part of progression"
	if room.get("secret", false):
		return "Secret route\nHidden mastery"
	if room.get("optional", false):
		var lock_label := _get_lock_label(room.get("requiresRooms", []))
		return "Side route\n%s" % ("Optional mastery" if lock_label.is_empty() else lock_label)
	var district_rooms := _get_rooms_for_district(String(room.get("districtId", "")))
	var solved_main := 0
	var main_total := 0
	for candidate in district_rooms:
		if candidate.get("optional", false):
			continue
		main_total += 1
		if _room_solved(String(candidate.get("id", ""))):
			solved_main += 1
	var status_text := "%s\nMain route %d / %d" % [district.get("subtitle", "Route status"), solved_main, main_total]
	var required_room_ids: Array = room.get("requiresRooms", [])
	if not required_room_ids.is_empty():
		status_text += "\n%s" % _get_lock_label(required_room_ids)
	return status_text

func _build_notes_text(room: Dictionary, district: Dictionary, player: Dictionary) -> String:
	var intro_line := ""
	if not room.get("intro", []).is_empty():
		var intro_beat: Dictionary = room.get("intro", [])[0]
		intro_line = "%s: %s" % [intro_beat.get("speaker", "Guide"), intro_beat.get("text", "")]
	var lines: Array = [intro_line, String(district.get("journalBody", "The town still reads like folded paper."))]
	var current_district_id := String(room.get("districtId", ""))
	var hidden_entries := _get_unlocked_journal_entries_for_district(current_district_id)
	var unlocked_ids: Array = profile.get("journalEntriesUnlocked", [])
	var total_district_entries := 0
	var unlocked_district_count := 0
	for entry in _get_journal_entries():
		var entry_district := String(entry.get("districtId", ""))
		if entry_district == current_district_id or (entry_district.is_empty() and current_district_id.is_empty()):
			total_district_entries += 1
			if unlocked_ids.has(String(entry.get("id", ""))):
				unlocked_district_count += 1
	if not hidden_entries.is_empty() or total_district_entries > 0:
		var hidden_lines: Array = []
		for entry in hidden_entries:
			hidden_lines.append("%s: %s" % [entry.get("title", "Margin Note"), entry.get("body", "")])
		var undiscovered := total_district_entries - unlocked_district_count
		for i in range(undiscovered):
			hidden_lines.append("??? — A hidden thread awaits...")
		if total_district_entries > 0:
			hidden_lines.append("Journal entries: %d of %d discovered" % [unlocked_district_count, total_district_entries])
		if not hidden_lines.is_empty():
			lines.append("Hidden threads:\n%s" % "\n\n".join(hidden_lines))
	lines.append("Courier position: (%d, %d), facing %s." % [
		int(player.get("x", 0)),
		int(player.get("y", 0)),
		player.get("facing", "right"),
	])
	return "\n\n".join(lines)

func _build_stats_text(progress: Dictionary, is_preview: bool) -> String:
	if is_preview:
		return "Development-only room.\nUse it to verify three-sheet routing, active-layer animation, and overlay clarity without progression pressure."
	return "Attempts: %d\nBest moves: %s\nHints used: %d\nSolved: %s" % [
		int(progress.get("attempts", 0)),
		"-" if progress.get("bestMoves", null) == null else str(progress.get("bestMoves")),
		int(progress.get("hintsRevealed", 0)),
		"Yes" if progress.get("solved", false) else "No",
	]

func _rebuild_layer_chips(layer_names: Array, active_layer: int) -> void:
	for child in layer_chip_row.get_children():
		child.queue_free()

	for index in range(layer_names.size()):
		var chip := PanelContainer.new()
		var fill := Color("f7eedb") if index == active_layer else Color("efe3c8")
		var border := ACCENT_GOLD if index == active_layer else CARD_BORDER
		chip.add_theme_stylebox_override("panel", _make_card_style(fill, border, 12))
		layer_chip_row.add_child(chip)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 6)
		chip.add_child(margin)

		var label := Label.new()
		label.text = "L%d %s%s" % [index + 1, String(layer_names[index]), " (Active)" if index == active_layer else ""]
		_register_scaled_font(label, 12)
		label.add_theme_color_override("font_color", ACCENT_INK if index == active_layer else ACCENT_MUTED)
		margin.add_child(label)

func _apply_settings_ui() -> void:
	if setting_contrast_button != null:
		setting_contrast_button.set_block_signals(true)
		setting_contrast_button.button_pressed = bool(profile.get("settings", {}).get("highContrast", false))
		setting_contrast_button.set_block_signals(false)
	if setting_motion_button != null:
		setting_motion_button.set_block_signals(true)
		setting_motion_button.button_pressed = bool(profile.get("settings", {}).get("reducedMotion", false))
		setting_motion_button.set_block_signals(false)
	if setting_colorblind_option != null:
		setting_colorblind_option.set_block_signals(true)
		var cb_mode := String(profile.get("settings", {}).get("colorblindMode", "none"))
		var cb_modes: Array = ["none", "deuteranopia", "protanopia", "tritanopia"]
		setting_colorblind_option.selected = cb_modes.find(cb_mode) if cb_modes.has(cb_mode) else 0
		setting_colorblind_option.set_block_signals(false)
	if setting_font_scale_slider != null:
		setting_font_scale_slider.set_block_signals(true)
		setting_font_scale_slider.value = float(profile.get("settings", {}).get("fontScale", 1.0))
		setting_font_scale_slider.set_block_signals(false)
	if setting_font_scale_value != null:
		setting_font_scale_value.text = "%d%%" % int(round(float(profile.get("settings", {}).get("fontScale", 1.0)) * 100.0))
	if setting_master_volume_slider != null:
		setting_master_volume_slider.set_block_signals(true)
		setting_master_volume_slider.value = float(profile.get("settings", {}).get("masterVolume", 0.0))
		setting_master_volume_slider.set_block_signals(false)
	if setting_sfx_volume_slider != null:
		setting_sfx_volume_slider.set_block_signals(true)
		setting_sfx_volume_slider.value = float(profile.get("settings", {}).get("sfxVolume", 0.0))
		setting_sfx_volume_slider.set_block_signals(false)

func _apply_profile_settings() -> void:
	current_font_scale = clampf(float(profile.get("settings", {}).get("fontScale", 1.0)), 0.9, 1.35)
	InputBindings.ensure_input_map(profile.get("settings", {}).get("controls", {}))
	for control in scalable_controls:
		if control == null or not is_instance_valid(control):
			continue
		var property_name := String(control.get_meta("patchwork_font_property", "font_size"))
		var base_size := int(control.get_meta("patchwork_font_base", 14))
		control.add_theme_font_size_override(property_name, int(round(base_size * current_font_scale)))
	room_view.set_accessibility(
		bool(profile.get("settings", {}).get("highContrast", false)),
		bool(profile.get("settings", {}).get("reducedMotion", false))
	)
	room_view.set_colorblind_mode(String(profile.get("settings", {}).get("colorblindMode", "none")))
	if audio_manager != null:
		audio_manager.set_master_volume_db(float(profile.get("settings", {}).get("masterVolume", 0.0)))
		audio_manager.set_sfx_volume_db(float(profile.get("settings", {}).get("sfxVolume", 0.0)))
	_apply_settings_ui()

func _sync_steam_state() -> void:
	if steam_bridge == null:
		return
	var synced_ids: Array = steam_bridge.sync_pending_achievements(profile)
	for achievement_id in synced_ids:
		SaveRuntime.mark_steam_achievement_synced(profile, String(achievement_id))
	if not synced_ids.is_empty():
		SaveRuntime.save_profile(profile)

func _handle_high_contrast_toggled(enabled: bool) -> void:
	profile.get("settings", {})["highContrast"] = enabled
	SaveRuntime.save_profile(profile)
	_apply_profile_settings()
	_refresh_ui()

func _handle_reduced_motion_toggled(enabled: bool) -> void:
	profile.get("settings", {})["reducedMotion"] = enabled
	SaveRuntime.save_profile(profile)
	_apply_profile_settings()
	_refresh_ui()

func _handle_font_scale_changed(value: float) -> void:
	profile.get("settings", {})["fontScale"] = value
	SaveRuntime.save_profile(profile)
	_apply_profile_settings()
	_refresh_ui()

func _handle_master_volume_changed(db: float) -> void:
	profile.get("settings", {})["masterVolume"] = db
	SaveRuntime.save_profile(profile)
	if audio_manager != null:
		audio_manager.set_master_volume_db(db)

func _handle_sfx_volume_changed(db: float) -> void:
	profile.get("settings", {})["sfxVolume"] = db
	SaveRuntime.save_profile(profile)
	if audio_manager != null:
		audio_manager.set_sfx_volume_db(db)

func _toggle_pause() -> void:
	if pause_panel == null:
		return
	pause_panel.visible = not pause_panel.visible
	if pause_panel.visible and pause_resume_button != null:
		pause_resume_button.grab_focus()
	elif not pause_panel.visible:
		room_view.grab_focus()

func _scroll_to_route_list() -> void:
	if district_list != null and district_list.get_child_count() > 0:
		district_list.get_child(0).grab_focus()

func _pause_reveal_hint() -> void:
	var room: Dictionary = engine.get_room()
	var room_id := String(room.get("id", ""))
	var progress := SaveRuntime.get_room_progress(profile, room_id)
	var next_tier := int(progress.get("hintsRevealed", 0)) + 1
	_handle_hint_request(next_tier)

func _handle_colorblind_mode_changed(index: int) -> void:
	var modes: Array = ["none", "deuteranopia", "protanopia", "tritanopia"]
	var mode: String = String(modes[clampi(index, 0, modes.size() - 1)])
	profile.get("settings", {})["colorblindMode"] = mode
	SaveRuntime.save_profile(profile)
	_apply_profile_settings()
	_refresh_ui()

func _apply_district_palette(district_id: String) -> void:
	var accent := ACCENT_RUST
	var secondary := ACCENT_MUTED
	match district_id:
		"mailroom":
			accent = Color("c36b4a")
		"market":
			accent = Color("b35b56")
		"greenhouse":
			accent = Color("6b9a5d")
		"clocktower":
			accent = Color("5f7999")
		"theater":
			accent = Color("6f5d82")
		"rooftops":
			accent = Color("c58f2d")
		"attic":
			accent = Color("8b6b4e")
		_:
			accent = ACCENT_RUST
	eyebrow_label.add_theme_color_override("font_color", accent)
	route_status_label.add_theme_color_override("font_color", accent)
	for label in card_title_labels:
		if label != null and is_instance_valid(label):
			label.add_theme_color_override("font_color", accent)
	subtitle_label.add_theme_color_override("font_color", secondary)

func _rebuild_route_list(current_room_id: String) -> void:
	if district_list == null:
		return
	for child in district_list.get_children():
		child.queue_free()
	route_buttons.clear()

	for district in campaign.get("districts", []):
		var unlocked := _is_district_unlocked(district)
		var rooms := _get_rooms_for_district(String(district.get("id", "")))
		var solved_count := 0
		for room in rooms:
			if _room_solved(String(room.get("id", ""))):
				solved_count += 1

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_card_style(
			Color("fff6e8") if unlocked else Color("efe5d4"),
			CARD_BORDER if unlocked else Color("cbb79a"),
			18
		))
		district_list.add_child(card)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 12)
		card.add_child(margin)

		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		margin.add_child(body)

		var title := _create_body_label(16, ACCENT_INK)
		title.text = "%s%s" % [district.get("title", "District"), "" if unlocked else " (Locked)"]
		body.add_child(title)

		var subtitle := _create_body_label(12, ACCENT_MUTED)
		subtitle.text = district.get("subtitle", "")
		body.add_child(subtitle)

		var summary := _create_body_label(12, ACCENT_MUTED)
		summary.text = district.get("summary", "")
		body.add_child(summary)

		var badge := _create_body_label(12, ACCENT_RUST if unlocked else ACCENT_MUTED)
		var district_lock := _get_lock_label(district.get("requiresRooms", []))
		if unlocked:
			badge.text = "%d/%d rooms solved" % [solved_count, rooms.size()]
		elif not district_lock.is_empty():
			badge.text = district_lock
		else:
			badge.text = "Need %d postmarks" % int(district.get("unlockPostmarks", 0))
		body.add_child(badge)

		var room_list := VBoxContainer.new()
		room_list.add_theme_constant_override("separation", 6)
		body.add_child(room_list)

		for room in rooms:
			var button := Button.new()
			var room_id := String(room.get("id", ""))
			var room_unlocked := unlocked and _is_room_unlocked(room)
			var room_solved := _room_solved(room_id)
			var is_secret: bool = room.get("secret", false)
			var is_optional: bool = room.get("optional", false)
			var room_lock := _get_lock_label(room.get("requiresRooms", []))

			var icon := ""
			if is_secret:
				icon = "★ " if room_solved else "☆ "
			elif is_optional:
				icon = "◆ " if room_solved else "◇ "
			else:
				icon = "● " if room_solved else ("◌ " if not room_unlocked else "○ ")
			var suffix := ""
			if room_solved:
				suffix = " ✓"
			elif not room_unlocked and not room_lock.is_empty():
				suffix = " (%s)" % room_lock

			button.text = "%s%s%s" % [icon, room.get("title", room_id), suffix]
			button.disabled = not room_unlocked
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var fill: Color
			if not room_unlocked:
				fill = Color("e9decd")
			elif room_id == current_room_id:
				fill = Color("f7eed6")
			elif room_solved:
				fill = Color("e8f0d6") if (is_optional or is_secret) else Color("eef3df")
			else:
				fill = Color("f5e8d0") if (is_optional or is_secret) else Color("f4ead1")
			var border := ACCENT_GOLD if room_id == current_room_id else (ACCENT_GREEN if room_solved else CARD_BORDER)
			_style_button(button, fill, border, ACCENT_INK)
			button.pressed.connect(_load_room.bind(room_id, true))
			room_list.add_child(button)
			route_buttons[room_id] = button

func _start_room_transition() -> void:
	transition_time_left = 0.42 if not bool(profile.get("settings", {}).get("reducedMotion", false)) else 0.08
	transition_overlay.visible = true

func _show_dialogue_for_current_room() -> void:
	if engine == null:
		return
	var room: Dictionary = engine.get_room()
	if room.is_empty() or room.get("intro", []).is_empty():
		dialogue_panel.visible = false
		dialogue_time_left = 0.0
		return
	_show_dialogue_beat(room.get("intro", [])[0])

func _show_dialogue_beat(beat: Dictionary, duration: float = -1.0) -> void:
	if beat.is_empty():
		return
	dialogue_speaker_label.text = String(beat.get("speaker", "Guide")).to_upper()
	dialogue_text_label.text = String(beat.get("text", ""))
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var default_duration := 6.0 if not bool(profile.get("settings", {}).get("reducedMotion", false)) else 3.0
	dialogue_time_left = duration if duration > 0.0 else default_duration

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_time_left = 3.2 if not bool(profile.get("settings", {}).get("reducedMotion", false)) else 2.2

func _show_solve_banner(room: Dictionary) -> void:
	var reduced_motion := bool(profile.get("settings", {}).get("reducedMotion", false))
	solve_title_label.text = "Route Restored"
	solve_subtitle_label.text = "%s is back in circulation." % room.get("title", "The route")

	var room_id: String = String(room.get("id", ""))
	var progress: Dictionary = SaveRuntime.get_room_progress(profile, room_id)
	var move_count: int = int(engine.get_runtime().get("moveCount", 0))
	var best_moves = progress.get("bestMoves", null)
	var hints_revealed: int = int(progress.get("hintsRevealed", 0))

	var move_text := "Solved in %d move%s" % [move_count, "s" if move_count != 1 else ""]
	if best_moves != null and int(best_moves) == move_count:
		move_text += "  \u2022  New best!"
	var hint_text := "No hints used" if hints_revealed == 0 else "%d hint%s used" % [hints_revealed, "s" if hints_revealed != 1 else ""]
	solve_record_label.text = "%s\n%s" % [move_text, hint_text]

	solve_panel.visible = true
	solve_panel.modulate.a = 0.0
	solve_time_left = 4.0 if not reduced_motion else 2.5
	if audio_manager != null:
		audio_manager.play_event("solve")

func _show_special_completion_panel(ending: Dictionary, default_title: String, default_subtitle: String, default_body: String, teaser_lines: Array = []) -> void:
	if demo_panel == null:
		return
	demo_title_label.text = String(ending.get("title", default_title))
	var subtitle := String(ending.get("subtitle", default_subtitle))
	var body := String(ending.get("body", default_body))
	demo_body_label.text = "%s\n\n%s" % [subtitle, body]
	var teaser_text := ""
	if not teaser_lines.is_empty():
		teaser_text = "Ahead:\n%s" % "\n".join(teaser_lines)
	demo_teaser_label.text = teaser_text
	demo_panel.visible = true
	demo_panel.modulate.a = 0.0
	demo_time_left = 8.0 if not bool(profile.get("settings", {}).get("reducedMotion", false)) else 4.8

	var ending_beat: Dictionary = ending.get("beat", {})
	if not ending_beat.is_empty():
		_show_dialogue_beat(ending_beat, 8.6 if not bool(profile.get("settings", {}).get("reducedMotion", false)) else 4.4)

func _show_demo_completion(room: Dictionary) -> void:
	var demo_config := _get_demo_config()
	if demo_config.is_empty():
		return
	var teaser_lines: Array = []
	for teaser_line in demo_config.get("teaserLines", []):
		teaser_lines.append(String(teaser_line))
	_show_special_completion_panel(
		demo_config.get("ending", {}),
		"Demo Route Complete",
		"%s completes the public festival-route slice." % room.get("title", "This room"),
		"The next districts twist the same rules into delayed echoes, mirrored shadows, and full mixed-mechanic routes.",
		teaser_lines
	)

func _show_main_campaign_completion(room: Dictionary) -> void:
	var config := _get_main_campaign_config()
	if config.is_empty():
		return
	var teaser_lines: Array = []
	var secret_config := _get_secret_route_config()
	for required_room in secret_config.get("requiredRoomIds", []):
		var secret_room := ContentLoader.get_room_by_id(campaign, String(required_room))
		if not secret_room.is_empty() and not _room_solved(String(required_room)):
			teaser_lines.append("Unsolved secret route piece: %s" % secret_room.get("title", String(required_room)))
	_show_special_completion_panel(
		config.get("ending", {}),
		"Festival Line Restored",
		"%s reconnects the rooftop delivery lane." % room.get("title", "This room"),
		"The festival line is back. Optional margin notes can still be traced into the hidden attic route.",
		teaser_lines
	)

func _show_secret_route_completion(room: Dictionary) -> void:
	var config := _get_secret_route_config()
	if config.is_empty():
		return
	_show_special_completion_panel(
		config.get("ending", {}),
		"Secret Line Complete",
		"%s restores the final hidden route above the town." % room.get("title", "This room"),
		"You found the attic line and tied the whole folded town together.",
		[]
	)

func _handle_unlock_changes(before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
	var new_districts: Array = []
	for district_id in after_snapshot.get("districts", []):
		if not before_snapshot.get("districts", []).has(district_id):
			new_districts.append(district_id)
	var new_rooms: Array = []
	for room_id in after_snapshot.get("rooms", []):
		if not before_snapshot.get("rooms", []).has(room_id):
			new_rooms.append(room_id)

	if not new_districts.is_empty():
		var district := _get_district_by_id(String(new_districts[0]))
		_show_toast("District unlocked: %s. A fresh route sheet is ready on the map." % district.get("title", "New district"))
	elif not new_rooms.is_empty():
		var unlocked_room := ContentLoader.get_room_by_id(campaign, String(new_rooms[0]))
		_show_toast("New route unlocked: %s." % unlocked_room.get("title", "Room"))

func _update_overlay_state(delta: float) -> void:
	var reduced_motion := bool(profile.get("settings", {}).get("reducedMotion", false))
	if transition_overlay != null:
		if transition_time_left > 0.0:
			transition_time_left = maxf(0.0, transition_time_left - delta)
			var progress := transition_time_left / (0.08 if reduced_motion else 0.42)
			transition_overlay.color.a = progress * 0.48
		else:
			transition_overlay.color.a = 0.0
			transition_overlay.visible = false

	if dialogue_panel != null:
		if dialogue_time_left > 0.0:
			dialogue_time_left = maxf(0.0, dialogue_time_left - delta)
			dialogue_panel.visible = true
			dialogue_panel.modulate.a = minf(1.0, dialogue_panel.modulate.a + delta * (10.0 if reduced_motion else 6.0))
		else:
			dialogue_panel.modulate.a = maxf(0.0, dialogue_panel.modulate.a - delta * (18.0 if reduced_motion else 7.0))
			dialogue_panel.visible = dialogue_panel.modulate.a > 0.01

	if toast_panel != null:
		if toast_time_left > 0.0:
			toast_time_left = maxf(0.0, toast_time_left - delta)
			toast_panel.visible = true
			toast_panel.modulate.a = minf(1.0, toast_panel.modulate.a + delta * 8.0)
		else:
			toast_panel.modulate.a = maxf(0.0, toast_panel.modulate.a - delta * 8.0)
			toast_panel.visible = toast_panel.modulate.a > 0.01

	if solve_panel != null:
		if solve_time_left > 0.0:
			solve_time_left = maxf(0.0, solve_time_left - delta)
			solve_panel.visible = true
			solve_panel.modulate.a = minf(1.0, solve_panel.modulate.a + delta * 7.0)
		else:
			solve_panel.modulate.a = maxf(0.0, solve_panel.modulate.a - delta * 8.0)
			solve_panel.visible = solve_panel.modulate.a > 0.01

	if demo_panel != null:
		if demo_time_left > 0.0:
			demo_time_left = maxf(0.0, demo_time_left - delta)
			demo_panel.visible = true
			demo_panel.modulate.a = minf(1.0, demo_panel.modulate.a + delta * 6.0)
		else:
			demo_panel.modulate.a = maxf(0.0, demo_panel.modulate.a - delta * 6.0)
			demo_panel.visible = demo_panel.modulate.a > 0.01
