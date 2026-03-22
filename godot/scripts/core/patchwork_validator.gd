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

static func validate_room(room: Dictionary) -> Array:
	var issues: Array = []
	if room.is_empty():
		return ["No room data loaded."]

	var layers: Array = room.get("layers", [])
	if layers.size() < 2 or layers.size() > 3:
		issues.append("Room should define two or three layers.")
		return issues

	var root_tiles: Array = layers[0].get("tiles", [])
	var width: int = String(root_tiles[0]).length()
	var height: int = root_tiles.size()

	for layer_index in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var tiles: Array = layer.get("tiles", [])
		if tiles.size() != height:
			issues.append("Layer %d has a different height than the first layer." % layer_index)
		for row_index in range(tiles.size()):
			var row := String(tiles[row_index])
			if row.length() != width:
				issues.append("Layer %d row %d has an inconsistent width." % [layer_index, row_index])
			for column_index in range(row.length()):
				var character := row.substr(column_index, 1)
				if not ["#", ".", "S", "G", "~"].has(character):
					issues.append("Layer %d contains an unsupported tile '%s'." % [layer_index, character])

	if not room.has("start"):
		issues.append("Room is missing a player start.")
	else:
		var start: Dictionary = room["start"]
		if int(start.get("layer", -1)) < 0 or int(start.get("layer", -1)) >= layers.size() \
		or int(start.get("x", -1)) < 0 or int(start.get("x", -1)) >= width \
		or int(start.get("y", -1)) < 0 or int(start.get("y", -1)) >= height:
			issues.append("Player start is outside the room bounds.")

	var goal_count := 0
	for layer in layers:
		for row in layer.get("tiles", []):
			var row_text := String(row)
			for index in range(row_text.length()):
				if row_text.substr(index, 1) == "G":
					goal_count += 1
	if goal_count == 0:
		issues.append("Room should have at least one mailbox goal tile.")

	var stitch_keys := {}
	for layer_index in range(layers.size()):
		var tiles := _parse_tiles(layers[layer_index])
		for y in range(tiles.size()):
			for x in range(tiles[y].size()):
				if tiles[y][x] == "S":
					var tile_key := "%d:%d" % [x, y]
					stitch_keys[tile_key] = int(stitch_keys.get(tile_key, 0)) + 1
	for tile_key in stitch_keys.keys():
		if int(stitch_keys[tile_key]) < 2:
			issues.append("Stitch at %s does not line up with another layer." % tile_key)

	var switch_ids := {}
	for switch_def in room.get("switches", []):
		if switch_ids.has(switch_def.get("id", "")):
			issues.append("Duplicate switch id '%s'." % switch_def.get("id", ""))
		switch_ids[switch_def.get("id", "")] = true
		if int(switch_def.get("x", -1)) < 0 or int(switch_def.get("x", -1)) >= width \
		or int(switch_def.get("y", -1)) < 0 or int(switch_def.get("y", -1)) >= height:
			issues.append("Switch '%s' is outside the room bounds." % switch_def.get("id", ""))
		var layer_index := int(switch_def.get("layer", -1))
		if layer_index < 0 or layer_index >= layers.size():
			issues.append("Switch '%s' uses an invalid layer index." % switch_def.get("id", ""))
		elif String(layers[layer_index].get("tiles", [])[int(switch_def.get("y", 0))]).substr(int(switch_def.get("x", 0)), 1) == "#":
			issues.append("Switch '%s' is placed on a wall." % switch_def.get("id", ""))

	for door_def in room.get("doors", []):
		if door_def.get("switchIds", []).is_empty():
			issues.append("Door '%s' is not linked to a switch." % door_def.get("id", ""))
		for switch_id in door_def.get("switchIds", []):
			if not switch_ids.has(switch_id):
				issues.append("Door '%s' references missing switch '%s'." % [door_def.get("id", ""), switch_id])

	for entity in room.get("entities", []):
		if int(entity.get("x", -1)) < 0 or int(entity.get("x", -1)) >= width \
		or int(entity.get("y", -1)) < 0 or int(entity.get("y", -1)) >= height:
			issues.append("Entity '%s' is outside the room bounds." % entity.get("id", ""))
		var entity_layer := int(entity.get("layer", -1))
		if entity_layer < 0 or entity_layer >= layers.size():
			issues.append("Entity '%s' uses invalid layer index '%s'." % [entity.get("id", ""), str(entity.get("layer", ""))])
		elif String(layers[entity_layer].get("tiles", [])[int(entity.get("y", 0))]).substr(int(entity.get("x", 0)), 1) == "#":
			issues.append("Entity '%s' starts inside a wall." % entity.get("id", ""))

		for target in entity.get("projectionTargets", []):
			var tx := int(entity.get("x", 0)) + int(target.get("dx", 0))
			var ty := int(entity.get("y", 0)) + int(target.get("dy", 0))
			var target_layer := int(target.get("layer", -1))
			if target_layer < 0 or target_layer >= layers.size():
				issues.append("Entity '%s' projects to missing layer '%s'." % [entity.get("id", ""), str(target.get("layer", ""))])
			elif tx < 0 or tx >= width or ty < 0 or ty >= height:
				issues.append("Entity '%s' projects outside the room bounds." % entity.get("id", ""))

	if room.get("hintTiers", []).size() < 3:
		issues.append("Room should provide three hint tiers.")

	if room.get("objective", "").to_lower().contains("transfer"):
		var has_pushable := false
		for entity in room.get("entities", []):
			if entity.get("pushable", false):
				has_pushable = true
				break
		if not has_pushable:
			issues.append("Objective mentions transfer, but no pushable entities are present.")

	for entity in room.get("entities", []):
		if not entity.get("pushable", false):
			continue
		var layer_tiles: Array = layers[int(entity.get("layer", 0))].get("tiles", [])
		var x := int(entity.get("x", 0))
		var y := int(entity.get("y", 0))
		var up := y - 1 >= 0 and String(layer_tiles[y - 1]).substr(x, 1) == "#"
		var down := y + 1 < layer_tiles.size() and String(layer_tiles[y + 1]).substr(x, 1) == "#"
		var left := x - 1 >= 0 and String(layer_tiles[y]).substr(x - 1, 1) == "#"
		var right := x + 1 < String(layer_tiles[y]).length() and String(layer_tiles[y]).substr(x + 1, 1) == "#"
		if (up or down) and (left or right):
			issues.append("Pushable '%s' starts in a corner. This may create an accidental soft lock." % entity.get("id", ""))

	if issues.is_empty():
		issues.append("No structural issues detected. This validator only performs basic checks.")

	return issues
