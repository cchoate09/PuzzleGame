class_name PatchworkValidator
extends RefCounted

static func _key(layer: int, x: int, y: int) -> String:
	return "%d:%d:%d" % [layer, x, y]

static func _parse_tiles(layer: Dictionary) -> Array:
	var rows: Array = []
	for row in layer.get("tiles", []):
		var cells: Array = []
		var row_text := String(row)
		for index in range(row_text.length()):
			cells.append(row_text.substr(index, 1))
		rows.append(cells)
	return rows

static func _add_issue(report: Dictionary, severity: String, category: String, message: String) -> void:
	var issue := {
		"severity": severity,
		"category": category,
		"message": message,
	}
	report["issues"].append(issue)
	match severity:
		"error":
			report["errors"].append(issue)
		"warning":
			report["warnings"].append(issue)
		_:
			report["infos"].append(issue)

static func _tile_at(layers: Array, layer_index: int, x: int, y: int) -> String:
	if layer_index < 0 or layer_index >= layers.size():
		return ""
	var rows: Array = layers[layer_index].get("tiles", [])
	if y < 0 or y >= rows.size():
		return ""
	var row := String(rows[y])
	if x < 0 or x >= row.length():
		return ""
	return row.substr(x, 1)

static func _can_walk_static(tile: String) -> bool:
	return [".", "S", "G", "~"].has(tile)

static func _build_static_reachability(room: Dictionary) -> Dictionary:
	var reachability := {}
	var start: Dictionary = room.get("start", {})
	var layers: Array = room.get("layers", [])
	if layers.is_empty():
		return reachability
	var queue: Array = [Vector3i(int(start.get("layer", 0)), int(start.get("x", 0)), int(start.get("y", 0)))]
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	while not queue.is_empty():
		var cell: Vector3i = queue.pop_front()
		var cell_key := _key(cell.x, cell.y, cell.z)
		if reachability.has(cell_key):
			continue
		var tile := _tile_at(layers, cell.x, cell.y, cell.z)
		if not _can_walk_static(tile):
			continue
		reachability[cell_key] = true

		for direction in directions:
			var next_layer := cell.x
			var next_x: int = cell.y + direction.x
			var next_y: int = cell.z + direction.y
			if _can_walk_static(_tile_at(layers, next_layer, next_x, next_y)):
				queue.append(Vector3i(next_layer, next_x, next_y))

		if tile == "S":
			for layer_index in range(layers.size()):
				if layer_index == cell.x:
					continue
				if _tile_at(layers, layer_index, cell.y, cell.z) == "S":
					queue.append(Vector3i(layer_index, cell.y, cell.z))

	return reachability

