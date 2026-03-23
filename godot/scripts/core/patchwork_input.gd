class_name PatchworkInput
extends RefCounted

const GAMEPLAY_ACTION_SPECS := [
	{
		"name": "move_up",
		"label": "Move Up",
		"description": "Step upward through the current sheet.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_W},
			{"kind": "key", "keycode": KEY_UP},
		],
		"controller": [
			{"kind": "joy_motion", "axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		],
	},
	{
		"name": "move_down",
		"label": "Move Down",
		"description": "Step downward through the current sheet.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_S},
			{"kind": "key", "keycode": KEY_DOWN},
		],
		"controller": [
			{"kind": "joy_motion", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		],
	},
	{
		"name": "move_left",
		"label": "Move Left",
		"description": "Step left through the current sheet.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_A},
			{"kind": "key", "keycode": KEY_LEFT},
		],
		"controller": [
			{"kind": "joy_motion", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
		],
	},
	{
		"name": "move_right",
		"label": "Move Right",
		"description": "Step right through the current sheet.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_D},
			{"kind": "key", "keycode": KEY_RIGHT},
		],
		"controller": [
			{"kind": "joy_motion", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
		],
	},
	{
		"name": "wait_turn",
		"label": "Wait",
		"description": "Hold still for one beat to advance echoes.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_SPACE},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_A},
		],
	},
	{
		"name": "switch_layer",
		"label": "Switch Layer",
		"description": "Flip to the matching stitch on another sheet.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_TAB},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_X},
		],
	},
	{
		"name": "transfer_object",
		"label": "Transfer Parcel",
		"description": "Send the facing parcel to a matching spot on another layer.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_X},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_Y},
		],
	},
	{
		"name": "undo_action",
		"label": "Undo",
		"description": "Rewind the last step.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_Z},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_LEFT_SHOULDER},
		],
	},
	{
		"name": "redo_action",
		"label": "Redo",
		"description": "Reapply the last rewound step.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_Y},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_RIGHT_SHOULDER},
		],
	},
	{
		"name": "reset_room",
		"label": "Reset Room",
		"description": "Restart the current route from the initial state.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_R},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_B},
		],
	},
	{
		"name": "replay_room",
		"label": "Replay Route",
		"description": "Replay the saved best route or the canonical solution.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_P},
		],
		"controller": [
			{"kind": "joy_button", "button": JOY_BUTTON_START},
		],
	},
	{
		"name": "next_room",
		"label": "Next Room",
		"description": "Cycle to the next unlocked route.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_BRACKETRIGHT},
			{"kind": "key", "keycode": KEY_PAGEDOWN},
		],
		"controller": [
			{"kind": "joy_motion", "axis": JOY_AXIS_TRIGGER_RIGHT, "value": 1.0},
		],
	},
	{
		"name": "prev_room",
		"label": "Previous Room",
		"description": "Cycle to the previous unlocked route.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_BRACKETLEFT},
			{"kind": "key", "keycode": KEY_PAGEUP},
		],
		"controller": [
			{"kind": "joy_motion", "axis": JOY_AXIS_TRIGGER_LEFT, "value": 1.0},
		],
	},
	{
		"name": "load_proof_room",
		"label": "Proof Room",
		"description": "Load the developer-only three-layer proof room.",
		"keyboard": [
			{"kind": "key", "keycode": KEY_F8},
		],
		"controller": [],
	},
]

const UI_ACTION_SPECS := [
	{"name": "ui_up", "keyboard": [{"kind": "key", "keycode": KEY_UP}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_DPAD_UP}]},
	{"name": "ui_down", "keyboard": [{"kind": "key", "keycode": KEY_DOWN}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_DPAD_DOWN}]},
	{"name": "ui_left", "keyboard": [{"kind": "key", "keycode": KEY_LEFT}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_DPAD_LEFT}]},
	{"name": "ui_right", "keyboard": [{"kind": "key", "keycode": KEY_RIGHT}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_DPAD_RIGHT}]},
	{"name": "ui_accept", "keyboard": [{"kind": "key", "keycode": KEY_ENTER}, {"kind": "key", "keycode": KEY_SPACE}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_A}]},
	{"name": "ui_cancel", "keyboard": [{"kind": "key", "keycode": KEY_ESCAPE}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_B}]},
	{"name": "ui_focus_next", "keyboard": [{"kind": "key", "keycode": KEY_TAB}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_RIGHT_SHOULDER}]},
	{"name": "ui_focus_prev", "keyboard": [{"kind": "key", "keycode": KEY_TAB, "shift": true}], "controller": [{"kind": "joy_button", "button": JOY_BUTTON_LEFT_SHOULDER}]},
]

