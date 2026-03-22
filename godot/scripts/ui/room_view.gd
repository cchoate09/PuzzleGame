class_name RoomView
extends Control

const BACKGROUND := Color("1f1a18")
const FLOOR := Color("f4ead8")
const WALL := Color("5d534d")
const STITCH := Color("4aa0a4")
const GOAL := Color("f0c04d")
const GAP := Color("3d2c36")
const BRIDGE := Color("8ccf98")
const PLAYER := Color("de7548")
const SWITCH_IDLE := Color("7a6d64")
const SWITCH_ACTIVE := Color("76b28a")
const DOOR_CLOSED := Color("7f4343")
const DOOR_OPEN := Color("87b39d")

var room: Dictionary = {}
var runtime: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(760, 560)

func set_room_state(room_data: Dictionary, runtime_state: Dictionary) -> void:
	room = room_data.duplicate(true)
	runtime = runtime_state.duplicate(true)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)

	if room.is_empty() or runtime.is_empty():
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, Vector2(24, 40), "Load a room to start the shipping runtime.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		return

	var active_layer := int(runtime.get("activeLayer", 0))
	var layers: Array = room.get("layers", [])
	if active_layer < 0 or active_layer >= layers.size():
		return

	var tiles: Array = layers[active_layer].get("tiles", [])
	if tiles.is_empty():
		return

	var width: int = String(tiles[0]).length()
	var height: int = tiles.size()
	var board_rect: Rect2 = Rect2(Vector2(28, 28), size - Vector2(56, 56))
	var tile_size: float = floor(min(board_rect.size.x / max(width, 1), board_rect.size.y / max(height, 1)))
	tile_size = maxf(tile_size, 24.0)
	var grid_size: Vector2 = Vector2(width * tile_size, height * tile_size)
	var origin: Vector2 = board_rect.position + (board_rect.size - grid_size) * 0.5
	var dynamic_state: Dictionary = runtime.get("dynamicState", {})
	var bridges: Dictionary = dynamic_state.get("bridges", {})
	var open_doors: Dictionary = dynamic_state.get("openDoors", {})
	var active_switches: Dictionary = dynamic_state.get("activeSwitches", {})

	for y in range(height):
		var row := String(tiles[y])
		for x in range(width):
			var tile := row.substr(x, 1)
			var cell_rect := Rect2(origin + Vector2(x * tile_size, y * tile_size), Vector2(tile_size - 2, tile_size - 2))
			var color := FLOOR
			match tile:
				"#":
					color = WALL
				"S":
					color = STITCH
				"G":
					color = GOAL
				"~":
					color = BRIDGE if bridges.has("%d:%d:%d" % [active_layer, x, y]) else GAP
			draw_rect(cell_rect, color, true)
		draw_line(origin + Vector2(0, y * tile_size), origin + Vector2(grid_size.x, y * tile_size), Color("2d2522"), 1.0)
	for x in range(width + 1):
		draw_line(origin + Vector2(x * tile_size, 0), origin + Vector2(x * tile_size, grid_size.y), Color("2d2522"), 1.0)

	for switch_def in room.get("switches", []):
		if int(switch_def.get("layer", -1)) != active_layer:
			continue
		var switch_rect := Rect2(
			origin + Vector2(int(switch_def["x"]) * tile_size + tile_size * 0.25, int(switch_def["y"]) * tile_size + tile_size * 0.25),
			Vector2(tile_size * 0.5, tile_size * 0.5)
		)
		draw_rect(switch_rect, SWITCH_ACTIVE if active_switches.has(switch_def.get("id", "")) else SWITCH_IDLE, true)

	for door in room.get("doors", []):
		if int(door.get("layer", -1)) != active_layer:
			continue
		var door_rect := Rect2(
			origin + Vector2(int(door["x"]) * tile_size + tile_size * 0.1, int(door["y"]) * tile_size + tile_size * 0.1),
			Vector2(tile_size * 0.8, tile_size * 0.8)
		)
		draw_rect(door_rect, DOOR_OPEN if open_doors.has(door.get("id", "")) else DOOR_CLOSED, false, 4.0)

	for entity in runtime.get("entities", []):
		if int(entity.get("layer", -1)) != active_layer:
			continue
		var center := origin + Vector2(int(entity["x"]) * tile_size + tile_size * 0.5, int(entity["y"]) * tile_size + tile_size * 0.5)
		var color := Color("7b6ee6")
		var glyph := "?"
		match String(entity.get("type", "")):
			"parcel":
				color = Color("3d6b9e")
				glyph = "P"
			"projector":
				color = Color("7c9950")
				glyph = "L"
			"echo":
				color = Color("8e6ca8")
				glyph = "E"
			"shadow":
				color = Color("1b2930")
				glyph = "S"
		draw_circle(center, tile_size * 0.28, color)
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, center + Vector2(-tile_size * 0.12, tile_size * 0.12), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tile_size * 0.4), Color.WHITE)

	var player: Dictionary = runtime.get("player", {})
	var player_center := origin + Vector2(int(player.get("x", 0)) * tile_size + tile_size * 0.5, int(player.get("y", 0)) * tile_size + tile_size * 0.5)
	draw_circle(player_center, tile_size * 0.32, PLAYER)
	var player_font := get_theme_default_font()
	if player_font != null:
		draw_string(player_font, player_center + Vector2(-tile_size * 0.18, tile_size * 0.14), "@", HORIZONTAL_ALIGNMENT_LEFT, -1, int(tile_size * 0.45), Color.WHITE)
