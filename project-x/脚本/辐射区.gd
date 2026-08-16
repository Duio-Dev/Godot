extends Area2D

@export var radiation_level: float = 1.0

const SAMPLE_RATE: int = 44100
const PULSE_FREQ_MIN: float = 2600.0
const PULSE_FREQ_MAX: float = 2900.0
const Q_MIN: float = 8.0
const Q_MAX: float = 10.0
const NOISE_MIN: float = 0.02
const NOISE_MAX: float = 0.08
const AMP_MIN: float = 0.85
const AMP_MAX: float = 1.0
const PULSE_LENGTH: float = 0.035
const DOUBLE_PULSE_CHANCE: float = 0.05

var _player_inside: bool = false
var _player: PlayerCharacter = null

var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

var _time_to_next_click: float = 0.0
var _pulse_active: bool = false
var _pulse_sample_index: int = 0
var _pulse_samples: PackedFloat32Array = []
var _pulse_amplitude: float = 1.0
var _pending_double: bool = false
var _double_delay_samples: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_audio_generator()
	_rng.randomize()

func _setup_audio_generator() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.02
	_audio_player.stream = generator
	_audio_player.play()

	_playback = _audio_player.get_stream_playback()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_inside = true
		_player = body
		_time_to_next_click = _rng.randf_range(0.0, _get_avg_interval())

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
		_player = null

func _process(delta: float) -> void:
	if _player_inside and _player:
		# 每秒最多变化10，5秒即可达到50
		_player.radiation = move_toward(_player.radiation, radiation_level, 10.0 * delta)

	if not _player_inside:
		return

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var buffer := PackedVector2Array()
	buffer.resize(frames_available)

	for i in range(frames_available):
		if _pending_double and not _pulse_active:
			if _double_delay_samples <= 0:
				_generate_new_pulse()
				_pending_double = false
			else:
				_double_delay_samples -= 1

		if not _pulse_active and not _pending_double:
			_time_to_next_click -= 1.0 / SAMPLE_RATE

		if not _pulse_active and _time_to_next_click <= 0.0 and not _pending_double:
			_generate_new_pulse()
			if _rng.randf() < DOUBLE_PULSE_CHANCE:
				_pending_double = true
				_double_delay_samples = _rng.randi_range(2, 8)
			else:
				_time_to_next_click = _get_random_interval()

		var sample_val: float = 0.0
		if _pulse_active:
			sample_val = _pulse_samples[_pulse_sample_index] * _pulse_amplitude
			_pulse_sample_index += 1
			if _pulse_sample_index >= _pulse_samples.size():
				_pulse_active = false

		buffer[i] = Vector2(sample_val, sample_val)

	_playback.push_buffer(buffer)

func _generate_new_pulse() -> void:
	var freq: float = _rng.randf_range(PULSE_FREQ_MIN, PULSE_FREQ_MAX)
	var q: float = _rng.randf_range(Q_MIN, Q_MAX)
	var noise_level: float = _rng.randf_range(NOISE_MIN, NOISE_MAX)
	_pulse_amplitude = _rng.randf_range(AMP_MIN, AMP_MAX)

	var decay_time: float = q / (PI * freq) * 6.9
	decay_time = clamp(decay_time, 0.005, PULSE_LENGTH)
	var sample_count: int = int(SAMPLE_RATE * decay_time)
	_pulse_samples.resize(sample_count)

	for i in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var attack: float = 1.0
		if t < 0.0001:
			attack = sin(PI * 0.5 * t / 0.0001)

		var envelope: float = exp(-PI * freq * t / q)
		var osc: float = sin(2.0 * PI * freq * t)
		var noise: float = _rng.randf_range(-1.0, 1.0) * noise_level

		_pulse_samples[i] = (osc + noise) * envelope * attack

	_pulse_active = true
	_pulse_sample_index = 0

func _get_avg_interval() -> float:
	if radiation_level > 0.0:
		return 1.0 / radiation_level
	return 1000.0

func _get_random_interval() -> float:
	return -log(_rng.randf()) * _get_avg_interval()
