class_name RoomView
extends Control

const BASE_DESK := Color("dcc39a")
const BASE_DESK_SHADOW := Color("b48f67")
const BASE_PAPER := Color("fffaf0")
const BASE_PAPER_ALT := Color("f3ead7")
const BASE_PAPER_BORDER := Color("ceb48a")
const BASE_WALL := Color("8f7353")
const BASE_FLOOR := Color("fbf3e4")
const BASE_STITCH := Color("c85f4b")
const BASE_GOAL := Color("d7a53d")
const BASE_GAP := Color("bda57e")
const BASE_BRIDGE := Color("8db47a")
const BASE_PLAYER := Color("315a78")
const BASE_PARCEL := Color("cb7148")
const BASE_PROJECTOR := Color("b6a04c")
const BASE_ECHO := Color("7f8fc4")
const BASE_SHADOW := Color("2e2a38")
const BASE_ROUTING := Color("c86b4b")
const BASE_ACTIVE_STRIP := Color("e8b44a")
const BASE_INACTIVE_STRIP := Color("d7c29d")
const BASE_GRID_LINE := Color("dacbb2")

var room: Dictionary = {}
var runtime: Dictionary = {}
var high_contrast := false
var reduced_motion := false
var colorblind_mode := "none"
var displayed_active_layer := 0.0
var enter_progress := 1.0
var solve_flash := 0.0
var _idle_time := 0.0
var stamp_ring_progress := 0.0
var confetti_particles: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(860, 620)
	set_process(true)

func set_colorblind_mode(mode: String) -> void:
	colorblind_mode = mode
	queue_redraw()

func set_accessibility(high_contrast_enabled: bool, reduced_motion_enabled: bool) -> void:
	high_contrast = high_contrast_enabled
	reduced_motion = reduced_motion_enabled
	if reduced_motion and not runtime.is_empty():
		displayed_active_layer = float(int(runtime.get("activeLayer", 0)))
		enter_progress = 1.0
		_idle_time = 0.0
	queue_redraw()

func begin_room_intro() -> void:
	enter_progress = 1.0 if reduced_motion else 0.0
	_idle_time = 0.0
	queue_redraw()

func trigger_solve_flash() -> void:
	solve_flash = 0.45 if reduced_motion else 1.0
	if not reduced_motion:
		stamp_ring_progress = 1.0
		confetti_particles = _make_confetti()
	queue_redraw()

func _make_confetti() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var palette := _get_palette(String(room.get("districtId", "")))
	var colors := [palette["goal"], palette["parcel"], palette["active_strip"], palette["stitch"]]
	var origin := size * 0.5
	var result: Array = []
	for i in range(10):
		var base_color: Color = colors[i % colors.size()]
		result.append({
			"pos": origin + Vector2(rng.randf_range(-100.0, 100.0), rng.randf_range(-70.0, 50.0)),
			"vel": Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-80.0, -20.0)),
			"rot": rng.randf_range(0.0, TAU),
			"rot_speed": rng.randf_range(-4.0, 4.0),
			"alpha": 1.0,
			"w": rng.randf_range(6.0, 13.0),
			"h": rng.randf_range(3.0, 6.0),
			"color": base_color,
		})
	return result

func set_room_state(room_data: Dictionary, runtime_state: Dictionary) -> void:
	var previous_room_id := String(room.get("id", ""))
	room = room_data.duplicate(true)
	runtime = runtime_state.duplicate(true)
	var target_active := float(int(runtime.get("activeLayer", 0)))
	if reduced_motion or previous_room_id.is_empty() or previous_room_id != String(room.get("id", "")):
		displayed_active_layer = target_active
	queue_redraw()

