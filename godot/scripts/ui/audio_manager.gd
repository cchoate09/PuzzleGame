class_name AudioManager
extends Node

const MIX_RATE := 44100
const SFX_BUS_NAME := &"SFX"
const SFX_DEFAULT_DB := -8.0

var stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(SFX_BUS_NAME) == -1:
		var sfx_idx := AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, SFX_BUS_NAME)
		AudioServer.set_bus_send(sfx_idx, &"Master")
		AudioServer.set_bus_volume_db(sfx_idx, SFX_DEFAULT_DB)

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
	stream_cache.clear()

func play_event(event_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStreamWAV = _get_stream(event_name)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS_NAME
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func set_master_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), db)

func set_sfx_volume_db(db: float) -> void:
	var idx := AudioServer.get_bus_index(SFX_BUS_NAME)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)

func _get_stream(event_name: String) -> AudioStreamWAV:
	if not stream_cache.has(event_name):
		stream_cache[event_name] = _build_stream(event_name)
	return stream_cache.get(event_name, null)

func _build_stream(event_name: String) -> AudioStreamWAV:
	match event_name:
		"move":
			return _create_stream(0.08, [{"freq": 420.0, "gain": 0.65, "wave": "triangle"}], 0.18, 0.003)
		"push":
			return _create_stream(0.12, [
				{"freq": 210.0, "gain": 0.32, "wave": "triangle"},
				{"freq": 310.0, "gain": 0.14, "wave": "square"},
			], 0.22, 0.004)
		"wait":
			return _create_stream(0.06, [{"freq": 280.0, "gain": 0.32, "wave": "sine"}], 0.04, 0.002)
		"switch_layer":
			return _create_stream(0.18, [
				{"freq": 370.0, "gain": 0.32, "wave": "sine"},
				{"freq": 554.0, "gain": 0.24, "wave": "triangle"},
			], 0.06, 0.01)
		"transfer":
			return _create_stream(0.16, [
				{"freq": 260.0, "gain": 0.24, "wave": "square"},
				{"freq": 390.0, "gain": 0.18, "wave": "triangle"},
			], 0.1, 0.008)
		"undo":
			return _create_stream(0.12, [{"freq": 260.0, "gain": 0.32, "wave": "sine"}], 0.04, 0.004)
		"redo":
			return _create_stream(0.12, [{"freq": 330.0, "gain": 0.32, "wave": "sine"}], 0.04, 0.004)
		"reset":
			return _create_stream(0.2, [
				{"freq": 180.0, "gain": 0.16, "wave": "triangle"},
				{"freq": 96.0, "gain": 0.12, "wave": "sine"},
			], 0.18, 0.012)
		"hint":
			return _create_stream(0.14, [{"freq": 620.0, "gain": 0.26, "wave": "sine"}], 0.03, 0.004)
		"enter":
			return _create_stream(0.22, [
				{"freq": 240.0, "gain": 0.16, "wave": "triangle"},
				{"freq": 360.0, "gain": 0.14, "wave": "sine"},
			], 0.12, 0.008)
		"solve":
			return _create_stream(0.36, [
				{"freq": 392.0, "gain": 0.2, "wave": "sine"},
				{"freq": 523.25, "gain": 0.18, "wave": "triangle"},
				{"freq": 659.25, "gain": 0.14, "wave": "sine"},
			], 0.05, 0.012)
		_:
			return _create_stream(0.08, [{"freq": 300.0, "gain": 0.24, "wave": "sine"}], 0.04, 0.002)

func _create_stream(duration: float, partials: Array, noise_gain: float, attack: float) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(round(duration * MIX_RATE)))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for sample_index in range(sample_count):
		var t := float(sample_index) / float(MIX_RATE)
		var envelope := _envelope(t, duration, attack)
		var sample_value := 0.0

		for partial in partials:
			sample_value += _waveform(
				String(partial.get("wave", "sine")),
				float(partial.get("freq", 440.0)),
				t
			) * float(partial.get("gain", 0.2))

		sample_value += rng.randf_range(-1.0, 1.0) * noise_gain * envelope
		sample_value *= envelope
		sample_value = clampf(sample_value, -0.95, 0.95)

		var s16 := int(round(sample_value * 32767.0))
		var offset := sample_index * 2
		pcm[offset] = s16 & 0xFF
		pcm[offset + 1] = (s16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

func _envelope(t: float, duration: float, attack: float) -> float:
	var attack_factor: float = minf(1.0, t / maxf(attack, 0.001))
	var release_factor := pow(max(0.0, 1.0 - t / max(duration, 0.001)), 1.8)
	return attack_factor * release_factor

func _waveform(kind: String, frequency: float, time_value: float) -> float:
	var phase := TAU * frequency * time_value
	match kind:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle":
			return (2.0 / PI) * asin(sin(phase))
		_:
			return sin(phase)