static func validate_room_report(room: Dictionary) -> Dictionary:
	var report := {
		"errors": [],
		"warnings": [],
		"infos": [],
		"issues": [],
		"metrics": {
			"layerCount": 0,
			"width": 0,
			"height": 0,
			"entityCount": 0,
			"switchCount": 0,
			"doorCount": 0,
			"routingStampCount": 0,
			"goalCount": 0,
			"stitchCount": 0,
		},
	}
	if room.is_empty():
		_add_issue(report, "error", "room", "No room data loaded.")
		return report

	var layers: Array = room.get("layers", [])
	report["metrics"]["layerCount"] = layers.size()
	if layers.size() < 2 or layers.size() > 3:
		_add_issue(report, "error", "layers", "Room should define two or three layers.")
		return report

	var root_tiles: Array = layers[0].get("tiles", [])
	if root_tiles.is_empty():
		_add_issue(report, "error", "layers", "First layer is missing tile rows.")
		return report
	var width: int = String(root_tiles[0]).length()
	var height: int = root_tiles.size()
	report["metrics"]["width"] = width
	report["metrics"]["height"] = height

	var supported_tiles := ["#", ".", "S", "G", "~"]
	var stitch_counts := {}
	var goal_count := 0

	for layer_index in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var tiles: Array = layer.get("tiles", [])
		if String(layer.get("id", "")).is_empty():
			_add_issue(report, "warning", "layers", "Layer %d is missing an id." % layer_index)
		if String(layer.get("name", "")).is_empty():
			_add_issue(report, "warning", "layers", "Layer %d is missing a display name." % layer_index)
		if tiles.size() != height:
			_add_issue(report, "error", "layers", "Layer %d has a different height than the first layer." % layer_index)
		for row_index in range(tiles.size()):
			var row := String(tiles[row_index])
			if row.length() != width:
				_add_issue(report, "error", "layers", "Layer %d row %d has an inconsistent width." % [layer_index, row_index])
			for column_index in range(row.length()):
				var character := row.substr(column_index, 1)
				if not supported_tiles.has(character):
					_add_issue(report, "error", "tiles", "Layer %d contains an unsupported tile '%s'." % [layer_index, character])
				if character == "G":
					goal_count += 1
				if character == "S":
					var stitch_key := "%d:%d" % [column_index, row_index]
					stitch_counts[stitch_key] = int(stitch_counts.get(stitch_key, 0)) + 1

	report["metrics"]["goalCount"] = goal_count
	report["metrics"]["stitchCount"] = stitch_counts.size()

	if not room.has("start"):
		_add_issue(report, "error", "start", "Room is missing a player start.")
	else:
		var start: Dictionary = room["start"]
		if int(start.get("layer", -1)) < 0 or int(start.get("layer", -1)) >= layers.size() \
		or int(start.get("x", -1)) < 0 or int(start.get("x", -1)) >= width \
		or int(start.get("y", -1)) < 0 or int(start.get("y", -1)) >= height:
			_add_issue(report, "error", "start", "Player start is outside the room bounds.")
		elif _tile_at(layers, int(start.get("layer", 0)), int(start.get("x", 0)), int(start.get("y", 0))) == "#":
			_add_issue(report, "error", "start", "Player start is placed on a wall.")

	if goal_count == 0:
		_add_issue(report, "error", "goal", "Room should have at least one mailbox goal tile.")

	for stitch_key in stitch_counts.keys():
		if int(stitch_counts[stitch_key]) < 2:
			_add_issue(report, "warning", "stitches", "Stitch at %s does not line up with another layer." % stitch_key)

	var switch_ids := {}
	report["metrics"]["switchCount"] = room.get("switches", []).size()
	for switch_def in room.get("switches", []):
		var switch_id := String(switch_def.get("id", ""))
		if switch_id.is_empty():
			_add_issue(report, "error", "switches", "A switch is missing its id.")
		elif switch_ids.has(switch_id):
			_add_issue(report, "error", "switches", "Duplicate switch id '%s'." % switch_id)
		switch_ids[switch_id] = true

		var layer_index := int(switch_def.get("layer", -1))
		var sx := int(switch_def.get("x", -1))
		var sy := int(switch_def.get("y", -1))
		if layer_index < 0 or layer_index >= layers.size():
			_add_issue(report, "error", "switches", "Switch '%s' uses an invalid layer index." % switch_id)
		elif sx < 0 or sx >= width or sy < 0 or sy >= height:
			_add_issue(report, "error", "switches", "Switch '%s' is outside the room bounds." % switch_id)
		elif _tile_at(layers, layer_index, sx, sy) == "#":
			_add_issue(report, "error", "switches", "Switch '%s' is placed on a wall." % switch_id)

	var door_ids := {}
	report["metrics"]["doorCount"] = room.get("doors", []).size()
	for door_def in room.get("doors", []):
		var door_id := String(door_def.get("id", ""))
		if door_id.is_empty():
			_add_issue(report, "error", "doors", "A door is missing its id.")
		elif door_ids.has(door_id):
			_add_issue(report, "error", "doors", "Duplicate door id '%s'." % door_id)
		door_ids[door_id] = true

		var layer_index := int(door_def.get("layer", -1))
		var dx := int(door_def.get("x", -1))
		var dy := int(door_def.get("y", -1))
		if layer_index < 0 or layer_index >= layers.size():
			_add_issue(report, "error", "doors", "Door '%s' uses an invalid layer index." % door_id)
		elif dx < 0 or dx >= width or dy < 0 or dy >= height:
			_add_issue(report, "error", "doors", "Door '%s' is outside the room bounds." % door_id)
		if door_def.get("switchIds", []).is_empty():
			_add_issue(report, "error", "doors", "Door '%s' is not linked to a switch." % door_id)
		for switch_id in door_def.get("switchIds", []):
			if not switch_ids.has(switch_id):
				_add_issue(report, "error", "doors", "Door '%s' references missing switch '%s'." % [door_id, switch_id])

	var routing_stamp_ids := {}
	var routing_stamp_locations := {}
	report["metrics"]["routingStampCount"] = room.get("routingStamps", []).size()
	for stamp in room.get("routingStamps", []):
		var stamp_id := String(stamp.get("id", ""))
		if stamp_id.is_empty():
			_add_issue(report, "error", "routing", "A routing stamp is missing its id.")
		elif routing_stamp_ids.has(stamp_id):
			_add_issue(report, "error", "routing", "Duplicate routing stamp id '%s'." % stamp_id)
		routing_stamp_ids[stamp_id] = true

		var stamp_layer := int(stamp.get("layer", -1))
		var stamp_x := int(stamp.get("x", -1))
		var stamp_y := int(stamp.get("y", -1))
		if stamp_layer < 0 or stamp_layer >= layers.size():
			_add_issue(report, "error", "routing", "Routing stamp '%s' uses an invalid layer index." % stamp_id)
			continue
		if stamp_x < 0 or stamp_x >= width or stamp_y < 0 or stamp_y >= height:
			_add_issue(report, "error", "routing", "Routing stamp '%s' is outside the room bounds." % stamp_id)
			continue
		if _tile_at(layers, stamp_layer, stamp_x, stamp_y) == "#":
			_add_issue(report, "error", "routing", "Routing stamp '%s' is placed on a wall." % stamp_id)

		var direction := String(stamp.get("direction", ""))
		if not ["up", "down", "left", "right"].has(direction):
			_add_issue(report, "error", "routing", "Routing stamp '%s' uses invalid direction '%s'." % [stamp_id, direction])

		if int(stamp.get("distance", 0)) < 1:
			_add_issue(report, "error", "routing", "Routing stamp '%s' should use a distance of at least 1." % stamp_id)

		var applies_to: Array = stamp.get("appliesTo", [])
		if applies_to.is_empty():
			_add_issue(report, "error", "routing", "Routing stamp '%s' should declare at least one routing channel." % stamp_id)
		else:
			for channel in applies_to:
				if not ["switch", "transfer", "projection"].has(channel):
					_add_issue(report, "error", "routing", "Routing stamp '%s' uses unsupported channel '%s'." % [stamp_id, String(channel)])

		var location_key := _key(stamp_layer, stamp_x, stamp_y)
		if routing_stamp_locations.has(location_key):
			_add_issue(report, "warning", "routing", "Multiple routing stamps share %s." % location_key)
		routing_stamp_locations[location_key] = true

	var entity_ids := {}
	report["metrics"]["entityCount"] = room.get("entities", []).size()
	for entity in room.get("entities", []):
		var entity_id := String(entity.get("id", ""))
		if entity_id.is_empty():
			_add_issue(report, "error", "entities", "An entity is missing its id.")
		elif entity_ids.has(entity_id):
			_add_issue(report, "error", "entities", "Duplicate entity id '%s'." % entity_id)
		entity_ids[entity_id] = true

		var entity_layer := int(entity.get("layer", -1))
		var ex := int(entity.get("x", -1))
		var ey := int(entity.get("y", -1))
		if entity_layer < 0 or entity_layer >= layers.size():
			_add_issue(report, "error", "entities", "Entity '%s' uses invalid layer index '%s'." % [entity_id, str(entity.get("layer", ""))])
		elif ex < 0 or ex >= width or ey < 0 or ey >= height:
			_add_issue(report, "error", "entities", "Entity '%s' is outside the room bounds." % entity_id)
		elif _tile_at(layers, entity_layer, ex, ey) == "#":
			_add_issue(report, "error", "entities", "Entity '%s' starts inside a wall." % entity_id)

		for target in entity.get("projectionTargets", []):
			var tx := int(entity.get("x", 0)) + int(target.get("dx", 0))
			var ty := int(entity.get("y", 0)) + int(target.get("dy", 0))
			var target_layer := int(target.get("layer", -1))
			if target_layer < 0 or target_layer >= layers.size():
				_add_issue(report, "error", "entities", "Entity '%s' projects to missing layer '%s'." % [entity_id, str(target.get("layer", ""))])
			elif tx < 0 or tx >= width or ty < 0 or ty >= height:
				_add_issue(report, "error", "entities", "Entity '%s' projects outside the room bounds." % entity_id)

		if entity.get("pushable", false):
			var up := ey - 1 >= 0 and _tile_at(layers, entity_layer, ex, ey - 1) == "#"
			var down := ey + 1 < height and _tile_at(layers, entity_layer, ex, ey + 1) == "#"
			var left := ex - 1 >= 0 and _tile_at(layers, entity_layer, ex - 1, ey) == "#"
			var right := ex + 1 < width and _tile_at(layers, entity_layer, ex + 1, ey) == "#"
			if (up or down) and (left or right):
				_add_issue(report, "warning", "soft-locks", "Pushable '%s' starts in a corner. This may create an accidental soft lock." % entity_id)

	var hint_tiers: Array = room.get("hintTiers", [])
	if hint_tiers.size() < 3:
		_add_issue(report, "error", "hints", "Room should provide three hint tiers.")
	else:
		for index in range(3):
			if String(hint_tiers[index]).strip_edges().is_empty():
				_add_issue(report, "warning", "hints", "Hint tier %d is empty." % [index + 1])

	if String(room.get("objective", "")).strip_edges().is_empty():
		_add_issue(report, "warning", "metadata", "Room objective is missing.")
	if String(room.get("blurb", "")).strip_edges().is_empty():
		_add_issue(report, "warning", "metadata", "Room blurb is missing.")
	if String(room.get("title", "")).strip_edges().is_empty():
		_add_issue(report, "warning", "metadata", "Room title is missing.")
	if String(room.get("districtId", "")).strip_edges().is_empty():
		_add_issue(report, "warning", "metadata", "Room district id is missing.")

	var balance: Dictionary = room.get("balance", {})
	if balance.is_empty():
		_add_issue(report, "error", "balance", "Room is missing balance metadata.")
	else:
		if String(balance.get("intendedLesson", "")).strip_edges().is_empty():
			_add_issue(report, "warning", "balance", "Balance metadata is missing the intended lesson.")
		if int(balance.get("targetDifficulty", 0)) < 1 or int(balance.get("targetDifficulty", 0)) > 5:
			_add_issue(report, "warning", "balance", "Balance metadata should set target difficulty between 1 and 5.")
		if float(balance.get("expectedSolveMinutes", 0.0)) <= 0.0:
			_add_issue(report, "warning", "balance", "Balance metadata should include expected solve minutes.")
		if String(balance.get("commonMisunderstanding", "")).strip_edges().is_empty():
			_add_issue(report, "warning", "balance", "Balance metadata is missing the common misunderstanding.")

	var reachability := _build_static_reachability(room)
	var reachable_stitch_count := 0
	var reachable_goal_count := 0
	for key in reachability.keys():
		var parts := String(key).split(":")
		var layer_index := int(parts[0])
		var x := int(parts[1])
		var y := int(parts[2])
		var tile := _tile_at(layers, layer_index, x, y)
		if tile == "S":
			reachable_stitch_count += 1
		elif tile == "G":
			reachable_goal_count += 1

	if stitch_counts.size() > 0 and reachable_stitch_count == 0:
		_add_issue(report, "warning", "reachability", "No stitch tile is reachable from the player start in the static layout.")
	if goal_count > 0 and reachable_goal_count == 0:
		_add_issue(report, "warning", "reachability", "No mailbox is reachable in the static layout, even with doors and gaps treated as walkable.")

	if report["issues"].is_empty():
		_add_issue(report, "info", "validation", "No structural issues detected. This validator only performs basic checks.")

	return report

static func validate_room(room: Dictionary) -> Array:
	var report := validate_room_report(room)
	var messages: Array = []
	if report.get("errors", []).is_empty() and report.get("warnings", []).is_empty():
		messages.append("No structural issues detected. This validator only performs basic checks.")
		return messages
	for issue in report.get("issues", []):
		if issue.get("severity", "") == "info":
			continue
		messages.append("[%s] %s" % [String(issue.get("severity", "")).to_upper(), issue.get("message", "")])
	return messages