func _process(delta: float) -> void:
	var needs_redraw := false
	if not runtime.is_empty():
		var target_active := float(int(runtime.get("activeLayer", 0)))
		if reduced_motion:
			if displayed_active_layer != target_active:
				displayed_active_layer = target_active
				needs_redraw = true
		else:
			var next_active := move_toward(displayed_active_layer, target_active, delta * 5.2)
			if not is_equal_approx(next_active, displayed_active_layer):
				displayed_active_layer = next_active
				needs_redraw = true

	if enter_progress < 1.0:
		enter_progress = minf(1.0, enter_progress + delta * (18.0 if reduced_motion else 3.6))
		needs_redraw = true
	if solve_flash > 0.0:
		solve_flash = maxf(0.0, solve_flash - delta * (5.0 if reduced_motion else 1.9))
		needs_redraw = true

	if not reduced_motion and not runtime.is_empty():
		_idle_time += delta
		needs_redraw = true

	if stamp_ring_progress > 0.0:
		stamp_ring_progress = maxf(0.0, stamp_ring_progress - delta * 1.6)
		needs_redraw = true

	if not confetti_particles.is_empty():
		var i := confetti_particles.size() - 1
		while i >= 0:
			var p: Dictionary = confetti_particles[i]
			var pos: Vector2 = p["pos"]
			var vel: Vector2 = p["vel"]
			pos += vel * delta
			vel.y += 110.0 * delta
			p["pos"] = pos
			p["vel"] = vel
			p["rot"] = float(p["rot"]) + float(p["rot_speed"]) * delta
			p["alpha"] = maxf(0.0, float(p["alpha"]) - delta * 1.2)
			if float(p["alpha"]) <= 0.0:
				confetti_particles.remove_at(i)
			i -= 1
		needs_redraw = true

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var palette := _get_palette(String(room.get("districtId", "")))
	_draw_backdrop(palette)

	if room.is_empty() or runtime.is_empty():
		var empty_font: Font = get_theme_default_font()
		if empty_font != null:
			draw_string(empty_font, Vector2(40, 54), "Load a room to begin the route.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("4b352d"))
		return

	var layers: Array = room.get("layers", [])
	if layers.is_empty():
		return

	var width: int = String(layers[0].get("tiles", [""])[0]).length()
	var height: int = layers[0].get("tiles", []).size()
	var board_gap: float = 34.0
	var total_columns: int = layers.size() * width
	var tile_size: float = floor(min((size.x - 126.0 - board_gap * float(layers.size() - 1)) / max(total_columns, 1), (size.y - 160.0) / max(height, 1)))
	tile_size = clampf(tile_size, 34.0, 68.0)
	var board_width: float = width * tile_size
	var board_height: float = height * tile_size
	var total_width: float = layers.size() * board_width + float(layers.size() - 1) * board_gap
	var start_x: float = maxf(42.0, (size.x - total_width) * 0.5)
	var start_y: float = maxf(84.0, (size.y - board_height - 110.0) * 0.5)
	var board_data: Array = []

	for layer_index in range(layers.size()):
		var focus := clampf(1.0 - absf(displayed_active_layer - float(layer_index)), 0.0, 1.0)
		var lift := lerpf(10.0, -24.0, focus)
		var intro_offset := (1.0 - enter_progress) * (30.0 + float(layer_index) * 6.0)
		var idle_y := 0.0
		if not reduced_motion:
			idle_y = sin(_idle_time * 0.8 + float(layer_index) * 1.2) * 1.4 * (1.0 - focus)
		var board_origin: Vector2 = Vector2(start_x + layer_index * (board_width + board_gap), start_y + lift + intro_offset + idle_y)
		board_data.append({
			"index": layer_index,
			"origin": board_origin,
			"tileSize": tile_size,
		})
		_draw_layer_card(layer_index, board_origin, tile_size, board_width, board_height, focus, palette)

	_draw_stitch_threads(board_data, palette)
	if solve_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, solve_flash * 0.12), true)
	if stamp_ring_progress > 0.0:
		var ring_t := 1.0 - stamp_ring_progress
		var ring_radius := ring_t * tile_size * 2.8
		var ring_alpha := stamp_ring_progress * 0.7
		draw_arc(size * 0.5, ring_radius, 0.0, TAU, 48, Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, ring_alpha), 4.0)
	for p in confetti_particles:
		var hw: float = float(p["w"]) * 0.5
		var hh: float = float(p["h"]) * 0.5
		var t := Transform2D(float(p["rot"]), p["pos"])
		var verts := PackedVector2Array([t * Vector2(-hw, -hh), t * Vector2(hw, -hh), t * Vector2(hw, hh), t * Vector2(-hw, hh)])
		var base_col: Color = p["color"]
		var col := Color(base_col.r, base_col.g, base_col.b, float(p["alpha"]) * 0.88)
		draw_colored_polygon(verts, col)

