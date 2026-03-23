class_name PatchworkRoomAuthoringDock
extends PanelContainer

signal preview_requested(room_data: Dictionary)
signal room_load_requested(room_id: String)
signal campaign_saved(campaign_index: Dictionary, source_campaign: Dictionary, active_room_id: String)

const Repository = preload("res://scripts/core/content_repository.gd")
const Validator = preload("res://scripts/core/patchwork_validator.gd")
const PlaytestLoggerScript = preload("res://scripts/tools/playtest_logger.gd")
const DOCK_FILL := Color("fcf6ea")
const DOCK_BORDER := Color("cbb293")
const CARD_FILL := Color("fff9ef")
const CARD_BORDER := Color("d7c2a2")
const INK := Color("433029")
const MUTED := Color("796152")

var campaign_index: Dictionary = {}
var source_campaign: Dictionary = {}
var playtest_summary: Dictionary = {}
var draft_room: Dictionary = {}
var loaded_source_room_id := ""
var visible_layers: Array = []
var validation_report: Dictionary = {}
var suppress_form_events := false
var selected_entity_index := -1
var selected_switch_index := -1
var selected_door_index := -1
var selected_routing_index := -1
var current_tool := "tile"
var current_brush := "."

var status_label: Label
var live_preview_button: CheckButton
var room_tree: Tree
var editor_tabs: TabContainer
var layer_selector: OptionButton
var tool_selector: OptionButton
var tile_brush_selector: OptionButton
var layer_visibility_row: HBoxContainer
var layer_grid_container: VBoxContainer
var structure_width_spin: SpinBox
var structure_height_spin: SpinBox
var layer_id_edit: LineEdit
var layer_name_edit: LineEdit
var metadata_room_id_edit: LineEdit
var metadata_title_edit: LineEdit
var metadata_district_option: OptionButton
var metadata_optional_button: CheckButton
var metadata_postmarks_spin: SpinBox
var metadata_unlock_spin: SpinBox
var metadata_objective_edit: TextEdit
var metadata_blurb_edit: TextEdit
var intro_speaker_edit: LineEdit
var intro_text_edit: TextEdit
var hint_edits: Array = []
var balance_lesson_edit: LineEdit
var balance_difficulty_spin: SpinBox
var balance_expected_spin: SpinBox
var balance_misread_edit: TextEdit
var entity_list: ItemList
var entity_id_edit: LineEdit
var entity_type_option: OptionButton
var entity_pushable_button: CheckButton
var entity_solid_button: CheckButton
var entity_mirror_option: OptionButton
var entity_projection_layer_option: OptionButton
var entity_projection_dx_spin: SpinBox
var entity_projection_dy_spin: SpinBox
var switch_list: ItemList
var switch_id_edit: LineEdit
var switch_sticky_button: CheckButton
var door_list: ItemList
var door_id_edit: LineEdit
var door_switch_links_box: VBoxContainer
var routing_list: ItemList
var routing_id_edit: LineEdit
var routing_direction_option: OptionButton
var routing_distance_spin: SpinBox
var routing_apply_switch_button: CheckButton
var routing_apply_transfer_button: CheckButton
var routing_apply_projection_button: CheckButton
var validation_label: RichTextLabel
var balance_tree: Tree
var playtest_tree: Tree
var playtest_label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", _make_card_style(DOCK_FILL, DOCK_BORDER, 18))
	_build_ui()

func set_context(next_campaign_index: Dictionary, next_source_campaign: Dictionary, active_room_id: String, next_playtest_summary: Dictionary) -> void:
	campaign_index = next_campaign_index.duplicate(true)
	source_campaign = next_source_campaign.duplicate(true)
	playtest_summary = next_playtest_summary.duplicate(true)
	if source_campaign.is_empty():
		source_campaign = Repository.load_source_campaign()
	if source_campaign.is_empty():
		return
	_rebuild_room_tree()
	_rebuild_balance_tree()
	_rebuild_playtest_tree()
	if active_room_id.is_empty():
		active_room_id = String(source_campaign.get("rooms", [{}])[0].get("id", ""))
	if draft_room.is_empty() or loaded_source_room_id != active_room_id:
		load_room_for_edit(active_room_id)
	else:
		_rebuild_balance_tree()
		_rebuild_playtest_tree()

func update_playtest_summary(next_playtest_summary: Dictionary) -> void:
	playtest_summary = next_playtest_summary.duplicate(true)
	_rebuild_balance_tree()
	_rebuild_playtest_tree()

func load_room_for_edit(room_id: String) -> void:
	if source_campaign.is_empty():
		return
	var room := Repository.get_room_source_by_id(source_campaign, room_id)
	if room.is_empty():
		return
	loaded_source_room_id = room_id
	draft_room = _normalize_room(room)
	visible_layers = []
	for _layer in draft_room.get("layers", []):
		visible_layers.append(true)
	selected_entity_index = 0 if not draft_room.get("entities", []).is_empty() else -1
	selected_switch_index = 0 if not draft_room.get("switches", []).is_empty() else -1
	selected_door_index = 0 if not draft_room.get("doors", []).is_empty() else -1
	selected_routing_index = 0 if not draft_room.get("routingStamps", []).is_empty() else -1
	validation_report = Validator.validate_room_report(draft_room)
	_load_draft_into_forms()
	_rebuild_layer_controls()
	_rebuild_entities_section()
	_rebuild_switch_section()
	_rebuild_door_section()
	_rebuild_routing_section()
	_refresh_validation_view()
	_rebuild_balance_tree()
	_rebuild_playtest_tree()
	status_label.text = "Editing %s" % room_id
	if live_preview_button.button_pressed:
		preview_requested.emit(draft_room.duplicate(true))

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

func _create_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_card_style(CARD_FILL, CARD_BORDER, 16))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	return panel

func _create_subsection_card(parent: Control, title_text: String) -> VBoxContainer:
	var card := _create_card()
	parent.add_child(card)
	var body: VBoxContainer = card.get_child(0).get_child(0)
	body.add_child(_make_section_label(title_text))
	return body

func _make_section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", INK)
	return label

func _add_labeled_line_edit(parent: Control, label_text: String, changed_callback: Callable) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", MUTED)
	parent.add_child(label)
	var line_edit := LineEdit.new()
	line_edit.text_changed.connect(changed_callback)
	parent.add_child(line_edit)
	return line_edit

func _add_labeled_text_edit(parent: Control, label_text: String, min_height: float, changed_callback: Callable) -> TextEdit:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", MUTED)
	parent.add_child(label)
	var text_edit := TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, min_height)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(changed_callback)
	parent.add_child(text_edit)
	return text_edit

func _add_labeled_spin(parent: Control, label_text: String, min_value: float, max_value: float, step: float, changed_callback: Callable) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", MUTED)
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value_changed.connect(changed_callback)
	parent.add_child(spin)
	return spin

