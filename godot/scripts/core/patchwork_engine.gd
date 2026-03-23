class_name PatchworkEngine
extends RefCounted

const DIRECTIONS := {
	"up": {"dx": 0, "dy": -1, "facing": "up"},
	"down": {"dx": 0, "dy": 1, "facing": "down"},
	"left": {"dx": -1, "dy": 0, "facing": "left"},
	"right": {"dx": 1, "dy": 0, "facing": "right"},
}

var campaign: Dictionary = {}
var room: Dictionary = {}
var runtime: Dictionary = {}
var current_room_id := ""
var preview_mode := false
var replay_state: Dictionary = {}

func _init(initial_campaign: Dictionary = {}) -> void:
	campaign = _clone(initial_campaign)

static func _clone(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _coord_key(layer: int, x: int, y: int) -> String:
	return "%d:%d:%d" % [layer, x, y]

static func _clamp_distance(value: Variant) -> int:
	if value == null:
		return 1
	return maxi(1, int(value))

func load_room(room_id: String, snapshot: Variant = null) -> Dictionary:
	var rooms_by_id: Dictionary = campaign.get("roomsById", {})
	var next_room: Dictionary = rooms_by_id.get(room_id, {})
	if next_room.is_empty():
		push_error("Unknown room '%s'" % room_id)
		return {}

	preview_mode = false
	current_room_id = room_id
	room = _clone(next_room)
	runtime = create_runtime(room, snapshot)
	replay_state = {}
	return runtime

func load_preview_room(room_data: Dictionary) -> Dictionary:
	preview_mode = true
	current_room_id = room_data.get("id", "__preview__")
	room = _clone(room_data)
	runtime = create_runtime(room, null)
	replay_state = {}
	return runtime

func create_runtime(room_data: Dictionary, snapshot: Variant = null) -> Dictionary:
	var start: Dictionary = room_data.get("start", {})
	var player: Dictionary = start.duplicate(true)
	player["facing"] = start.get("facing", "right")

	var base := {
		"player": player,
		"activeLayer": start.get("layer", 0),
		"entities": _clone(room_data.get("entities", [])),
		"moveCount": 0,
		"solved": false,
		"actionLog": [],
		"history": [],
		"future": [],
		"latchedSwitches": [],
		"notifications": [],
	}

	if snapshot is Dictionary and not snapshot.is_empty():
		base["player"] = _clone(snapshot.get("player", base["player"]))
		base["activeLayer"] = snapshot.get("activeLayer", base["activeLayer"])
		base["entities"] = _clone(snapshot.get("entities", base["entities"]))
		base["moveCount"] = snapshot.get("moveCount", 0)
		base["solved"] = snapshot.get("solved", false)
		base["actionLog"] = _clone(snapshot.get("actionLog", []))
		base["latchedSwitches"] = _clone(snapshot.get("latchedSwitches", []))

	ensure_companion_state(base["entities"])
	update_dynamic_state(base)
	base["solved"] = is_solved(base)
	return base

func ensure_companion_state(entities: Array) -> void:
	for entity in entities:
		if entity.get("type", "") == "echo" and not entity.has("queuedAction"):
			entity["queuedAction"] = null

func get_room() -> Dictionary:
	return room

func get_runtime() -> Dictionary:
	return runtime

func get_room_snapshot() -> Dictionary:
	if runtime.is_empty():
		return {}

	return {
		"player": _clone(runtime.get("player", {})),
		"activeLayer": runtime.get("activeLayer", 0),
		"entities": _clone(runtime.get("entities", [])),
		"moveCount": runtime.get("moveCount", 0),
		"solved": runtime.get("solved", false),
		"actionLog": _clone(runtime.get("actionLog", [])),
		"latchedSwitches": _clone(runtime.get("latchedSwitches", [])),
	}

func get_replay_actions(kind: String = "current") -> Array:
	if runtime.is_empty():
		return []
	if kind == "current":
		return _clone(runtime.get("actionLog", []))
	return []

func can_undo() -> bool:
	return not runtime.is_empty() and not runtime.get("history", []).is_empty()

func can_redo() -> bool:
	return not runtime.is_empty() and not runtime.get("future", []).is_empty()

func is_replaying() -> bool:
	return not replay_state.is_empty()

func undo() -> bool:
	if not can_undo():
		return false

	var history: Array = runtime["history"]
	var previous: Dictionary = history.pop_back()
	var future: Array = runtime["future"]
	future.append(get_room_snapshot())
	restore_snapshot(previous)
	return true

func redo() -> bool:
	if not can_redo():
		return false

	var future: Array = runtime["future"]
	var next: Dictionary = future.pop_back()
	var history: Array = runtime["history"]
	history.append(get_room_snapshot())
	restore_snapshot(next)
	return true

func reset() -> bool:
	if room.is_empty():
		return false
	runtime = create_runtime(room, null)
	replay_state = {}
	return true

func restore_snapshot(snapshot: Dictionary) -> void:
	runtime["player"] = _clone(snapshot.get("player", {}))
	runtime["activeLayer"] = snapshot.get("activeLayer", 0)
	runtime["entities"] = _clone(snapshot.get("entities", []))
	runtime["moveCount"] = snapshot.get("moveCount", 0)
	runtime["solved"] = snapshot.get("solved", false)
	runtime["actionLog"] = _clone(snapshot.get("actionLog", []))
	runtime["latchedSwitches"] = _clone(snapshot.get("latchedSwitches", []))
	runtime["notifications"] = []
	ensure_companion_state(runtime["entities"])
	update_dynamic_state(runtime)

func start_replay(actions: Array) -> bool:
	if actions.is_empty():
		return false
	reset()
	replay_state = {
		"actions": _clone(actions),
		"index": 0,
		"timerMs": 0.0,
	}
	return true

func update(dt_ms: float) -> void:
	if replay_state.is_empty():
		return

	replay_state["timerMs"] = float(replay_state.get("timerMs", 0.0)) - dt_ms
	var step_ms := 260.0
	while not replay_state.is_empty() and float(replay_state.get("timerMs", 0.0)) <= 0.0:
		var actions: Array = replay_state.get("actions", [])
		var index := int(replay_state.get("index", 0))
		var next_action = actions[index] if index < actions.size() else null
		if next_action == null:
			replay_state = {}
			return
		dispatch(next_action, {"recordHistory": false, "isReplay": true})
		replay_state["index"] = index + 1
		replay_state["timerMs"] = float(replay_state.get("timerMs", 0.0)) + step_ms

func dispatch(raw_action: Variant, options: Dictionary = {}) -> bool:
	if runtime.is_empty() or room.is_empty():
		return false

	var action: Dictionary = normalize_action(raw_action)
	if runtime.get("solved", false) and not options.get("isReplay", false):
		return false

	match action.get("type", ""):
		"undo":
			return undo()
		"redo":
			return redo()
		"reset":
			return reset()

	var snapshot := get_room_snapshot()
	var changed := apply_player_action(action)
	if not changed:
		return false

	process_companions(action)
	runtime["moveCount"] = int(runtime.get("moveCount", 0)) + 1
	runtime["actionLog"].append(action)
	update_dynamic_state(runtime)
	runtime["solved"] = is_solved(runtime)

	if options.get("recordHistory", true):
		runtime["history"].append(snapshot)
		runtime["future"] = []

	return true

func normalize_action(action: Variant) -> Dictionary:
	if action is String:
		return {"type": action}
	if action is Dictionary:
		return _clone(action)
	return {}

func is_move_action(action: Dictionary) -> bool:
	var direction: String = String(action.get("direction", ""))
	return action.get("type", "") == "move" and DIRECTIONS.has(direction)

func apply_player_action(action: Dictionary) -> bool:
	if is_move_action(action):
		var direction: Dictionary = DIRECTIONS[action["direction"]]
		runtime["player"]["facing"] = direction["facing"]
		return try_move_actor(runtime["player"], int(direction["dx"]), int(direction["dy"]), true)

	match action.get("type", ""):
		"switch_layer":
			return try_switch_layer()
		"transfer":
			return try_transfer()
		"wait":
			return true

	return false

func process_companions(action: Dictionary) -> void:
	for entity in runtime.get("entities", []):
		if entity.get("type", "") == "shadow" and is_move_action(action):
			var direction: Dictionary = DIRECTIONS[action["direction"]]
			var mirrored := get_mirrored_vector(direction, entity.get("mirrorAxis", "vertical"))
			try_move_actor(entity, int(mirrored["dx"]), int(mirrored["dy"]), false)

	for entity in runtime.get("entities", []):
		if entity.get("type", "") != "echo":
			continue

		var queued_action = entity.get("queuedAction", null)
		if queued_action is Dictionary and queued_action.get("type", "") == "move":
			var direction: Dictionary = DIRECTIONS[queued_action["direction"]]
			try_move_actor(entity, int(direction["dx"]), int(direction["dy"]), false)

		if is_move_action(action):
			entity["queuedAction"] = _clone(action)
		else:
			entity["queuedAction"] = {"type": "wait"}

func get_mirrored_vector(direction: Dictionary, axis: String) -> Dictionary:
	if axis == "horizontal":
		return {"dx": direction["dx"], "dy": -int(direction["dy"])}
	return {"dx": -int(direction["dx"]), "dy": direction["dy"]}

func routing_stamp_applies_to(stamp: Dictionary, channel: String) -> bool:
	var applies_to: Array = stamp.get("appliesTo", [])
	return applies_to.has(channel)

func find_routing_stamp(layer: int, x: int, y: int, channel: String) -> Dictionary:
	for stamp in room.get("routingStamps", []):
		if int(stamp.get("layer", -1)) != layer:
			continue
		if int(stamp.get("x", -1)) != x or int(stamp.get("y", -1)) != y:
			continue
		if routing_stamp_applies_to(stamp, channel):
			return stamp
	return {}

func get_routed_destination(layer: int, x: int, y: int, channel: String) -> Dictionary:
	var stamp := find_routing_stamp(layer, x, y, channel)
	if stamp.is_empty():
		return {"layer": layer, "x": x, "y": y}
	var direction: Dictionary = DIRECTIONS.get(String(stamp.get("direction", "")), {})
	if direction.is_empty():
		return {"layer": layer, "x": x, "y": y}
	var distance := _clamp_distance(stamp.get("distance", 1))
	return {
		"layer": layer,
		"x": x + int(direction.get("dx", 0)) * distance,
		"y": y + int(direction.get("dy", 0)) * distance,
		"stamp": stamp,
	}

func try_switch_layer() -> bool:
	var player: Dictionary = runtime["player"]
	if get_tile(int(player["layer"]), int(player["x"]), int(player["y"])) != "S":
		return false

	var available_layers: Array = []
	var layers: Array = room.get("layers", [])
	for layer_index in range(layers.size()):
		if layer_index == int(player["layer"]):
			continue
		if get_tile(layer_index, int(player["x"]), int(player["y"])) == "S":
			available_layers.append(layer_index)

	for layer_index in available_layers:
		var routed := get_routed_destination(layer_index, int(player["x"]), int(player["y"]), "switch")
		if is_passable(int(routed["layer"]), int(routed["x"]), int(routed["y"]), {"ignorePlayer": true}):
			player["layer"] = int(routed["layer"])
			player["x"] = int(routed["x"])
			player["y"] = int(routed["y"])
			runtime["activeLayer"] = int(routed["layer"])
			return true

	return false

func try_transfer() -> bool:
	var player: Dictionary = runtime["player"]
	var facing: String = player.get("facing", "right")
	var direction: Dictionary = DIRECTIONS.get(facing, DIRECTIONS["right"])
	var source_x := int(player["x"]) + int(direction["dx"])
	var source_y := int(player["y"]) + int(direction["dy"])
	var entity := find_entity_at(int(player["layer"]), source_x, source_y, {
		"solidOnly": true,
		"pushableOnly": true,
	})

	if entity.is_empty():
		return false

	var layer_count: int = room.get("layers", []).size()
	for offset in range(1, layer_count):
		var target_layer: int = (int(entity["layer"]) + offset) % layer_count
		if target_layer == int(entity["layer"]):
			continue
		var routed := get_routed_destination(target_layer, int(entity["x"]), int(entity["y"]), "transfer")
		if is_passable(int(routed["layer"]), int(routed["x"]), int(routed["y"]), {"ignoreEntityId": entity["id"]}):
			entity["layer"] = int(routed["layer"])
			entity["x"] = int(routed["x"])
			entity["y"] = int(routed["y"])
			return true
	return false

func try_move_actor(actor: Dictionary, dx: int, dy: int, can_push: bool) -> bool:
	var target_x := int(actor["x"]) + dx
	var target_y := int(actor["y"]) + dy
	var blocking_entity := find_entity_at(int(actor["layer"]), target_x, target_y, {
		"solidOnly": true,
		"ignoreEntityId": actor.get("id", ""),
	})

	if not blocking_entity.is_empty():
		if not can_push or not blocking_entity.get("pushable", false):
			return false
		var beyond_x := target_x + dx
		var beyond_y := target_y + dy
		if not is_passable(int(actor["layer"]), beyond_x, beyond_y, {"ignoreEntityId": blocking_entity["id"]}):
			return false
		blocking_entity["x"] = beyond_x
		blocking_entity["y"] = beyond_y
	elif not is_passable(int(actor["layer"]), target_x, target_y, {
		"ignoreEntityId": actor.get("id", ""),
		"ignorePlayer": actor != runtime.get("player", {}),
	}):
		return false

	actor["x"] = target_x
	actor["y"] = target_y
	if actor == runtime.get("player", {}):
		runtime["activeLayer"] = actor["layer"]
	return true

func is_passable(layer: int, x: int, y: int, options: Dictionary = {}) -> bool:
	var tile := get_tile(layer, x, y)
	if tile.is_empty() or tile == "#":
		return false
	if tile == "~":
		var bridges: Dictionary = runtime.get("dynamicState", {}).get("bridges", {})
		if not bridges.has(_coord_key(layer, x, y)):
			return false

	var door := find_door_at(layer, x, y)
	if not door.is_empty():
		var open_doors: Dictionary = runtime.get("dynamicState", {}).get("openDoors", {})
		if not open_doors.has(door["id"]):
			return false

	var occupant := find_entity_at(layer, x, y, {
		"solidOnly": true,
		"ignoreEntityId": options.get("ignoreEntityId", ""),
	})
	if not occupant.is_empty():
		return false

	if not options.get("ignorePlayer", false):
		var player: Dictionary = runtime.get("player", {})
		if int(player.get("layer", -1)) == layer and int(player.get("x", -1)) == x and int(player.get("y", -1)) == y:
			return false

	return true

func update_dynamic_state(runtime_state: Dictionary) -> void:
	var bridges := {}
	for entity in runtime_state.get("entities", []):
		for projection in entity.get("projectionTargets", []):
			var routed := get_routed_destination(
				int(projection["layer"]),
				int(entity["x"]) + int(projection["dx"]),
				int(entity["y"]) + int(projection["dy"]),
				"projection"
			)
			if not get_tile(int(routed["layer"]), int(routed["x"]), int(routed["y"])).is_empty():
				bridges[_coord_key(int(routed["layer"]), int(routed["x"]), int(routed["y"]))] = true

	var active_switches := {}
	for switch_id in runtime_state.get("latchedSwitches", []):
		active_switches[switch_id] = true
	for switch_def in room.get("switches", []):
		if has_occupant(runtime_state, int(switch_def["layer"]), int(switch_def["x"]), int(switch_def["y"])):
			active_switches[switch_def["id"]] = true

	var open_doors := {}
	for door in room.get("doors", []):
		var all_active := true
		for switch_id in door.get("switchIds", []):
			if not active_switches.has(switch_id):
				all_active = false
				break
		if all_active:
			open_doors[door["id"]] = true

	var latched: Array = []
	for switch_id in runtime_state.get("latchedSwitches", []):
		for switch_def in room.get("switches", []):
			if switch_def["id"] == switch_id and switch_def.get("sticky", false):
				latched.append(switch_id)
				break
	for switch_def in room.get("switches", []):
		if switch_def.get("sticky", false) and active_switches.has(switch_def["id"]) and not latched.has(switch_def["id"]):
			latched.append(switch_def["id"])

	runtime_state["latchedSwitches"] = latched
	runtime_state["dynamicState"] = {
		"activeSwitches": active_switches,
		"openDoors": open_doors,
		"bridges": bridges,
	}

func has_occupant(runtime_state: Dictionary, layer: int, x: int, y: int) -> bool:
	var player: Dictionary = runtime_state.get("player", {})
	if int(player.get("layer", -1)) == layer and int(player.get("x", -1)) == x and int(player.get("y", -1)) == y:
		return true

	for entity in runtime_state.get("entities", []):
		if int(entity.get("layer", -1)) == layer and int(entity.get("x", -1)) == x and int(entity.get("y", -1)) == y and entity.get("solid", false):
			return true
	return false

func find_entity_at(layer: int, x: int, y: int, options: Dictionary = {}) -> Dictionary:
	for entity in runtime.get("entities", []):
		if options.get("ignoreEntityId", "") != "" and entity.get("id", "") == options["ignoreEntityId"]:
			continue
		if options.get("solidOnly", false) and not entity.get("solid", false):
			continue
		if options.get("pushableOnly", false) and not entity.get("pushable", false):
			continue
		if int(entity.get("layer", -1)) == layer and int(entity.get("x", -1)) == x and int(entity.get("y", -1)) == y:
			return entity
	return {}

func find_door_at(layer: int, x: int, y: int) -> Dictionary:
	for door in room.get("doors", []):
		if int(door.get("layer", -1)) == layer and int(door.get("x", -1)) == x and int(door.get("y", -1)) == y:
			return door
	return {}

func get_tile(layer: int, x: int, y: int) -> String:
	var layers: Array = room.get("layers", [])
	if layer < 0 or layer >= layers.size():
		return ""
	var tiles: Array = layers[layer].get("tiles", [])
	if y < 0 or y >= tiles.size():
		return ""
	var row := String(tiles[y])
	if x < 0 or x >= row.length():
		return ""
	return row.substr(x, 1)

func is_solved(runtime_state: Dictionary) -> bool:
	var player: Dictionary = runtime_state.get("player", {})
	return get_tile(int(player.get("layer", 0)), int(player.get("x", 0)), int(player.get("y", 0))) == "G"

func get_text_state() -> Dictionary:
	if runtime.is_empty() or room.is_empty():
		return {"mode": "boot"}

	var entities: Array = []
	for entity in runtime.get("entities", []):
		entities.append({
			"id": entity.get("id", ""),
			"type": entity.get("type", ""),
			"layer": entity.get("layer", 0),
			"x": entity.get("x", 0),
			"y": entity.get("y", 0),
		})

	var switches: Array = []
	for switch_def in room.get("switches", []):
		switches.append({
			"id": switch_def.get("id", ""),
			"layer": switch_def.get("layer", 0),
			"x": switch_def.get("x", 0),
			"y": switch_def.get("y", 0),
			"active": runtime.get("dynamicState", {}).get("activeSwitches", {}).has(switch_def.get("id", "")),
		})

	var doors: Array = []
	for door in room.get("doors", []):
		doors.append({
			"id": door.get("id", ""),
			"layer": door.get("layer", 0),
			"x": door.get("x", 0),
			"y": door.get("y", 0),
			"open": runtime.get("dynamicState", {}).get("openDoors", {}).has(door.get("id", "")),
		})

	var routing_stamps: Array = []
	for stamp in room.get("routingStamps", []):
		routing_stamps.append({
			"id": stamp.get("id", ""),
			"layer": stamp.get("layer", 0),
			"x": stamp.get("x", 0),
			"y": stamp.get("y", 0),
			"direction": stamp.get("direction", ""),
			"appliesTo": _clone(stamp.get("appliesTo", [])),
		})

	var layer_names: Array = []
	for layer_data in room.get("layers", []):
		layer_names.append(layer_data.get("name", "Layer"))

	return {
		"mode": "preview" if preview_mode else "room",
		"roomId": room.get("id", ""),
		"roomTitle": room.get("title", ""),
		"coordinates": "origin top-left, x increases right, y increases down",
		"activeLayer": runtime.get("activeLayer", 0),
		"layerNames": layer_names,
		"player": {
			"layer": runtime.get("player", {}).get("layer", 0),
			"x": runtime.get("player", {}).get("x", 0),
			"y": runtime.get("player", {}).get("y", 0),
			"facing": runtime.get("player", {}).get("facing", "right"),
		},
		"entities": entities,
		"switches": switches,
		"doors": doors,
		"routingStamps": routing_stamps,
		"moveCount": runtime.get("moveCount", 0),
		"solved": runtime.get("solved", false),
		"availableActions": ["move", "wait", "switch_layer", "transfer", "undo", "redo", "reset"],
	}