func _draw_backdrop(palette: Dictionary) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette["desk"], true)
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 86)), palette["backdrop_band"], true)
	draw_circle(Vector2(120, 92), 56, palette["desk_shadow"].lightened(0.58))
	draw_circle(Vector2(size.x - 132, 118), 72, palette["desk_shadow"].lightened(0.46))
	for index in range(6):
		var x := 84.0 + index * 148.0
		draw_circle(Vector2(x, size.y - 44.0 + float(index % 2) * 8.0), 24.0, palette["desk_shadow"].lightened(0.18))

func _draw_panel(rect: Rect2, fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 16, border_width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if border_width > 0:
		style.border_color = border
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	draw_style_box(style, rect)

func _draw_layer_card(layer_index: int, board_origin: Vector2, tile_size: float, board_width: float, board_height: float, focus: float, palette: Dictionary) -> void:
	var card_rect: Rect2 = Rect2(board_origin - Vector2(22, 62), Vector2(board_width + 44, board_height + 94))
	var shadow_rect: Rect2 = card_rect.grow_individual(6, 12, 6, 14)
	_draw_panel(shadow_rect, Color(0, 0, 0, 0.05 + focus * 0.07), Color(0, 0, 0, 0), 24, 0)
	_draw_panel(card_rect, palette["paper"].lerp(palette["paper_alt"], 1.0 - focus), palette["paper_border"], 22, 2)
	_draw_torn_edge(card_rect, palette)
	_draw_card_stitches(card_rect, palette["stitch"])

	var strip_rect: Rect2 = Rect2(card_rect.position.x + 18, card_rect.position.y + 16, card_rect.size.x - 36, 14)
	_draw_panel(strip_rect, palette["inactive_strip"].lerp(palette["active_strip"], focus), Color(0, 0, 0, 0), 8, 0)

	var layer_title: String = room.get("layers", [])[layer_index].get("name", "Layer")
	var font: Font = get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(card_rect.position.x + 22, card_rect.position.y + 54), layer_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("4b352d"))
		draw_string(font, Vector2(card_rect.position.x + card_rect.size.x - 44, card_rect.position.y + 54), "L%d" % [layer_index + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, palette["paper_border"].darkened(0.35))

	_draw_tiles(layer_index, board_origin, tile_size, focus, palette)
	_draw_switches(layer_index, board_origin, tile_size, palette)
	_draw_routing_stamps(layer_index, board_origin, tile_size, palette)
	_draw_doors(layer_index, board_origin, tile_size, palette)
	_draw_entities(layer_index, board_origin, tile_size, palette)
	_draw_player(layer_index, board_origin, tile_size, palette)

func _draw_torn_edge(card_rect: Rect2, palette: Dictionary) -> void:
	var points := PackedVector2Array()
	var segment_count := 9
	for index in range(segment_count + 1):
		var ratio := float(index) / float(segment_count)
		var x := lerpf(card_rect.position.x + 14.0, card_rect.position.x + card_rect.size.x - 14.0, ratio)
		var y := card_rect.position.y + card_rect.size.y - 4.0 + (5.0 if index % 2 == 0 else -2.5)
		points.append(Vector2(x, y))
	draw_polyline(points, palette["paper_border"].darkened(0.12), 2.0)

func _draw_card_stitches(card_rect: Rect2, stitch_color: Color) -> void:
	var left_x := card_rect.position.x + 10.0
	var right_x := card_rect.position.x + card_rect.size.x - 10.0
	for index in range(8):
		var y := card_rect.position.y + 34.0 + float(index) * 32.0
		draw_line(Vector2(left_x, y), Vector2(left_x, y + 10.0), stitch_color, 2.0)
		draw_line(Vector2(right_x, y), Vector2(right_x, y + 10.0), stitch_color, 2.0)

func _draw_tiles(layer_index: int, board_origin: Vector2, tile_size: float, focus: float, palette: Dictionary) -> void:
	var tiles: Array = room.get("layers", [])[layer_index].get("tiles", [])
	var dynamic_state: Dictionary = runtime.get("dynamicState", {})
	var bridges: Dictionary = dynamic_state.get("bridges", {})

	for y in range(tiles.size()):
		var row: String = String(tiles[y])
		for x in range(row.length()):
			var tile: String = row.substr(x, 1)
			var cell_rect: Rect2 = Rect2(board_origin + Vector2(x * tile_size, y * tile_size), Vector2(tile_size - 2, tile_size - 2))
			var cell_color: Color = palette["floor"].darkened((1.0 - focus) * 0.05)
			match tile:
				"#":
					cell_color = palette["wall"].darkened((1.0 - focus) * 0.08)
				"S":
					cell_color = palette["floor"]
				"G":
					cell_color = palette["goal"]
				"~":
					cell_color = palette["bridge"] if bridges.has("%d:%d:%d" % [layer_index, x, y]) else palette["gap"]
			draw_rect(cell_rect, cell_color, true)
			draw_rect(cell_rect, palette["grid_line"], false, 1.0)

			if tile == "#":
				_draw_panel(cell_rect.grow(-8), palette["wall"].darkened(0.14), Color(0, 0, 0, 0), 12, 0)
			elif tile == "S":
				draw_rect(cell_rect.grow(-10), Color(0, 0, 0, 0), false, 2.0)
				var stitch_inner: Rect2 = cell_rect.grow(-14)
				draw_line(stitch_inner.position, stitch_inner.position + stitch_inner.size, palette["stitch"], 2.0)
				draw_line(stitch_inner.position + Vector2(stitch_inner.size.x, 0), stitch_inner.position + Vector2(0, stitch_inner.size.y), palette["stitch"], 2.0)
				draw_circle(cell_rect.position + Vector2(10, 10), 2.0, palette["stitch"])
				draw_circle(cell_rect.position + Vector2(cell_rect.size.x - 10, cell_rect.size.y - 10), 2.0, palette["stitch"])
			elif tile == "G":
				var mailbox_rect: Rect2 = cell_rect.grow(-12)
				_draw_panel(mailbox_rect, palette["goal"].darkened(0.15), Color(0, 0, 0, 0), 10, 0)
				_draw_panel(Rect2(mailbox_rect.position.x + 10, mailbox_rect.position.y + 6, mailbox_rect.size.x - 20, 10), Color("fff0cb"), Color(0, 0, 0, 0), 5, 0)
				draw_line(mailbox_rect.position + Vector2(mailbox_rect.size.x * 0.2, mailbox_rect.size.y * 0.55), mailbox_rect.position + Vector2(mailbox_rect.size.x * 0.8, mailbox_rect.size.y * 0.55), Color("7e4d20"), 2.0)
			elif tile == "~" and not bridges.has("%d:%d:%d" % [layer_index, x, y]):
				draw_line(cell_rect.position + Vector2(10, 10), cell_rect.position + Vector2(cell_rect.size.x - 10, cell_rect.size.y - 10), palette["wall"], 2.0)
				draw_line(cell_rect.position + Vector2(cell_rect.size.x - 10, 10), cell_rect.position + Vector2(10, cell_rect.size.y - 10), palette["wall"], 2.0)
			elif tile == "~":
				draw_rect(cell_rect.grow(-8), palette["bridge"].lightened(0.12), false, 2.0)

func _draw_switches(layer_index: int, board_origin: Vector2, tile_size: float, palette: Dictionary) -> void:
	var active_switches: Dictionary = runtime.get("dynamicState", {}).get("activeSwitches", {})
	for switch_def in room.get("switches", []):
		if int(switch_def.get("layer", -1)) != layer_index:
			continue
		var rect := Rect2(
			board_origin + Vector2(int(switch_def.get("x", 0)) * tile_size + tile_size * 0.2, int(switch_def.get("y", 0)) * tile_size + tile_size * 0.68),
			Vector2(tile_size * 0.6, tile_size * 0.12)
		)
		_draw_panel(rect, palette["bridge"] if active_switches.has(switch_def.get("id", "")) else Color("c8b89b"), Color(0, 0, 0, 0), 6, 0)
		draw_circle(rect.position + Vector2(rect.size.x * 0.5, 0), 3.0, palette["stitch"])

func _draw_doors(layer_index: int, board_origin: Vector2, tile_size: float, palette: Dictionary) -> void:
	var open_doors: Dictionary = runtime.get("dynamicState", {}).get("openDoors", {})
	for door in room.get("doors", []):
		if int(door.get("layer", -1)) != layer_index:
			continue
		var door_rect := Rect2(
			board_origin + Vector2(int(door.get("x", 0)) * tile_size + tile_size * 0.16, int(door.get("y", 0)) * tile_size + tile_size * 0.12),
			Vector2(tile_size * 0.68, tile_size * 0.76)
		)
		if open_doors.has(door.get("id", "")):
			_draw_panel(door_rect, Color(0, 0, 0, 0), palette["bridge"].darkened(0.08), 10, 3)
		else:
			_draw_panel(door_rect, palette["parcel"].darkened(0.18), Color(0, 0, 0, 0), 10, 0)
			draw_circle(door_rect.position + Vector2(door_rect.size.x - 12, door_rect.size.y * 0.5), 3.0, Color("fff0cb"))
			draw_line(door_rect.position + Vector2(door_rect.size.x * 0.5, 6), door_rect.position + Vector2(door_rect.size.x * 0.5, door_rect.size.y - 6), Color("84513d"), 2.0)

func _draw_routing_stamps(layer_index: int, board_origin: Vector2, tile_size: float, palette: Dictionary) -> void:
	var font: Font = get_theme_default_font()
	for stamp in room.get("routingStamps", []):
		if int(stamp.get("layer", -1)) != layer_index:
			continue
		var stamp_rect := Rect2(
			board_origin + Vector2(int(stamp.get("x", 0)) * tile_size + tile_size * 0.18, int(stamp.get("y", 0)) * tile_size + tile_size * 0.18),
			Vector2(tile_size * 0.64, tile_size * 0.64)
		)
		_draw_panel(stamp_rect, Color(palette["routing"].r, palette["routing"].g, palette["routing"].b, 0.18), palette["routing"], 14, 2)
		_draw_stamp_arrow(stamp_rect, String(stamp.get("direction", "right")), palette["routing"])
		if font != null:
			var channels: Array = []
			for channel in stamp.get("appliesTo", []):
				var label := String(channel)
				channels.append(label.left(1).to_upper())
			var badge_text := ""
			for channel_label in channels:
				badge_text += String(channel_label)
			draw_string(font, stamp_rect.position + Vector2(6, stamp_rect.size.y - 6), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, palette["routing"].darkened(0.25))

func _draw_stamp_arrow(rect: Rect2, direction: String, color: Color) -> void:
	var center := rect.get_center()
	var shaft_start := center
	var shaft_end := center
	match direction:
		"left":
			shaft_start += Vector2(rect.size.x * 0.18, 0)
			shaft_end += Vector2(-rect.size.x * 0.18, 0)
		"up":
			shaft_start += Vector2(0, rect.size.y * 0.18)
			shaft_end += Vector2(0, -rect.size.y * 0.18)
		"down":
			shaft_start += Vector2(0, -rect.size.y * 0.18)
			shaft_end += Vector2(0, rect.size.y * 0.18)
		_:
			shaft_start += Vector2(-rect.size.x * 0.18, 0)
			shaft_end += Vector2(rect.size.x * 0.18, 0)
	draw_line(shaft_start, shaft_end, color, 2.4)
	var tip := PackedVector2Array()
	match direction:
		"left":
			tip = PackedVector2Array([shaft_end + Vector2(-7, 0), shaft_end + Vector2(4, -5), shaft_end + Vector2(4, 5)])
		"up":
			tip = PackedVector2Array([shaft_end + Vector2(0, -7), shaft_end + Vector2(-5, 4), shaft_end + Vector2(5, 4)])
		"down":
			tip = PackedVector2Array([shaft_end + Vector2(0, 7), shaft_end + Vector2(-5, -4), shaft_end + Vector2(5, -4)])
		_:
			tip = PackedVector2Array([shaft_end + Vector2(7, 0), shaft_end + Vector2(-4, -5), shaft_end + Vector2(-4, 5)])
	draw_colored_polygon(tip, color)

func _draw_entities(layer_index: int, board_origin: Vector2, tile_size: float, palette: Dictionary) -> void:
	for entity in runtime.get("entities", []):
		if int(entity.get("layer", -1)) != layer_index:
			continue

		var center: Vector2 = board_origin + Vector2(int(entity.get("x", 0)) * tile_size + tile_size * 0.5, int(entity.get("y", 0)) * tile_size + tile_size * 0.5)
		match String(entity.get("type", "")):
			"parcel":
				_draw_parcel(center, tile_size, palette)
			"projector":
				_draw_projector(center, tile_size, palette)
			"echo":
				_draw_echo(center, tile_size, palette)
			"shadow":
				_draw_shadow(center, tile_size, palette)

func _draw_parcel(center: Vector2, tile_size: float, palette: Dictionary) -> void:
	var box_rect := Rect2(center - Vector2(tile_size * 0.2, tile_size * 0.2), Vector2(tile_size * 0.4, tile_size * 0.4))
	_draw_panel(box_rect, palette["parcel"], Color("8a4a31"), 8, 1)
	draw_line(Vector2(center.x, box_rect.position.y + 4), Vector2(center.x, box_rect.position.y + box_rect.size.y - 4), Color("fff2dc"), 2.0)
	draw_line(Vector2(box_rect.position.x + 4, center.y), Vector2(box_rect.position.x + box_rect.size.x - 4, center.y), Color("fff2dc"), 2.0)
	# String bow on top — two tails meeting at a knot
	var knot := Vector2(center.x, box_rect.position.y + 2.0)
	draw_line(knot, knot + Vector2(-tile_size * 0.1, -tile_size * 0.08), Color("8a4a31"), 1.5)
	draw_line(knot, knot + Vector2(tile_size * 0.1, -tile_size * 0.08), Color("8a4a31"), 1.5)
	draw_circle(knot, tile_size * 0.04, Color("6b3520"))
	draw_circle(center + Vector2(0, tile_size * 0.22), tile_size * 0.06, Color(0, 0, 0, 0.08))

func _draw_projector(center: Vector2, tile_size: float, palette: Dictionary) -> void:
	# Glow halo behind body (drawn first so body renders on top)
	draw_circle(center + Vector2(tile_size * 0.07, 0), tile_size * 0.22, Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, 0.1))
	draw_polygon(PackedVector2Array([
		center + Vector2(-tile_size * 0.1, tile_size * 0.1),
		center + Vector2(tile_size * 0.18, tile_size * 0.02),
		center + Vector2(tile_size * 0.18, tile_size * 0.18),
	]), PackedColorArray([Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, 0.16), Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, 0.04), Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, 0.04)]))
	var body_rect := Rect2(center - Vector2(tile_size * 0.16, tile_size * 0.12), Vector2(tile_size * 0.22, tile_size * 0.26))
	_draw_panel(body_rect, palette["projector"], Color("7c6429"), 8, 1)
	draw_circle(center + Vector2(tile_size * 0.07, 0), tile_size * 0.11, Color("f8edc0"))
	draw_line(center + Vector2(-tile_size * 0.04, tile_size * 0.16), center + Vector2(tile_size * 0.12, tile_size * 0.16), Color("7c6429"), 2.0)
	# Light rays from cone tip
	var ray_origin := center + Vector2(tile_size * 0.18, tile_size * 0.1)
	draw_line(ray_origin, ray_origin + Vector2(tile_size * 0.14, -tile_size * 0.12), Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, 0.5), 1.5)
	draw_line(ray_origin, ray_origin + Vector2(tile_size * 0.15, tile_size * 0.08), Color(palette["goal"].r, palette["goal"].g, palette["goal"].b, 0.5), 1.5)