func _add_labeled_check(parent: Control, label_text: String, changed_callback: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = label_text
	button.toggled.connect(changed_callback)
	parent.add_child(button)
	return button

func _add_labeled_option(parent: Control, label_text: String, changed_callback: Callable) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", MUTED)
	parent.add_child(label)
	var option := OptionButton.new()
	option.item_selected.connect(changed_callback)
	parent.add_child(option)
	return option

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	body.add_child(toolbar)

	var new_button := Button.new()
	new_button.text = "New Room"
	new_button.pressed.connect(_handle_new_room)
	toolbar.add_child(new_button)

	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(_handle_duplicate_room)
	toolbar.add_child(duplicate_button)

	var save_button := Button.new()
	save_button.text = "Save Draft"
	save_button.pressed.connect(_handle_save_room)
	toolbar.add_child(save_button)

	var preview_button := Button.new()
	preview_button.text = "Preview Draft"
	preview_button.pressed.connect(_handle_preview_requested)
	toolbar.add_child(preview_button)

	var load_button := Button.new()
	load_button.text = "Load In Play View"
	load_button.pressed.connect(_handle_load_requested)
	toolbar.add_child(load_button)

	live_preview_button = CheckButton.new()
	live_preview_button.text = "Live Preview"
	live_preview_button.button_pressed = true
	toolbar.add_child(live_preview_button)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Authoring tools ready."
	status_label.add_theme_color_override("font_color", MUTED)
	toolbar.add_child(status_label)

	editor_tabs = TabContainer.new()
	editor_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(editor_tabs)

	var editor_tab := HSplitContainer.new()
	editor_tab.name = "Editor"
	editor_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_tabs.add_child(editor_tab)

	var room_browser_card := _create_card()
	room_browser_card.custom_minimum_size = Vector2(250, 0)
	editor_tab.add_child(room_browser_card)

	var room_browser_body: VBoxContainer = room_browser_card.get_child(0).get_child(0)
	room_browser_body.add_child(_make_section_label("Room Browser"))

	room_tree = Tree.new()
	room_tree.columns = 1
	room_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_tree.hide_root = true
	room_tree.item_selected.connect(_handle_room_tree_selected)
	room_browser_body.add_child(room_tree)

	var center_split := VSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_tab.add_child(center_split)

	var layer_card := _create_card()
	center_split.add_child(layer_card)
	var layer_body: VBoxContainer = layer_card.get_child(0).get_child(0)
	layer_body.add_child(_make_section_label("Visual Layer Editor"))

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	layer_body.add_child(tool_row)

	layer_selector = OptionButton.new()
	layer_selector.item_selected.connect(_handle_layer_selected)
	tool_row.add_child(layer_selector)

	tool_selector = OptionButton.new()
	for tool_name in ["Tile", "Start", "Entity", "Switch", "Door", "Stamp"]:
		tool_selector.add_item(tool_name)
	tool_selector.item_selected.connect(_handle_tool_selected)
	tool_row.add_child(tool_selector)

	tile_brush_selector = OptionButton.new()
	var brush_labels := {
		".": "Open",
		"#": "Wall",
		"S": "Stitch",
		"G": "Goal",
		"~": "Gap",
	}
	for brush_key in [".", "#", "S", "G", "~"]:
		tile_brush_selector.add_item(brush_labels[brush_key])
		tile_brush_selector.set_item_metadata(tile_brush_selector.item_count - 1, brush_key)
	tile_brush_selector.item_selected.connect(_handle_brush_selected)
	tool_row.add_child(tile_brush_selector)

	layer_visibility_row = HBoxContainer.new()
	layer_visibility_row.add_theme_constant_override("separation", 8)
	layer_body.add_child(layer_visibility_row)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layer_body.add_child(grid_scroll)

	layer_grid_container = VBoxContainer.new()
	layer_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_grid_container.add_theme_constant_override("separation", 10)
	grid_scroll.add_child(layer_grid_container)

	var inspector_card := _create_card()
	inspector_card.custom_minimum_size = Vector2(430, 0)
	editor_tab.add_child(inspector_card)
	var inspector_body: VBoxContainer = inspector_card.get_child(0).get_child(0)
	inspector_body.add_child(_make_section_label("Room Inspector"))

	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_body.add_child(inspector_scroll)

	var inspector_content := VBoxContainer.new()
	inspector_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_content.add_theme_constant_override("separation", 12)
	inspector_scroll.add_child(inspector_content)

	var structure_card := _create_subsection_card(inspector_content, "Structure")
	var structure_grid := GridContainer.new()
	structure_grid.columns = 2
	structure_grid.add_theme_constant_override("h_separation", 8)
	structure_grid.add_theme_constant_override("v_separation", 6)
	structure_card.add_child(structure_grid)

	structure_width_spin = _add_labeled_spin(structure_grid, "Grid Width", 5, 20, 1, _handle_structure_dimension_changed)
	structure_height_spin = _add_labeled_spin(structure_grid, "Grid Height", 5, 20, 1, _handle_structure_dimension_changed)
	layer_id_edit = _add_labeled_line_edit(structure_grid, "Selected Layer Id", _handle_layer_id_changed)
	layer_name_edit = _add_labeled_line_edit(structure_grid, "Selected Layer Name", _handle_layer_name_changed)

	var structure_buttons := HBoxContainer.new()
	structure_buttons.add_theme_constant_override("separation", 8)
	structure_card.add_child(structure_buttons)
	var resize_button := Button.new()
	resize_button.text = "Resize Grid"
	resize_button.pressed.connect(_handle_apply_resize)
	structure_buttons.add_child(resize_button)
	var add_layer_button := Button.new()
	add_layer_button.text = "Add Layer"
	add_layer_button.pressed.connect(_handle_add_layer)
	structure_buttons.add_child(add_layer_button)
	var remove_layer_button := Button.new()
	remove_layer_button.text = "Remove Layer"
	remove_layer_button.pressed.connect(_handle_remove_layer)
	structure_buttons.add_child(remove_layer_button)

	var metadata_card := _create_subsection_card(inspector_content, "Metadata")
	var metadata_grid := GridContainer.new()
	metadata_grid.columns = 2
	metadata_grid.add_theme_constant_override("h_separation", 8)
	metadata_grid.add_theme_constant_override("v_separation", 6)
	metadata_card.add_child(metadata_grid)

	metadata_room_id_edit = _add_labeled_line_edit(metadata_grid, "Room Id", _handle_room_id_changed)
	metadata_title_edit = _add_labeled_line_edit(metadata_grid, "Title", _handle_title_changed)
	metadata_district_option = _add_labeled_option(metadata_grid, "District", _handle_district_changed)
	metadata_optional_button = _add_labeled_check(metadata_grid, "Optional", _handle_optional_changed)
	metadata_postmarks_spin = _add_labeled_spin(metadata_grid, "Postmarks", 0, 5, 1, _handle_postmarks_changed)
	metadata_unlock_spin = _add_labeled_spin(metadata_grid, "Unlock Cost", 0, 5, 1, _handle_unlock_cost_changed)
	metadata_objective_edit = _add_labeled_text_edit(inspector_content, "Objective", 56, _handle_objective_changed)
	metadata_blurb_edit = _add_labeled_text_edit(inspector_content, "Blurb", 56, _handle_blurb_changed)
	intro_speaker_edit = _add_labeled_line_edit(inspector_content, "Intro Speaker", _handle_intro_speaker_changed)
	intro_text_edit = _add_labeled_text_edit(inspector_content, "Intro Text", 70, _handle_intro_text_changed)

	var hint_card := _create_subsection_card(inspector_content, "Hints")
	for index in range(3):
		var hint_edit := _add_labeled_text_edit(hint_card, "Hint %d" % [index + 1], 62, _handle_hint_text_changed.bind(index))
		hint_edits.append(hint_edit)

	var balance_card := _create_subsection_card(inspector_content, "Balance Metadata")
	balance_lesson_edit = _add_labeled_line_edit(balance_card, "Intended Lesson", _handle_balance_lesson_changed)
	balance_difficulty_spin = _add_labeled_spin(balance_card, "Target Difficulty", 1, 5, 1, _handle_balance_difficulty_changed)
	balance_expected_spin = _add_labeled_spin(balance_card, "Expected Solve (min)", 0.5, 30.0, 0.5, _handle_balance_expected_changed)
	balance_misread_edit = _add_labeled_text_edit(balance_card, "Common Misunderstanding", 68, _handle_balance_misread_changed)

	var entity_card := _create_subsection_card(inspector_content, "Entities")
	entity_list = ItemList.new()
	entity_list.custom_minimum_size = Vector2(0, 110)
	entity_list.item_selected.connect(_handle_entity_selected)
	entity_card.add_child(entity_list)

	var entity_buttons := HBoxContainer.new()
	entity_buttons.add_theme_constant_override("separation", 8)
	entity_card.add_child(entity_buttons)
	var add_entity_button := Button.new()
	add_entity_button.text = "Add Entity"
	add_entity_button.pressed.connect(_handle_add_entity)
	entity_buttons.add_child(add_entity_button)
	var remove_entity_button := Button.new()
	remove_entity_button.text = "Remove Entity"
	remove_entity_button.pressed.connect(_handle_remove_entity)
	entity_buttons.add_child(remove_entity_button)

	entity_id_edit = _add_labeled_line_edit(entity_card, "Entity Id", _handle_entity_id_changed)
	entity_type_option = _add_labeled_option(entity_card, "Entity Type", _handle_entity_type_changed)
	for entity_type in ["parcel", "projector", "echo", "shadow"]:
		entity_type_option.add_item(entity_type)
	entity_pushable_button = _add_labeled_check(entity_card, "Pushable", _handle_entity_pushable_changed)
	entity_solid_button = _add_labeled_check(entity_card, "Solid", _handle_entity_solid_changed)
	entity_mirror_option = _add_labeled_option(entity_card, "Mirror Axis", _handle_entity_mirror_changed)
	for axis in ["vertical", "horizontal"]:
		entity_mirror_option.add_item(axis)
	entity_projection_layer_option = _add_labeled_option(entity_card, "Projection Layer", _handle_entity_projection_layer_changed)
	entity_projection_dx_spin = _add_labeled_spin(entity_card, "Projection dX", -6, 6, 1, _handle_entity_projection_dx_changed)
	entity_projection_dy_spin = _add_labeled_spin(entity_card, "Projection dY", -6, 6, 1, _handle_entity_projection_dy_changed)

	var switch_card := _create_subsection_card(inspector_content, "Switches")
	switch_list = ItemList.new()
	switch_list.custom_minimum_size = Vector2(0, 92)
	switch_list.item_selected.connect(_handle_switch_selected)
	switch_card.add_child(switch_list)
	var switch_buttons := HBoxContainer.new()
	switch_buttons.add_theme_constant_override("separation", 8)
	switch_card.add_child(switch_buttons)
	var add_switch_button := Button.new()
	add_switch_button.text = "Add Switch"
	add_switch_button.pressed.connect(_handle_add_switch)
	switch_buttons.add_child(add_switch_button)
	var remove_switch_button := Button.new()
	remove_switch_button.text = "Remove Switch"
	remove_switch_button.pressed.connect(_handle_remove_switch)
	switch_buttons.add_child(remove_switch_button)
	switch_id_edit = _add_labeled_line_edit(switch_card, "Switch Id", _handle_switch_id_changed)
	switch_sticky_button = _add_labeled_check(switch_card, "Sticky", _handle_switch_sticky_changed)

	var door_card := _create_subsection_card(inspector_content, "Doors")
	door_list = ItemList.new()
	door_list.custom_minimum_size = Vector2(0, 92)
	door_list.item_selected.connect(_handle_door_selected)
	door_card.add_child(door_list)
	var door_buttons := HBoxContainer.new()
	door_buttons.add_theme_constant_override("separation", 8)
	door_card.add_child(door_buttons)
	var add_door_button := Button.new()
	add_door_button.text = "Add Door"
	add_door_button.pressed.connect(_handle_add_door)
	door_buttons.add_child(add_door_button)
	var remove_door_button := Button.new()
	remove_door_button.text = "Remove Door"
	remove_door_button.pressed.connect(_handle_remove_door)
	door_buttons.add_child(remove_door_button)
	door_id_edit = _add_labeled_line_edit(door_card, "Door Id", _handle_door_id_changed)
	var door_link_label := Label.new()
	door_link_label.text = "Linked Switches"
	door_link_label.add_theme_color_override("font_color", MUTED)
	door_card.add_child(door_link_label)
	door_switch_links_box = VBoxContainer.new()
	door_switch_links_box.add_theme_constant_override("separation", 4)
	door_card.add_child(door_switch_links_box)

	var routing_card := _create_subsection_card(inspector_content, "Routing Stamps")
	routing_list = ItemList.new()
	routing_list.custom_minimum_size = Vector2(0, 92)
	routing_list.item_selected.connect(_handle_routing_selected)
	routing_card.add_child(routing_list)
	var routing_buttons := HBoxContainer.new()
	routing_buttons.add_theme_constant_override("separation", 8)
	routing_card.add_child(routing_buttons)
	var add_routing_button := Button.new()
	add_routing_button.text = "Add Stamp"
	add_routing_button.pressed.connect(_handle_add_routing_stamp)
	routing_buttons.add_child(add_routing_button)
	var remove_routing_button := Button.new()
	remove_routing_button.text = "Remove Stamp"
	remove_routing_button.pressed.connect(_handle_remove_routing_stamp)
	routing_buttons.add_child(remove_routing_button)
	routing_id_edit = _add_labeled_line_edit(routing_card, "Stamp Id", _handle_routing_id_changed)
	routing_direction_option = _add_labeled_option(routing_card, "Direction", _handle_routing_direction_changed)
	for direction_name in ["right", "left", "up", "down"]:
		routing_direction_option.add_item(direction_name)
	routing_distance_spin = _add_labeled_spin(routing_card, "Distance", 1, 6, 1, _handle_routing_distance_changed)
	routing_apply_switch_button = _add_labeled_check(routing_card, "Applies To Switch Exits", _handle_routing_channel_toggled.bind("switch"))
	routing_apply_transfer_button = _add_labeled_check(routing_card, "Applies To Transfers", _handle_routing_channel_toggled.bind("transfer"))
	routing_apply_projection_button = _add_labeled_check(routing_card, "Applies To Projections", _handle_routing_channel_toggled.bind("projection"))

	var validation_card := _create_subsection_card(inspector_content, "Validation")
	validation_label = RichTextLabel.new()
	validation_label.fit_content = true
	validation_label.scroll_active = false
	validation_label.bbcode_enabled = true
	validation_card.add_child(validation_label)

	var balance_tab := VBoxContainer.new()
	balance_tab.name = "Balance Browser"
	balance_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	balance_tab.add_theme_constant_override("separation", 8)
	editor_tabs.add_child(balance_tab)

	var balance_caption := Label.new()
	balance_caption.text = "Review room metadata, validation pressure, and playtest signals across the current campaign."
	balance_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balance_caption.add_theme_color_override("font_color", MUTED)
	balance_tab.add_child(balance_caption)

	balance_tree = Tree.new()
	balance_tree.columns = 7
	balance_tree.column_titles_visible = true
	balance_tree.set_column_title(0, "Room")
	balance_tree.set_column_title(1, "District")
	balance_tree.set_column_title(2, "Difficulty")
	balance_tree.set_column_title(3, "Expected")
	balance_tree.set_column_title(4, "Validation")
	balance_tree.set_column_title(5, "Attempts")
	balance_tree.set_column_title(6, "Avg Time")
	balance_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	balance_tab.add_child(balance_tree)

	var playtest_tab := VBoxContainer.new()
	playtest_tab.name = "Playtest"
	playtest_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playtest_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	playtest_tab.add_theme_constant_override("separation", 8)
	editor_tabs.add_child(playtest_tab)

	playtest_label = Label.new()
	playtest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	playtest_label.add_theme_color_override("font_color", MUTED)
	playtest_tab.add_child(playtest_label)

	playtest_tree = Tree.new()
	playtest_tree.columns = 6
	playtest_tree.column_titles_visible = true
	playtest_tree.set_column_title(0, "Room")
	playtest_tree.set_column_title(1, "Attempts")
	playtest_tree.set_column_title(2, "Completes")
	playtest_tree.set_column_title(3, "Avg Time")
	playtest_tree.set_column_title(4, "Avg Hints")
	playtest_tree.set_column_title(5, "Avg Resets")
	playtest_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playtest_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	playtest_tab.add_child(playtest_tree)

func _normalize_room(room: Dictionary) -> Dictionary:
	var normalized := room.duplicate(true)
	if not normalized.has("intro") or normalized.get("intro", []).is_empty():
		normalized["intro"] = [{"speaker": "Mina", "text": ""}]
	if normalized.get("hintTiers", []).size() < 3:
		var hints: Array = normalized.get("hintTiers", [])
		while hints.size() < 3:
			hints.append("")
		normalized["hintTiers"] = hints
	if not normalized.has("balance"):
		normalized["balance"] = {
			"intendedLesson": "",
			"targetDifficulty": 1,
			"expectedSolveMinutes": 2,
			"commonMisunderstanding": "",
		}
	for entity in normalized.get("entities", []):
		if entity.get("type", "") == "projector" and entity.get("projectionTargets", []).is_empty():
			entity["projectionTargets"] = [{"layer": 0, "dx": 0, "dy": 0}]
	if not normalized.has("routingStamps"):
		normalized["routingStamps"] = []
	for stamp in normalized.get("routingStamps", []):
		if String(stamp.get("id", "")).is_empty():
			stamp["id"] = "routing-%02d" % [normalized.get("routingStamps", []).find(stamp) + 1]
		if String(stamp.get("direction", "")).is_empty():
			stamp["direction"] = "right"
		if int(stamp.get("distance", 0)) < 1:
			stamp["distance"] = 1
		if stamp.get("appliesTo", []).is_empty():
			stamp["appliesTo"] = ["switch"]
	return normalized

func _selected_layer_index() -> int:
	if layer_selector == null or layer_selector.item_count == 0:
		return 0
	return clampi(layer_selector.selected, 0, layer_selector.item_count - 1)

func _room_width() -> int:
	var layers: Array = draft_room.get("layers", [])
	if layers.is_empty():
		return 0
	var rows: Array = layers[0].get("tiles", [])
	if rows.is_empty():
		return 0
	return String(rows[0]).length()

func _room_height() -> int:
	var layers: Array = draft_room.get("layers", [])
	if layers.is_empty():
		return 0
	return layers[0].get("tiles", []).size()

func _repeat_tile(tile: String, count: int) -> String:
	var result := ""
	for _index in range(maxi(count, 0)):
		result += tile
	return result

func _default_row(width: int, y: int, height: int) -> String:
	if width <= 1:
		return "#"
	if y == 0 or y == height - 1:
		return _repeat_tile("#", width)
	return "#%s#" % _repeat_tile(".", maxi(width - 2, 0))

func _build_resized_row(source_row: String, width: int, y: int, height: int) -> String:
	if width <= 1:
		return "#"
	if y == 0 or y == height - 1:
		return _repeat_tile("#", width)
	var interior_width := maxi(width - 2, 0)
	var interior := ""
	if source_row.length() >= 3:
		interior = source_row.substr(1, mini(interior_width, source_row.length() - 2))
	elif source_row.length() == 2:
		interior = ""
	elif source_row.length() == 1:
		interior = source_row
	if interior.length() < interior_width:
		interior += _repeat_tile(".", interior_width - interior.length())
	elif interior.length() > interior_width:
		interior = interior.substr(0, interior_width)
	return "#%s#" % interior

func _sync_visible_layers() -> void:
	var target_count: int = draft_room.get("layers", []).size()
	while visible_layers.size() < target_count:
		visible_layers.append(true)
	while visible_layers.size() > target_count:
		visible_layers.pop_back()

func _clamp_room_contents() -> void:
	var layer_count: int = draft_room.get("layers", []).size()
	var width: int = _room_width()
	var height: int = _room_height()
	if layer_count == 0 or width == 0 or height == 0:
		return
	var max_x := maxi(1, width - 2)
	var max_y := maxi(1, height - 2)
	var start: Dictionary = draft_room.get("start", {})
	start["layer"] = clampi(int(start.get("layer", 0)), 0, layer_count - 1)
	start["x"] = clampi(int(start.get("x", 1)), 1, max_x)
	start["y"] = clampi(int(start.get("y", 1)), 1, max_y)
	for collection_name in ["entities", "switches", "doors", "routingStamps"]:
		for item in draft_room.get(collection_name, []):
			item["layer"] = clampi(int(item.get("layer", 0)), 0, layer_count - 1)
			item["x"] = clampi(int(item.get("x", 1)), 1, max_x)
			item["y"] = clampi(int(item.get("y", 1)), 1, max_y)
			if collection_name == "entities":
				for target in item.get("projectionTargets", []):
					target["layer"] = clampi(int(target.get("layer", 0)), 0, layer_count - 1)

func _refresh_structure_form() -> void:
	if structure_width_spin == null or structure_height_spin == null:
		return
	suppress_form_events = true
	structure_width_spin.value = _room_width()
	structure_height_spin.value = _room_height()
	if draft_room.get("layers", []).is_empty():
		layer_id_edit.text = ""
		layer_name_edit.text = ""
	else:
		var layer: Dictionary = draft_room.get("layers", [])[clampi(_selected_layer_index(), 0, draft_room.get("layers", []).size() - 1)]
		layer_id_edit.text = layer.get("id", "")
		layer_name_edit.text = layer.get("name", "")
	suppress_form_events = false

func _rebuild_room_tree() -> void:
	if room_tree == null or source_campaign.is_empty():
		return
	room_tree.clear()
	var root := room_tree.create_item()
	for district in source_campaign.get("districts", []):
		var district_item := room_tree.create_item(root)
		district_item.set_text(0, district.get("title", "District"))
		district_item.set_selectable(0, false)
		for room in source_campaign.get("rooms", []):
			if room.get("districtId", "") != district.get("id", ""):
				continue
			var room_item := room_tree.create_item(district_item)
			room_item.set_text(0, room.get("title", room.get("id", "")))
			room_item.set_metadata(0, room.get("id", ""))
			if room.get("id", "") == loaded_source_room_id:
				room_item.select(0)

func _load_draft_into_forms() -> void:
	suppress_form_events = true
	metadata_room_id_edit.text = draft_room.get("id", "")
	metadata_title_edit.text = draft_room.get("title", "")
	metadata_optional_button.button_pressed = bool(draft_room.get("optional", false))
	metadata_postmarks_spin.value = float(draft_room.get("postmarks", 1))
	metadata_unlock_spin.value = float(draft_room.get("unlockCost", 0))
	metadata_objective_edit.text = draft_room.get("objective", "")
	metadata_blurb_edit.text = draft_room.get("blurb", "")
	intro_speaker_edit.text = draft_room.get("intro", [{}])[0].get("speaker", "")
	intro_text_edit.text = draft_room.get("intro", [{}])[0].get("text", "")
	for index in range(hint_edits.size()):
		hint_edits[index].text = draft_room.get("hintTiers", ["", "", ""])[index]

	var balance: Dictionary = draft_room.get("balance", {})
	balance_lesson_edit.text = balance.get("intendedLesson", "")
	balance_difficulty_spin.value = float(balance.get("targetDifficulty", 1))
	balance_expected_spin.value = float(balance.get("expectedSolveMinutes", 2))
	balance_misread_edit.text = balance.get("commonMisunderstanding", "")

	metadata_district_option.clear()
	for district in source_campaign.get("districts", []):
		metadata_district_option.add_item(district.get("title", "District"))
		metadata_district_option.set_item_metadata(metadata_district_option.item_count - 1, district.get("id", ""))
		if district.get("id", "") == draft_room.get("districtId", ""):
			metadata_district_option.select(metadata_district_option.item_count - 1)

	layer_selector.clear()
	entity_projection_layer_option.clear()
	for layer_index in range(draft_room.get("layers", []).size()):
		var layer_name: String = draft_room.get("layers", [])[layer_index].get("name", "Layer %d" % [layer_index + 1])
		layer_selector.add_item(layer_name)
		entity_projection_layer_option.add_item(layer_name)
		entity_projection_layer_option.set_item_metadata(entity_projection_layer_option.item_count - 1, layer_index)
	if layer_selector.item_count > 0:
		layer_selector.select(clampi(int(draft_room.get("start", {}).get("layer", 0)), 0, layer_selector.item_count - 1))

	suppress_form_events = false
	_refresh_structure_form()

func _rebuild_layer_controls() -> void:
	_sync_visible_layers()
	for child in layer_visibility_row.get_children():
		child.queue_free()
	for child in layer_grid_container.get_children():
		child.queue_free()

	for layer_index in range(draft_room.get("layers", []).size()):
		var toggle := CheckButton.new()
		toggle.text = draft_room.get("layers", [])[layer_index].get("name", "Layer %d" % [layer_index + 1])
		toggle.button_pressed = visible_layers[layer_index]
		toggle.toggled.connect(_handle_layer_visibility_toggled.bind(layer_index))
		layer_visibility_row.add_child(toggle)

	for layer_index in range(draft_room.get("layers", []).size()):
		if not visible_layers[layer_index]:
			continue
		var layer_card := _create_card()
		layer_grid_container.add_child(layer_card)
		var layer_body: VBoxContainer = layer_card.get_child(0).get_child(0)
		layer_body.add_child(_make_section_label("%s%s" % [
			draft_room.get("layers", [])[layer_index].get("name", "Layer"),
			" (editing)" if layer_selector.selected == layer_index else "",
		]))

		var rows: Array = draft_room.get("layers", [])[layer_index].get("tiles", [])
		var grid := GridContainer.new()
		grid.columns = String(rows[0]).length() if not rows.is_empty() else 1
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		layer_body.add_child(grid)

		for y in range(rows.size()):
			var row := String(rows[y])
			for x in range(row.length()):
				var button := Button.new()
				button.custom_minimum_size = Vector2(28, 28)
				button.text = _cell_display_text(layer_index, x, y)
				_style_tile_button(button, row.substr(x, 1), layer_index == layer_selector.selected)
				button.tooltip_text = _cell_tooltip(layer_index, x, y)
				button.pressed.connect(_handle_grid_cell_pressed.bind(layer_index, x, y))
				grid.add_child(button)

func _style_tile_button(button: Button, tile: String, active_layer: bool) -> void:
	var fill := Color("fbf6eb")
	match tile:
		"#":
			fill = Color("b49773")
		"S":
			fill = Color("f0ddc5")
		"G":
			fill = Color("f1d58b")
		"~":
			fill = Color("cfbf9f")
	var style := _make_card_style(fill, Color("b58f65") if active_layer else Color("d4c1a1"), 8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", _make_card_style(fill.lightened(0.05), Color("c89b63"), 8))
	button.add_theme_stylebox_override("pressed", _make_card_style(fill.darkened(0.05), Color("a97b4f"), 8))
	button.add_theme_color_override("font_color", INK)

func _cell_display_text(layer_index: int, x: int, y: int) -> String:
	if draft_room.get("start", {}).get("layer", -1) == layer_index and draft_room.get("start", {}).get("x", -1) == x and draft_room.get("start", {}).get("y", -1) == y:
		return "@"
	for entity in draft_room.get("entities", []):
		if entity.get("layer", -1) == layer_index and entity.get("x", -1) == x and entity.get("y", -1) == y:
			return String(entity.get("type", "E")).left(1).to_upper()
	for switch_def in draft_room.get("switches", []):
		if switch_def.get("layer", -1) == layer_index and switch_def.get("x", -1) == x and switch_def.get("y", -1) == y:
			return "^"
	for door_def in draft_room.get("doors", []):
		if door_def.get("layer", -1) == layer_index and door_def.get("x", -1) == x and door_def.get("y", -1) == y:
			return "D"
	for stamp in draft_room.get("routingStamps", []):
		if stamp.get("layer", -1) != layer_index or stamp.get("x", -1) != x or stamp.get("y", -1) != y:
			continue
		match String(stamp.get("direction", "right")):
			"left":
				return "<"
			"up":
				return "A"
			"down":
				return "V"
			_:
				return ">"
	return String(draft_room.get("layers", [])[layer_index].get("tiles", [])[y]).substr(x, 1)

func _cell_tooltip(layer_index: int, x: int, y: int) -> String:
	var parts := ["Layer %d (%d, %d)" % [layer_index + 1, x, y]]
	parts.append("Tile: %s" % String(draft_room.get("layers", [])[layer_index].get("tiles", [])[y]).substr(x, 1))
	for stamp in draft_room.get("routingStamps", []):
		if stamp.get("layer", -1) == layer_index and stamp.get("x", -1) == x and stamp.get("y", -1) == y:
			parts.append("Stamp: %s %s x%d" % [
				stamp.get("id", ""),
				String(stamp.get("direction", "right")),
				int(stamp.get("distance", 1)),
			])
	return "\n".join(parts)

func _rebuild_entities_section() -> void:
	entity_list.clear()
	for entity in draft_room.get("entities", []):
		entity_list.add_item("%s (%s)" % [entity.get("id", ""), entity.get("type", "")])
	if selected_entity_index >= 0 and selected_entity_index < entity_list.item_count:
		entity_list.select(selected_entity_index)
	_load_selected_entity_into_form()

func _rebuild_switch_section() -> void:
	switch_list.clear()
	for switch_def in draft_room.get("switches", []):
		switch_list.add_item("%s%s" % [switch_def.get("id", ""), " [sticky]" if switch_def.get("sticky", false) else ""])
	if selected_switch_index >= 0 and selected_switch_index < switch_list.item_count:
		switch_list.select(selected_switch_index)
	_load_selected_switch_into_form()

func _rebuild_door_section() -> void:
	door_list.clear()
	for door_def in draft_room.get("doors", []):
		door_list.add_item("%s (%d links)" % [door_def.get("id", ""), door_def.get("switchIds", []).size()])
	if selected_door_index >= 0 and selected_door_index < door_list.item_count:
		door_list.select(selected_door_index)
	_load_selected_door_into_form()

func _rebuild_routing_section() -> void:
	routing_list.clear()
	for stamp in draft_room.get("routingStamps", []):
		routing_list.add_item("%s (%s x%d)" % [stamp.get("id", ""), stamp.get("direction", "right"), int(stamp.get("distance", 1))])
	if selected_routing_index >= 0 and selected_routing_index < routing_list.item_count:
		routing_list.select(selected_routing_index)
	_load_selected_routing_into_form()

func _load_selected_entity_into_form() -> void:
	suppress_form_events = true
	if selected_entity_index < 0 or selected_entity_index >= draft_room.get("entities", []).size():
		entity_id_edit.text = ""
		suppress_form_events = false
		return
	var entity: Dictionary = draft_room.get("entities", [])[selected_entity_index]
	entity_id_edit.text = entity.get("id", "")
	entity_pushable_button.button_pressed = bool(entity.get("pushable", false))
	entity_solid_button.button_pressed = bool(entity.get("solid", true))
	for index in range(entity_type_option.item_count):
		if entity_type_option.get_item_text(index) == entity.get("type", ""):
			entity_type_option.select(index)
			break
	for index in range(entity_mirror_option.item_count):
		if entity_mirror_option.get_item_text(index) == entity.get("mirrorAxis", "vertical"):
			entity_mirror_option.select(index)
			break
	var projection: Dictionary = entity.get("projectionTargets", [])[0] if not entity.get("projectionTargets", []).is_empty() else {"layer": 0, "dx": 0, "dy": 0}
	for index in range(entity_projection_layer_option.item_count):
		if int(entity_projection_layer_option.get_item_metadata(index)) == int(projection.get("layer", 0)):
			entity_projection_layer_option.select(index)
			break
	entity_projection_dx_spin.value = float(projection.get("dx", 0))
	entity_projection_dy_spin.value = float(projection.get("dy", 0))
	suppress_form_events = false

func _load_selected_switch_into_form() -> void:
	suppress_form_events = true
	if selected_switch_index < 0 or selected_switch_index >= draft_room.get("switches", []).size():
		switch_id_edit.text = ""
		switch_sticky_button.button_pressed = false
		suppress_form_events = false
		return
	var switch_def: Dictionary = draft_room.get("switches", [])[selected_switch_index]
	switch_id_edit.text = switch_def.get("id", "")
	switch_sticky_button.button_pressed = bool(switch_def.get("sticky", false))
	suppress_form_events = false

func _load_selected_door_into_form() -> void:
	suppress_form_events = true
	if selected_door_index < 0 or selected_door_index >= draft_room.get("doors", []).size():
		door_id_edit.text = ""
		suppress_form_events = false
		return
	var door_def: Dictionary = draft_room.get("doors", [])[selected_door_index]
	door_id_edit.text = door_def.get("id", "")
	for child in door_switch_links_box.get_children():
		child.queue_free()
	for switch_def in draft_room.get("switches", []):
		var toggle := CheckButton.new()
		toggle.text = switch_def.get("id", "")
		toggle.button_pressed = door_def.get("switchIds", []).has(switch_def.get("id", ""))
		toggle.toggled.connect(_handle_door_switch_link_toggled.bind(switch_def.get("id", "")))
		door_switch_links_box.add_child(toggle)
	suppress_form_events = false

func _load_selected_routing_into_form() -> void:
	suppress_form_events = true
	if selected_routing_index < 0 or selected_routing_index >= draft_room.get("routingStamps", []).size():
		routing_id_edit.text = ""
		routing_distance_spin.value = 1
		routing_apply_switch_button.button_pressed = false
		routing_apply_transfer_button.button_pressed = false
		routing_apply_projection_button.button_pressed = false
		suppress_form_events = false
		return
	var stamp: Dictionary = draft_room.get("routingStamps", [])[selected_routing_index]
	routing_id_edit.text = stamp.get("id", "")
	routing_distance_spin.value = float(stamp.get("distance", 1))
	for index in range(routing_direction_option.item_count):
		if routing_direction_option.get_item_text(index) == stamp.get("direction", "right"):
			routing_direction_option.select(index)
			break
	var applies_to: Array = stamp.get("appliesTo", [])
	routing_apply_switch_button.button_pressed = applies_to.has("switch")
	routing_apply_transfer_button.button_pressed = applies_to.has("transfer")
	routing_apply_projection_button.button_pressed = applies_to.has("projection")
	suppress_form_events = false

func _refresh_validation_view() -> void:
	validation_report = Validator.validate_room_report(draft_room)
	var lines: Array = []
	lines.append("[b]Errors:[/b] %d   [b]Warnings:[/b] %d   [b]Info:[/b] %d" % [
		validation_report.get("errors", []).size(),
		validation_report.get("warnings", []).size(),
		validation_report.get("infos", []).size(),
	])
	lines.append("[i]Metrics:[/i] %d layers, %dx%d, %d entities, %d switches, %d doors" % [
		validation_report.get("metrics", {}).get("layerCount", 0),
		validation_report.get("metrics", {}).get("width", 0),
		validation_report.get("metrics", {}).get("height", 0),
		validation_report.get("metrics", {}).get("entityCount", 0),
		validation_report.get("metrics", {}).get("switchCount", 0),
		validation_report.get("metrics", {}).get("doorCount", 0),
	])
	lines.append("[i]Routing:[/i] %d stamp(s)" % validation_report.get("metrics", {}).get("routingStampCount", 0))
	for issue in validation_report.get("issues", []):
		var prefix := "[color=#a2412c]ERROR[/color]"
		if issue.get("severity", "") == "warning":
			prefix = "[color=#8c6a27]WARN[/color]"
		elif issue.get("severity", "") == "info":
			prefix = "[color=#5f6f8c]INFO[/color]"
		lines.append("%s %s" % [prefix, issue.get("message", "")])
	validation_label.text = "\n".join(lines)

func _rebuild_balance_tree() -> void:
	if balance_tree == null:
		return
	balance_tree.clear()
	var root := balance_tree.create_item()
	var by_room: Dictionary = playtest_summary.get("byRoom", {})
	for room in source_campaign.get("rooms", []):
		var room_id := String(room.get("id", ""))
		var item := balance_tree.create_item(root)
		var room_report := Validator.validate_room_report(_normalize_room(room))
		var aggregate: Dictionary = by_room.get(room_id, {})
		item.set_text(0, room.get("title", room_id))
		item.set_text(1, room.get("districtId", ""))
		item.set_text(2, str(room.get("balance", {}).get("targetDifficulty", "-")))
		item.set_text(3, "%sm" % str(room.get("balance", {}).get("expectedSolveMinutes", "-")))
		item.set_text(4, "%dE / %dW" % [room_report.get("errors", []).size(), room_report.get("warnings", []).size()])
		item.set_text(5, str(aggregate.get("attempts", 0)))
		item.set_text(6, "%ss" % str(aggregate.get("averageDurationSeconds", "-")))

func _rebuild_playtest_tree() -> void:
	if playtest_tree == null:
		return
	playtest_tree.clear()
	playtest_label.text = "Local log: %s\nEntries: %d" % [PlaytestLoggerScript.LOG_PATH, playtest_summary.get("entryCount", 0)]
	var root := playtest_tree.create_item()
	for room in source_campaign.get("rooms", []):
		var room_id := String(room.get("id", ""))
		var aggregate: Dictionary = playtest_summary.get("byRoom", {}).get(room_id, {})
		if aggregate.is_empty():
			continue
		var item := playtest_tree.create_item(root)
		item.set_text(0, room.get("title", room_id))
		item.set_text(1, str(aggregate.get("attempts", 0)))
		item.set_text(2, str(aggregate.get("completions", 0)))
		item.set_text(3, "%ss" % str(aggregate.get("averageDurationSeconds", "-")))
		item.set_text(4, str(aggregate.get("averageHints", "-")))
		item.set_text(5, str(aggregate.get("averageResets", "-")))

func _commit_structural_change() -> void:
	_refresh_validation_view()
	_rebuild_layer_controls()
	_rebuild_entities_section()
	_rebuild_switch_section()
	_rebuild_door_section()
	_rebuild_routing_section()
	_rebuild_balance_tree()
	if live_preview_button.button_pressed:
		preview_requested.emit(draft_room.duplicate(true))

func _commit_metadata_change() -> void:
	_refresh_validation_view()
	_rebuild_balance_tree()

func _handle_structure_dimension_changed(_value: float) -> void:
	if suppress_form_events:
		return
	status_label.text = "Pending resize to %dx%d" % [int(structure_width_spin.value), int(structure_height_spin.value)]

func _handle_apply_resize() -> void:
	if draft_room.is_empty():
		return
	var width := maxi(5, int(structure_width_spin.value))
	var height := maxi(5, int(structure_height_spin.value))
	for layer in draft_room.get("layers", []):
		var next_rows: Array = []
		var source_rows: Array = layer.get("tiles", [])
		for y in range(height):
			if y < source_rows.size():
				next_rows.append(_build_resized_row(String(source_rows[y]), width, y, height))
			else:
				next_rows.append(_default_row(width, y, height))
		layer["tiles"] = next_rows
	_clamp_room_contents()
	_load_draft_into_forms()
	_commit_structural_change()
	status_label.text = "Resized %s to %dx%d" % [draft_room.get("id", ""), width, height]

func _handle_layer_id_changed(new_text: String) -> void:
	if suppress_form_events or draft_room.get("layers", []).is_empty():
		return
	var selected_layer := _selected_layer_index()
	draft_room.get("layers", [])[selected_layer]["id"] = new_text.strip_edges()
	_load_draft_into_forms()
	if layer_selector.item_count > 0:
		layer_selector.select(selected_layer)
	_refresh_structure_form()
	_commit_structural_change()

func _handle_layer_name_changed(new_text: String) -> void:
	if suppress_form_events or draft_room.get("layers", []).is_empty():
		return
	var selected_layer := _selected_layer_index()
	draft_room.get("layers", [])[selected_layer]["name"] = new_text
	_load_draft_into_forms()
	if layer_selector.item_count > 0:
		layer_selector.select(selected_layer)
	_refresh_structure_form()
	_commit_structural_change()

func _handle_add_layer() -> void:
	if draft_room.get("layers", []).size() >= 3:
		status_label.text = "v1 rooms top out at three layers."
		return
	var width: int = _room_width()
	var height: int = _room_height()
	var selected_layer: int = _selected_layer_index()
	var new_layer_index: int = draft_room.get("layers", []).size()
	var next_layer := {
		"id": "layer-%d" % [new_layer_index + 1],
		"name": "Layer %d" % [new_layer_index + 1],
		"tiles": [],
	}
	for y in range(height):
		var row := _default_row(width, y, height)
		if selected_layer >= 0 and selected_layer < draft_room.get("layers", []).size():
			var source_row := String(draft_room.get("layers", [])[selected_layer].get("tiles", [])[y])
			var stitch_row := ""
			for x in range(width):
				stitch_row += "S" if source_row.substr(x, 1) == "S" else row.substr(x, 1)
			row = stitch_row
		next_layer["tiles"].append(row)
	draft_room.get("layers", []).append(next_layer)
	_sync_visible_layers()
	_load_draft_into_forms()
	layer_selector.select(draft_room.get("layers", []).size() - 1)
	_refresh_structure_form()
	_commit_structural_change()
	status_label.text = "Added %s" % next_layer.get("name", "layer")

func _handle_remove_layer() -> void:
	if draft_room.get("layers", []).size() <= 2:
		status_label.text = "v1 rooms need at least two layers."
		return
	var selected_layer: int = _selected_layer_index()
	draft_room.get("layers", []).remove_at(selected_layer)
	var next_layer_count: int = draft_room.get("layers", []).size()
	var start: Dictionary = draft_room.get("start", {})
	if int(start.get("layer", 0)) > selected_layer:
		start["layer"] = int(start.get("layer", 0)) - 1
	elif int(start.get("layer", 0)) == selected_layer:
		start["layer"] = mini(selected_layer, next_layer_count - 1)
	for collection_name in ["entities", "switches", "doors", "routingStamps"]:
		for item in draft_room.get(collection_name, []):
			if int(item.get("layer", 0)) > selected_layer:
				item["layer"] = int(item.get("layer", 0)) - 1
			elif int(item.get("layer", 0)) == selected_layer:
				item["layer"] = mini(selected_layer, next_layer_count - 1)
			if collection_name == "entities":
				for target in item.get("projectionTargets", []):
					if int(target.get("layer", 0)) > selected_layer:
						target["layer"] = int(target.get("layer", 0)) - 1
					elif int(target.get("layer", 0)) == selected_layer:
						target["layer"] = mini(selected_layer, next_layer_count - 1)
	_sync_visible_layers()
	_load_draft_into_forms()
	if layer_selector.item_count > 0:
		layer_selector.select(clampi(selected_layer, 0, layer_selector.item_count - 1))
	_refresh_structure_form()
	_commit_structural_change()
	status_label.text = "Removed layer %d" % [selected_layer + 1]

func _handle_room_tree_selected() -> void:
	var item := room_tree.get_selected()
	if item == null:
		return
	var room_id := String(item.get_metadata(0))
	if room_id.is_empty():
		return
	load_room_for_edit(room_id)

func _handle_layer_selected(_index: int) -> void:
	if suppress_form_events:
		return
	_refresh_structure_form()
	_rebuild_layer_controls()

func _handle_tool_selected(index: int) -> void:
	if suppress_form_events:
		return
	current_tool = tool_selector.get_item_text(index).to_lower()

func _handle_brush_selected(index: int) -> void:
	if suppress_form_events:
		return
	current_brush = String(tile_brush_selector.get_item_metadata(index))

func _handle_layer_visibility_toggled(enabled: bool, layer_index: int) -> void:
	visible_layers[layer_index] = enabled
	_rebuild_layer_controls()

func _handle_grid_cell_pressed(layer_index: int, x: int, y: int) -> void:
	match current_tool:
		"start":
			draft_room["start"]["layer"] = layer_index
			draft_room["start"]["x"] = x
			draft_room["start"]["y"] = y
		"entity":
			if selected_entity_index >= 0 and selected_entity_index < draft_room.get("entities", []).size():
				var entity: Dictionary = draft_room.get("entities", [])[selected_entity_index]
				entity["layer"] = layer_index
				entity["x"] = x
				entity["y"] = y
		"switch":
			if selected_switch_index >= 0 and selected_switch_index < draft_room.get("switches", []).size():
				var switch_def: Dictionary = draft_room.get("switches", [])[selected_switch_index]
				switch_def["layer"] = layer_index
				switch_def["x"] = x
				switch_def["y"] = y
		"door":
			if selected_door_index >= 0 and selected_door_index < draft_room.get("doors", []).size():
				var door_def: Dictionary = draft_room.get("doors", [])[selected_door_index]
				door_def["layer"] = layer_index
				door_def["x"] = x
				door_def["y"] = y
		"stamp":
			if selected_routing_index >= 0 and selected_routing_index < draft_room.get("routingStamps", []).size():
				var stamp: Dictionary = draft_room.get("routingStamps", [])[selected_routing_index]
				stamp["layer"] = layer_index
				stamp["x"] = x
				stamp["y"] = y
		_:
			_set_tile(layer_index, x, y, current_brush)
	_commit_structural_change()

func _set_tile(layer_index: int, x: int, y: int, tile: String) -> void:
	var rows: Array = draft_room.get("layers", [])[layer_index].get("tiles", [])
	var row := String(rows[y])
	rows[y] = "%s%s%s" % [row.substr(0, x), tile, row.substr(x + 1)]

func _handle_room_id_changed(new_text: String) -> void:
	if suppress_form_events:
		return
	draft_room["id"] = new_text.strip_edges()
	_commit_metadata_change()

func _handle_title_changed(new_text: String) -> void:
	if suppress_form_events:
		return
	draft_room["title"] = new_text
	_commit_metadata_change()

func _handle_district_changed(index: int) -> void:
	if suppress_form_events:
		return
	draft_room["districtId"] = metadata_district_option.get_item_metadata(index)
	_commit_metadata_change()

func _handle_optional_changed(enabled: bool) -> void:
	if suppress_form_events:
		return
	draft_room["optional"] = enabled
	_commit_metadata_change()

func _handle_postmarks_changed(value: float) -> void:
	if suppress_form_events:
		return
	draft_room["postmarks"] = int(value)
	_commit_metadata_change()

func _handle_unlock_cost_changed(value: float) -> void:
	if suppress_form_events:
		return
	draft_room["unlockCost"] = int(value)
	_commit_metadata_change()

func _handle_objective_changed() -> void:
	if suppress_form_events:
		return
	draft_room["objective"] = metadata_objective_edit.text
	_commit_metadata_change()

func _handle_blurb_changed() -> void:
	if suppress_form_events:
		return
	draft_room["blurb"] = metadata_blurb_edit.text
	_commit_metadata_change()

func _handle_intro_speaker_changed(new_text: String) -> void:
	if suppress_form_events:
		return
	draft_room.get("intro", [])[0]["speaker"] = new_text
	_commit_metadata_change()

func _handle_intro_text_changed() -> void:
	if suppress_form_events:
		return
	draft_room.get("intro", [])[0]["text"] = intro_text_edit.text
	_commit_metadata_change()

func _handle_hint_text_changed(index: int) -> void:
	if suppress_form_events:
		return
	draft_room.get("hintTiers", [])[index] = hint_edits[index].text
	_commit_metadata_change()

func _handle_balance_lesson_changed(new_text: String) -> void:
	if suppress_form_events:
		return
	draft_room.get("balance", {})["intendedLesson"] = new_text
	_commit_metadata_change()

func _handle_balance_difficulty_changed(value: float) -> void:
	if suppress_form_events:
		return
	draft_room.get("balance", {})["targetDifficulty"] = int(value)
	_commit_metadata_change()

func _handle_balance_expected_changed(value: float) -> void:
	if suppress_form_events:
		return
	draft_room.get("balance", {})["expectedSolveMinutes"] = value
	_commit_metadata_change()

func _handle_balance_misread_changed() -> void:
	if suppress_form_events:
		return
	draft_room.get("balance", {})["commonMisunderstanding"] = balance_misread_edit.text
	_commit_metadata_change()

func _handle_entity_selected(index: int) -> void:
	selected_entity_index = index
	_load_selected_entity_into_form()

func _handle_add_entity() -> void:
	draft_room.get("entities", []).append({
		"id": "entity-%02d" % [draft_room.get("entities", []).size() + 1],
		"type": "parcel",
		"layer": layer_selector.selected,
		"x": 1,
		"y": 1,
		"pushable": true,
		"solid": true,
	})
	selected_entity_index = draft_room.get("entities", []).size() - 1
	_commit_structural_change()

func _handle_remove_entity() -> void:
	if selected_entity_index < 0 or selected_entity_index >= draft_room.get("entities", []).size():
		return
	draft_room.get("entities", []).remove_at(selected_entity_index)
	selected_entity_index = mini(selected_entity_index, draft_room.get("entities", []).size() - 1)
	_commit_structural_change()

func _handle_entity_id_changed(new_text: String) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	draft_room.get("entities", [])[selected_entity_index]["id"] = new_text
	_commit_structural_change()

func _handle_entity_type_changed(index: int) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	var entity: Dictionary = draft_room.get("entities", [])[selected_entity_index]
	entity["type"] = entity_type_option.get_item_text(index)
	if entity.get("type", "") == "projector" and entity.get("projectionTargets", []).is_empty():
		entity["projectionTargets"] = [{"layer": 0, "dx": 0, "dy": 0}]
	_commit_structural_change()

func _handle_entity_pushable_changed(enabled: bool) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	draft_room.get("entities", [])[selected_entity_index]["pushable"] = enabled
	_commit_structural_change()

func _handle_entity_solid_changed(enabled: bool) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	draft_room.get("entities", [])[selected_entity_index]["solid"] = enabled
	_commit_structural_change()

func _handle_entity_mirror_changed(index: int) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	draft_room.get("entities", [])[selected_entity_index]["mirrorAxis"] = entity_mirror_option.get_item_text(index)
	_commit_structural_change()

func _handle_entity_projection_layer_changed(index: int) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	var entity: Dictionary = draft_room.get("entities", [])[selected_entity_index]
	if entity.get("projectionTargets", []).is_empty():
		entity["projectionTargets"] = [{"layer": 0, "dx": 0, "dy": 0}]
	entity.get("projectionTargets", [])[0]["layer"] = int(entity_projection_layer_option.get_item_metadata(index))
	_commit_structural_change()

func _handle_entity_projection_dx_changed(value: float) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	var entity: Dictionary = draft_room.get("entities", [])[selected_entity_index]
	if entity.get("projectionTargets", []).is_empty():
		entity["projectionTargets"] = [{"layer": 0, "dx": 0, "dy": 0}]
	entity.get("projectionTargets", [])[0]["dx"] = int(value)
	_commit_structural_change()

func _handle_entity_projection_dy_changed(value: float) -> void:
	if suppress_form_events or selected_entity_index < 0:
		return
	var entity: Dictionary = draft_room.get("entities", [])[selected_entity_index]
	if entity.get("projectionTargets", []).is_empty():
		entity["projectionTargets"] = [{"layer": 0, "dx": 0, "dy": 0}]
	entity.get("projectionTargets", [])[0]["dy"] = int(value)
	_commit_structural_change()

func _handle_switch_selected(index: int) -> void:
	selected_switch_index = index
	_load_selected_switch_into_form()

func _handle_add_switch() -> void:
	draft_room.get("switches", []).append({
		"id": "switch-%02d" % [draft_room.get("switches", []).size() + 1],
		"layer": layer_selector.selected,
		"x": 1,
		"y": 1,
	})
	selected_switch_index = draft_room.get("switches", []).size() - 1
	_commit_structural_change()

func _handle_remove_switch() -> void:
	if selected_switch_index < 0 or selected_switch_index >= draft_room.get("switches", []).size():
		return
	var removed_id := String(draft_room.get("switches", [])[selected_switch_index].get("id", ""))
	draft_room.get("switches", []).remove_at(selected_switch_index)
	for door_def in draft_room.get("doors", []):
		var links: Array = []
		for link in door_def.get("switchIds", []):
			if link != removed_id:
				links.append(link)
		door_def["switchIds"] = links
	selected_switch_index = mini(selected_switch_index, draft_room.get("switches", []).size() - 1)
	_commit_structural_change()

func _handle_switch_id_changed(new_text: String) -> void:
	if suppress_form_events or selected_switch_index < 0:
		return
	draft_room.get("switches", [])[selected_switch_index]["id"] = new_text
	_commit_structural_change()

func _handle_switch_sticky_changed(enabled: bool) -> void:
	if suppress_form_events or selected_switch_index < 0:
		return
	draft_room.get("switches", [])[selected_switch_index]["sticky"] = enabled
	_commit_structural_change()

func _handle_door_selected(index: int) -> void:
	selected_door_index = index
	_load_selected_door_into_form()

func _handle_add_door() -> void:
	draft_room.get("doors", []).append({
		"id": "door-%02d" % [draft_room.get("doors", []).size() + 1],
		"layer": layer_selector.selected,
		"x": 1,
		"y": 1,
		"switchIds": [],
	})
	selected_door_index = draft_room.get("doors", []).size() - 1
	_commit_structural_change()

func _handle_remove_door() -> void:
	if selected_door_index < 0 or selected_door_index >= draft_room.get("doors", []).size():
		return
	draft_room.get("doors", []).remove_at(selected_door_index)
	selected_door_index = mini(selected_door_index, draft_room.get("doors", []).size() - 1)
	_commit_structural_change()

func _handle_door_id_changed(new_text: String) -> void:
	if suppress_form_events or selected_door_index < 0:
		return
	draft_room.get("doors", [])[selected_door_index]["id"] = new_text
	_commit_structural_change()

func _handle_door_switch_link_toggled(enabled: bool, switch_id: String) -> void:
	if suppress_form_events or selected_door_index < 0:
		return
	var door_def: Dictionary = draft_room.get("doors", [])[selected_door_index]
	var links: Array = door_def.get("switchIds", [])
	if enabled and not links.has(switch_id):
		links.append(switch_id)
	elif not enabled and links.has(switch_id):
		links.erase(switch_id)
	door_def["switchIds"] = links
	_commit_structural_change()

func _handle_routing_selected(index: int) -> void:
	selected_routing_index = index
	_load_selected_routing_into_form()

func _handle_add_routing_stamp() -> void:
	draft_room.get("routingStamps", []).append({
		"id": "routing-%02d" % [draft_room.get("routingStamps", []).size() + 1],
		"layer": layer_selector.selected,
		"x": 1,
		"y": 1,
		"direction": "right",
		"distance": 1,
		"appliesTo": ["switch"],
	})
	selected_routing_index = draft_room.get("routingStamps", []).size() - 1
	_commit_structural_change()

func _handle_remove_routing_stamp() -> void:
	if selected_routing_index < 0 or selected_routing_index >= draft_room.get("routingStamps", []).size():
		return
	draft_room.get("routingStamps", []).remove_at(selected_routing_index)
	selected_routing_index = mini(selected_routing_index, draft_room.get("routingStamps", []).size() - 1)
	_commit_structural_change()

func _handle_routing_id_changed(new_text: String) -> void:
	if suppress_form_events or selected_routing_index < 0:
		return
	draft_room.get("routingStamps", [])[selected_routing_index]["id"] = new_text.strip_edges()
	_commit_structural_change()

func _handle_routing_direction_changed(index: int) -> void:
	if suppress_form_events or selected_routing_index < 0:
		return
	draft_room.get("routingStamps", [])[selected_routing_index]["direction"] = routing_direction_option.get_item_text(index)
	_commit_structural_change()

func _handle_routing_distance_changed(value: float) -> void:
	if suppress_form_events or selected_routing_index < 0:
		return
	draft_room.get("routingStamps", [])[selected_routing_index]["distance"] = int(value)
	_commit_structural_change()

func _handle_routing_channel_toggled(enabled: bool, channel: String) -> void:
	if suppress_form_events or selected_routing_index < 0:
		return
	var stamp: Dictionary = draft_room.get("routingStamps", [])[selected_routing_index]
	var applies_to: Array = stamp.get("appliesTo", [])
	if enabled and not applies_to.has(channel):
		applies_to.append(channel)
	elif not enabled and applies_to.has(channel):
		applies_to.erase(channel)
	if applies_to.is_empty():
		applies_to.append("switch")
		suppress_form_events = true
		routing_apply_switch_button.button_pressed = true
		suppress_form_events = false
	stamp["appliesTo"] = applies_to
	_commit_structural_change()

func _handle_preview_requested() -> void:
	if not draft_room.is_empty():
		preview_requested.emit(draft_room.duplicate(true))
		status_label.text = "Previewing draft room %s" % draft_room.get("id", "")

func _handle_load_requested() -> void:
	if draft_room.is_empty():
		return
	room_load_requested.emit(String(draft_room.get("id", "")))

func _handle_new_room() -> void:
	if source_campaign.is_empty():
		return
	var district_id := String(source_campaign.get("districts", [{}])[0].get("id", "mailroom"))
	var next_id := _generate_room_id(district_id, "room")
	draft_room = Repository.create_blank_room(next_id, district_id)
	loaded_source_room_id = draft_room.get("id", "")
	visible_layers = [true, true]
	selected_entity_index = -1
	selected_switch_index = -1
	selected_door_index = -1
	selected_routing_index = -1
	validation_report = Validator.validate_room_report(draft_room)
	_load_draft_into_forms()
	_rebuild_layer_controls()
	_rebuild_entities_section()
	_rebuild_switch_section()
	_rebuild_door_section()
	_rebuild_routing_section()
	_refresh_validation_view()
	status_label.text = "Created blank draft %s" % draft_room.get("id", "")
	if live_preview_button.button_pressed:
		preview_requested.emit(draft_room.duplicate(true))

func _handle_duplicate_room() -> void:
	if source_campaign.is_empty() or draft_room.is_empty():
		return
	var new_id := _generate_room_id(String(draft_room.get("districtId", "mailroom")), "copy")
	var duplicated := Repository.duplicate_room(source_campaign, loaded_source_room_id, new_id)
	if duplicated.is_empty():
		return
	draft_room = _normalize_room(duplicated)
	loaded_source_room_id = duplicated.get("id", "")
	status_label.text = "Duplicated draft to %s" % loaded_source_room_id
	_load_draft_into_forms()
	_rebuild_layer_controls()
	_rebuild_entities_section()
	_rebuild_switch_section()
	_rebuild_door_section()
	_rebuild_routing_section()
	_refresh_validation_view()

func _handle_save_room() -> void:
	if draft_room.is_empty() or source_campaign.is_empty():
		return
	var next_source := source_campaign.duplicate(true)
	if loaded_source_room_id != draft_room.get("id", ""):
		next_source = Repository.remove_room(next_source, loaded_source_room_id)
	next_source = Repository.upsert_room(next_source, draft_room)
	if Repository.persist_campaign(next_source):
		source_campaign = next_source
		loaded_source_room_id = String(draft_room.get("id", ""))
		campaign_saved.emit(Repository.build_campaign_index(source_campaign), source_campaign.duplicate(true), loaded_source_room_id)
		status_label.text = "Saved %s to data/source/campaign.json" % loaded_source_room_id
		_rebuild_room_tree()
		_rebuild_balance_tree()
	else:
		status_label.text = "Save failed. Check file permissions."

func _generate_room_id(district_id: String, suffix: String) -> String:
	var base_prefix := "%s-%s" % [district_id, suffix]
	var next_number := 1
	for room in source_campaign.get("rooms", []):
		var room_id := String(room.get("id", ""))
		if room_id.begins_with(base_prefix):
			next_number += 1
	return "%s-%02d" % [base_prefix, next_number]