const LEGACY_KEY_MAP := {
	"ArrowUp": KEY_UP,
	"ArrowDown": KEY_DOWN,
	"ArrowLeft": KEY_LEFT,
	"ArrowRight": KEY_RIGHT,
	"Space": KEY_SPACE,
	"Tab": KEY_TAB,
	"KeyX": KEY_X,
	"KeyZ": KEY_Z,
	"KeyY": KEY_Y,
	"KeyR": KEY_R,
	"KeyP": KEY_P,
}

const BUTTON_LABELS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}

const AXIS_LABELS := {
	JOY_AXIS_LEFT_X: ["Left Stick Left", "Left Stick Right"],
	JOY_AXIS_LEFT_Y: ["Left Stick Up", "Left Stick Down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}

static func _clone(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _find_action_spec(action_name: String) -> Dictionary:
	for spec in GAMEPLAY_ACTION_SPECS:
		if String(spec.get("name", "")) == action_name:
			return spec
	for spec in UI_ACTION_SPECS:
		if String(spec.get("name", "")) == action_name:
			return spec
	return {}

static func create_default_controls() -> Dictionary:
	var controls := {}
	for spec in GAMEPLAY_ACTION_SPECS:
		controls[spec["name"]] = {
			"keyboard": _clone(spec.get("keyboard", [])),
			"controller": _clone(spec.get("controller", [])),
		}
	return controls

static func reset_to_defaults() -> Dictionary:
	return create_default_controls()

static func hydrate_controls(raw_controls: Variant) -> Dictionary:
	var controls := create_default_controls()
	if not (raw_controls is Dictionary):
		return controls

	for action_name in controls.keys():
		var existing: Variant = raw_controls.get(action_name, null)
		if existing is Dictionary:
			controls[action_name]["keyboard"] = _hydrate_binding_list(existing.get("keyboard", []), controls[action_name]["keyboard"])
			controls[action_name]["controller"] = _hydrate_binding_list(existing.get("controller", []), controls[action_name]["controller"])
		elif existing is String and LEGACY_KEY_MAP.has(existing):
			controls[action_name]["keyboard"] = [{"kind": "key", "keycode": LEGACY_KEY_MAP[existing]}]
	return controls

static func _hydrate_binding_list(raw_bindings: Variant, fallback: Array) -> Array:
	if raw_bindings is Array and not raw_bindings.is_empty():
		var hydrated: Array = []
		for binding in raw_bindings:
			if binding is Dictionary and not String(binding.get("kind", "")).is_empty():
				hydrated.append(_clone(binding))
		if not hydrated.is_empty():
			return hydrated
	return _clone(fallback)

static func ensure_input_map(control_profile: Dictionary) -> void:
	for spec in UI_ACTION_SPECS:
		_apply_action_events(String(spec.get("name", "")), spec.get("keyboard", []) + spec.get("controller", []))
	for spec in GAMEPLAY_ACTION_SPECS:
		var action_name := String(spec.get("name", ""))
		var bindings: Dictionary = control_profile.get(action_name, {})
		var events: Array = []
		events.append_array(bindings.get("keyboard", spec.get("keyboard", [])))
		events.append_array(bindings.get("controller", spec.get("controller", [])))
		_apply_action_events(action_name, events)

static func _apply_action_events(action_name: String, bindings: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for binding in bindings:
		var event := deserialize_event(binding)
		if event != null:
			InputMap.action_add_event(action_name, event)

static func serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"kind": "key",
			"keycode": int(event.keycode),
			"physicalKeycode": int(event.physical_keycode),
			"shift": bool(event.shift_pressed),
		}
	if event is InputEventJoypadButton:
		return {
			"kind": "joy_button",
			"button": int(event.button_index),
		}
	if event is InputEventJoypadMotion:
		return {
			"kind": "joy_motion",
			"axis": int(event.axis),
			"value": -1.0 if float(event.axis_value) < 0.0 else 1.0,
		}
	return {}

static func deserialize_event(binding: Variant) -> InputEvent:
	if not (binding is Dictionary):
		return null
	match String(binding.get("kind", "")):
		"key":
			var event := InputEventKey.new()
			event.keycode = int(binding.get("keycode", 0))
			event.physical_keycode = int(binding.get("physicalKeycode", event.keycode))
			event.shift_pressed = bool(binding.get("shift", false))
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.button_index = int(binding.get("button", JOY_BUTTON_A))
			event.pressed = true
			return event
		"joy_motion":
			var event := InputEventJoypadMotion.new()
			event.axis = int(binding.get("axis", JOY_AXIS_LEFT_X))
			event.axis_value = float(binding.get("value", 1.0))
			return event
		_:
			return null

static func get_action_specs() -> Array:
	return _clone(GAMEPLAY_ACTION_SPECS)

static func get_action_label(action_name: String) -> String:
	var spec := _find_action_spec(action_name)
	return String(spec.get("label", action_name))

static func get_action_description(action_name: String) -> String:
	var spec := _find_action_spec(action_name)
	return String(spec.get("description", ""))

static func get_bindings_for_source(control_profile: Dictionary, action_name: String, source: String) -> Array:
	var spec := _find_action_spec(action_name)
	if spec.is_empty():
		return []
	var action_profile: Dictionary = control_profile.get(action_name, {})
	return _clone(action_profile.get(source, spec.get(source, [])))

static func set_binding(control_profile: Dictionary, action_name: String, source: String, binding: Dictionary) -> Dictionary:
	var next_controls := hydrate_controls(control_profile)
	if not next_controls.has(action_name):
		return next_controls
	next_controls[action_name][source] = [binding]
	return next_controls

static func describe_binding(binding: Variant) -> String:
	if not (binding is Dictionary):
		return "-"
	match String(binding.get("kind", "")):
		"key":
			var keycode := int(binding.get("keycode", 0))
			return OS.get_keycode_string(keycode)
		"joy_button":
			return String(BUTTON_LABELS.get(int(binding.get("button", -1)), "Button %d" % int(binding.get("button", -1))))
		"joy_motion":
			var axis := int(binding.get("axis", -1))
			var labels: Array = AXIS_LABELS.get(axis, ["Axis %d -" % axis, "Axis %d +" % axis])
			return String(labels[0] if float(binding.get("value", 1.0)) < 0.0 else labels[1])
		_:
			return "-"

static func summarize_action_bindings(control_profile: Dictionary, action_name: String) -> Dictionary:
	var keyboard_bindings := get_bindings_for_source(control_profile, action_name, "keyboard")
	var controller_bindings := get_bindings_for_source(control_profile, action_name, "controller")
	return {
		"action": action_name,
		"label": get_action_label(action_name),
		"description": get_action_description(action_name),
		"keyboard": ", ".join(_describe_binding_list(keyboard_bindings)),
		"controller": ", ".join(_describe_binding_list(controller_bindings)),
	}

static func _describe_binding_list(bindings: Array) -> Array:
	var labels: Array = []
	for binding in bindings:
		labels.append(describe_binding(binding))
	if labels.is_empty():
		labels.append("-")
	return labels

static func is_bindable_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return int(event.keycode) != KEY_NONE and not event.echo
	if event is InputEventJoypadButton:
		return bool(event.pressed)
	if event is InputEventJoypadMotion:
		return absf(float(event.axis_value)) >= 0.65
	return false

static func detect_input_source(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "controller"
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventMouse:
		return "mouse"
	return "keyboard"

static func create_steam_input_manifest() -> Dictionary:
	var actions: Array = []
	for spec in GAMEPLAY_ACTION_SPECS:
		actions.append({
			"name": spec.get("name", ""),
			"title": spec.get("label", ""),
			"description": spec.get("description", ""),
		})
	return {
		"actionSet": {
			"name": "Courier",
			"title": "Courier Controls",
			"actions": actions,
		},
		"navigation": {
			"dpad": ["ui_up", "ui_down", "ui_left", "ui_right"],
			"accept": "ui_accept",
			"cancel": "ui_cancel",
			"focusNext": "ui_focus_next",
			"focusPrev": "ui_focus_prev",
		},
	}