func _draw_echo(center: Vector2, tile_size: float, palette: Dictionary) -> void:
	# Outer ring as primary shape — suggests ripple/echo delay
	draw_arc(center, tile_size * 0.26, 0.0, TAU, 32, Color(palette["echo"].r, palette["echo"].g, palette["echo"].b, 0.88), 3.0)
	# Subtle fill
	draw_circle(center, tile_size * 0.22, Color(palette["echo"].r, palette["echo"].g, palette["echo"].b, 0.20))
	# Inner ring (secondary pulse)
	draw_arc(center, tile_size * 0.14, 0.0, TAU, 20, Color(palette["echo"].r, palette["echo"].g, palette["echo"].b, 0.55), 1.5)
	# Center dot
	draw_circle(center, tile_size * 0.04, Color("ecf3ff"))

func _draw_shadow(center: Vector2, tile_size: float, palette: Dictionary) -> void:
	# Body silhouette — clearer person shape
	draw_circle(center + Vector2(0, tile_size * 0.05), tile_size * 0.24, Color(palette["shadow"].r, palette["shadow"].g, palette["shadow"].b, 0.90))
	# Head
	draw_circle(center + Vector2(0, -tile_size * 0.14), tile_size * 0.12, Color(palette["shadow"].r, palette["shadow"].g, palette["shadow"].b, 0.86))
	# Mirror axis indicators — faint inward lines at sides suggest mirrored movement
	draw_line(center + Vector2(-tile_size * 0.28, 0), center + Vector2(-tile_size * 0.18, 0), Color(palette["shadow"].r, palette["shadow"].g, palette["shadow"].b, 0.28), 1.5)
	draw_line(center + Vector2(tile_size * 0.28, 0), center + Vector2(tile_size * 0.18, 0), Color(palette["shadow"].r, palette["shadow"].g, palette["shadow"].b, 0.28), 1.5)

