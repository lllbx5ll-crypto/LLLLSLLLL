extends Node
## Synthesized original placeholder sound effects; replace with licensed field audio later.

const SAMPLE_RATE: int = 22050
var player: AudioStreamPlayer
var ambient: AudioStreamPlayer
var ambient_phase: float = 0.0

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.3
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -9.0
	add_child(player)
	player.play()
	var air := AudioStreamGenerator.new()
	air.mix_rate = SAMPLE_RATE
	air.buffer_length = 0.4
	ambient = AudioStreamPlayer.new()
	ambient.stream = air
	ambient.volume_db = -29.0
	add_child(ambient)
	ambient.play()

func _process(_delta: float) -> void:
	if ambient == null:
		return
	var playback := ambient.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var available: int = mini(playback.get_frames_available(), 1103)
	for i in range(available):
		var val: float = 0.6 * sin(ambient_phase * 0.015) + 0.4 * sin(ambient_phase * 0.037)
		ambient_phase += 1.0
		playback.push_frame(Vector2(val * 0.023, val * 0.023))

func effect(kind: String = "coin") -> void:
	if player == null:
		return
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames: int = mini(playback.get_frames_available(), 3307)
	var frequency: float = 640.0
	if kind == "error":
		frequency = 160.0
	elif kind == "step":
		frequency = 95.0
	elif kind == "open":
		frequency = 470.0
	for i in range(frames):
		var t: float = float(i) / SAMPLE_RATE
		var decay: float = exp(-t * (18.0 if kind != "open" else 10.0))
		var frequency_bend: float = frequency + 190.0 * t if kind == "coin" else frequency
		var value: float = sin(TAU * frequency_bend * t) * decay * 0.25
		if kind == "step":
			value *= randf_range(-1.0, 1.0)
		playback.push_frame(Vector2(value, value))
