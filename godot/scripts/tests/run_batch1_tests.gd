extends SceneTree

const ContentLoader = preload("res://scripts/core/content_loader.gd")
const EngineScript = preload("res://scripts/core/patchwork_engine.gd")
const ValidatorScript = preload("res://scripts/core/patchwork_validator.gd")

var failures: Array = []

func _initialize() -> void:
	var campaign: Dictionary = ContentLoader.load_campaign_index()
	var dev_rooms: Dictionary = ContentLoader.load_dev_rooms()
	var solutions: Dictionary = ContentLoader.load_solutions()

	_expect(not campaign.is_empty(), "Campaign JSON should load in the Godot runtime.")
	_expect(not dev_rooms.is_empty(), "Dev room JSON should load in the Godot runtime.")
	_expect(not solutions.is_empty(), "Solutions JSON should load in the Godot runtime.")

	_test_canonical_solutions(campaign, solutions)
	_test_snapshot_controls(campaign)
	_test_replay(campaign, solutions)
	_test_three_layer_room(dev_rooms, solutions)

	if failures.is_empty():
		print("Batch 1 Godot tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_canonical_solutions(campaign: Dictionary, solutions: Dictionary) -> void:
	var room_solutions: Dictionary = solutions.get("canonicalSolutions", {})
	for room_id in room_solutions.keys():
		var engine = EngineScript.new(campaign)
		var room: Dictionary = campaign.get("roomsById", {}).get(room_id, {})
		_expect(not room.is_empty(), "Unknown room in canonical solutions: %s" % room_id)
		engine.load_room(room_id)
		for action in room_solutions[room_id]:
			_expect(engine.dispatch(action), "Canonical action %s should change state in %s." % [JSON.stringify(action), room_id])
		var runtime: Dictionary = engine.get_runtime()
		_expect(runtime.get("solved", false), "%s should solve with its canonical solution." % room_id)
		_expect(int(runtime.get("moveCount", -1)) == room_solutions[room_id].size(), "%s move count should match canonical solution length." % room_id)

func _test_snapshot_controls(campaign: Dictionary) -> void:
	# mailroom-02 "Stamped Twice": start at (1,8) facing right.
	# Navigate up three tiles to (1,5), then right to (2,5) facing right.
	# Parcel-a sits at (3,5) on layer 0. Transfer sends it to layer 1.
	var engine = EngineScript.new(campaign)
	engine.load_room("mailroom-02")

	_expect(engine.dispatch({"type": "move", "direction": "up"}), "mailroom-02 first move (up) should succeed.")
	_expect(engine.dispatch({"type": "move", "direction": "up"}), "mailroom-02 second move (up) should succeed.")
	_expect(engine.dispatch({"type": "move", "direction": "up"}), "mailroom-02 third move (up) should succeed.")
	_expect(engine.dispatch({"type": "move", "direction": "right"}), "mailroom-02 fourth move (right) should succeed.")
	var snapshot_after_moves: Dictionary = engine.get_room_snapshot()
	_expect(int(engine.get_runtime().get("player", {}).get("x", -1)) == 2, "Player should be at x2 after navigating to parcel.")
	_expect(int(engine.get_runtime().get("player", {}).get("y", -1)) == 5, "Player should be at y5 after navigating to parcel.")

	_expect(engine.dispatch({"type": "transfer"}), "mailroom-02 transfer should succeed.")
	_expect(int(engine.get_runtime().get("entities", [])[0].get("layer", -1)) == 1, "Parcel should move to layer 1 after transfer.")

	_expect(engine.dispatch({"type": "undo"}), "Undo should succeed.")
	_expect(int(engine.get_runtime().get("entities", [])[0].get("layer", -1)) == 0, "Undo should return parcel to its original layer.")
	_expect(int(engine.get_runtime().get("player", {}).get("x", -1)) == 2, "Undo should keep the player at x2.")

	_expect(engine.dispatch({"type": "redo"}), "Redo should succeed.")
	_expect(int(engine.get_runtime().get("entities", [])[0].get("layer", -1)) == 1, "Redo should reapply the transfer.")

	engine.restore_snapshot(snapshot_after_moves)
	_expect(int(engine.get_runtime().get("player", {}).get("x", -1)) == 2, "Snapshot restore should return the player to x2.")
	_expect(int(engine.get_runtime().get("entities", [])[0].get("layer", -1)) == 0, "Snapshot restore should return the parcel to layer 0.")

	_expect(engine.dispatch({"type": "reset"}), "Reset should succeed.")
	_expect(int(engine.get_runtime().get("player", {}).get("x", -1)) == 1, "Reset should return the player to the starting x.")
	_expect(int(engine.get_runtime().get("player", {}).get("y", -1)) == 8, "Reset should return the player to the starting y.")
	_expect(int(engine.get_runtime().get("entities", [])[0].get("layer", -1)) == 0, "Reset should return the parcel to layer 0.")
	_expect(int(engine.get_runtime().get("moveCount", -1)) == 0, "Reset should clear move count.")

func _test_replay(campaign: Dictionary, solutions: Dictionary) -> void:
	var actions: Array = solutions.get("canonicalSolutions", {}).get("clocktower-01", [])
	var engine = EngineScript.new(campaign)
	engine.load_room("clocktower-01")
	_expect(engine.start_replay(actions), "Replay should start for clocktower-01.")

	for _index in range(actions.size() + 2):
		engine.update(300.0)

	_expect(engine.get_runtime().get("solved", false), "Replay should solve clocktower-01.")
	_expect(int(engine.get_runtime().get("moveCount", -1)) == actions.size(), "Replay move count should match canonical action count.")

func _test_three_layer_room(dev_rooms: Dictionary, solutions: Dictionary) -> void:
	var proof_room: Dictionary = dev_rooms.get("threeLayerProofRoom", {})
	var issues: Array = ValidatorScript.validate_room(proof_room)
	_expect(issues.size() == 1 and issues[0] == "No structural issues detected. This validator only performs basic checks.", "Three-layer proof room should pass structural validation.")

	var engine = EngineScript.new({})
	engine.load_preview_room(proof_room)
	var visited_layers: Array = [int(engine.get_runtime().get("activeLayer", 0))]
	for action in solutions.get("threeLayerProofSolution", []):
		_expect(engine.dispatch(action), "Three-layer proof action %s should succeed." % JSON.stringify(action))
		var active_layer := int(engine.get_runtime().get("activeLayer", -1))
		if not visited_layers.has(active_layer):
			visited_layers.append(active_layer)

	_expect(engine.get_runtime().get("solved", false), "Three-layer proof room should solve.")
	_expect(
		visited_layers.size() == 3 and visited_layers.has(0) and visited_layers.has(1) and visited_layers.has(2),
		"Three-layer proof room should visit all three layers."
	)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