func _draw_player(layer_index: int, board_origin: Vector2, tile_size: float, palette: Dictionary) -> void:
	var player: Dictionary = runtime.get("player", {})
	if int(player.get("layer", -1)) != layer_index:
		return

	var center: Vector2 = board_origin + Vector2(int(player.get("x", 0)) * tile_size + tile_size * 0.5, int(player.get("y", 0)) * tile_size + tile_size * 0.5)
	draw_circle(center + Vector2(0, 5), tile_size * 0.3, Color(0, 0, 0, 0.08))
	draw_circle(center, tile_size * 0.24, palette["player"])
	draw_circle(center + Vector2(0, -tile_size * 0.16), tile_size * 0.11, Color("f6dfc2"))
	_draw_panel(Rect2(center.x - tile_size * 0.08, center.y - tile_size * 0.01, tile_size * 0.16, tile_size * 0.18), palette["player"].darkened(0.08), Color(0, 0, 0, 0), 6, 0)
	_draw_panel(Rect2(center.x + tile_size * 0.06, center.y - tile_size * 0.01, tile_size * 0.09, tile_size * 0.12), palette["parcel"].darkened(0.06), Color(0, 0, 0, 0), 4, 0)
	var facing := String(player.get("facing", "right"))
	var marker := PackedVector2Array()
	match facing:
		"left":
			marker = PackedVector2Array([center + Vector2(-tile_size * 0.28, 0), center + Vector2(-tile_size * 0.1, -tile_size * 0.08), center + Vector2(-tile_size * 0.1, tile_size * 0.08)])
		"up":
			marker = PackedVector2Array([center + Vector2(0, -tile_size * 0.3), center + Vector2(-tile_size * 0.08, -tile_size * 0.12), center + Vector2(tile_size * 0.08, -tile_size * 0.12)])
		"down":
			marker = PackedVector2Array([center + Vector2(0, tile_size * 0.3), center + Vector2(-tile_size * 0.08, tile_size * 0.12), center + Vector2(tile_size * 0.08, tile_size * 0.12)])
		_:
			marker = PackedVector2Array([center + Vector2(tile_size * 0.28, 0), center + Vector2(tile_size * 0.1, -tile_size * 0.08), center + Vector2(tile_size * 0.1, tile_size * 0.08)])
	draw_colored_polygon(marker, Color("fff8ec"))

func _draw_stitch_threads(board_data: Array, palette: Dictionary) -> void:
	if board_data.size() < 2:
		return
	for index in range(board_data.size() - 1):
		var left: Dictionary = board_data[index]
		var right: Dictionary = board_data[index + 1]
		var left_tiles: Array = room.get("layers", [])[int(left["index"])].get("tiles", [])
		var right_tiles: Array = room.get("layers", [])[int(right["index"])].get("tiles", [])
		for y in range(left_tiles.size()):
			var left_row := String(left_tiles[y])
			var right_row := String(right_tiles[y]) if y < right_tiles.size() else ""
			for x in range(left_row.length()):
				if x >= right_row.length():
					continue
				if left_row.substr(x, 1) != "S" or right_row.substr(x, 1) != "S":
					continue
				var left_point := Vector2(left["origin"].x + (float(x) + 1.0) * float(left["tileSize"]) - 2.0, left["origin"].y + (float(y) + 0.5) * float(left["tileSize"]))
				var right_point := Vector2(right["origin"].x + 2.0, right["origin"].y + (float(y) + 0.5) * float(right["tileSize"]))
				_draw_stitched_line(left_point, right_point, palette["stitch"], 8.0, 6.0, 2.0)

func _draw_stitched_line(from_point: Vector2, to_point: Vector2, color: Color, stitch_length: float, gap_length: float, width: float) -> void:
	var delta := to_point - from_point
	var total_length := delta.length()
	if total_length <= 0.0:
		return
	var direction := delta / total_length
	var distance := 0.0
	while distance < total_length:
		var segment_start := from_point + direction * distance
		var segment_end := from_point + direction * minf(distance + stitch_length, total_length)
		draw_line(segment_start, segment_end, color, width)
		distance += stitch_length + gap_length

func _get_palette(district_id: String) -> Dictionary:
	var accent := BASE_ACTIVE_STRIP
	var secondary := BASE_STITCH
	match district_id:
		"mailroom":
			accent = Color("d89d47")
			secondary = Color("c46a4c")
		"market":
			accent = Color("cf8f44")
			secondary = Color("b85d53")
		"greenhouse":
			accent = Color("91b368")
			secondary = Color("688d5d")
		"clocktower":
			accent = Color("7c95b8")
			secondary = Color("60738e")
		"theater":
			accent = Color("9c7db9")
			secondary = Color("6f5d82")
		"rooftops":
			accent = Color("d8a04a")
			secondary = Color("c66f49")
		"attic":
			accent = Color("b98c57")
			secondary = Color("8b6b4e")

	var palette := {
		"desk": BASE_DESK,
		"desk_shadow": BASE_DESK_SHADOW,
		"backdrop_band": Color("f2e5ca"),
		"paper": BASE_PAPER,
		"paper_alt": BASE_PAPER_ALT,
		"paper_border": BASE_PAPER_BORDER,
		"wall": BASE_WALL,
		"floor": BASE_FLOOR,
		"stitch": secondary,
		"goal": BASE_GOAL,
		"gap": BASE_GAP,
		"bridge": BASE_BRIDGE,
		"player": BASE_PLAYER,
		"parcel": BASE_PARCEL,
		"projector": BASE_PROJECTOR,
		"echo": BASE_ECHO,
		"shadow": BASE_SHADOW,
		"routing": BASE_ROUTING,
		"active_strip": accent,
		"inactive_strip": BASE_INACTIVE_STRIP,
		"grid_line": BASE_GRID_LINE,
	}

	if high_contrast:
		palette["paper"] = Color("fffef8")
		palette["paper_alt"] = Color("f0eadf")
		palette["paper_border"] = Color("6e5744")
		palette["wall"] = Color("5b4635")
		palette["floor"] = Color("fff7ea")
		palette["gap"] = Color("8c7a5c")
		palette["bridge"] = Color("5aa554")
		palette["player"] = Color("1b4f8f")
		palette["parcel"] = Color("b04a2d")
		palette["echo"] = Color("556fd8")
		palette["shadow"] = Color("111111")
		palette["routing"] = Color("b1411e")
		palette["grid_line"] = Color("7d6951")

	if colorblind_mode == "deuteranopia":
		palette["player"] = Color("0072b2")
		palette["parcel"] = Color("d55e00")
		palette["echo"] = Color("cc79a7")
		palette["shadow"] = Color("222222")
		palette["goal"] = Color("f0e442")
		palette["bridge"] = Color("009e73")
	elif colorblind_mode == "protanopia":
		palette["player"] = Color("0072b2")
		palette["parcel"] = Color("e69f00")
		palette["echo"] = Color("cc79a7")
		palette["shadow"] = Color("222222")
		palette["goal"] = Color("f0e442")
		palette["bridge"] = Color("56b4e9")
	elif colorblind_mode == "tritanopia":
		palette["player"] = Color("d55e00")
		palette["parcel"] = Color("0072b2")
		palette["echo"] = Color("cc79a7")
		palette["shadow"] = Color("222222")
		palette["goal"] = Color("e69f00")
		palette["bridge"] = Color("009e73")

	return palette
