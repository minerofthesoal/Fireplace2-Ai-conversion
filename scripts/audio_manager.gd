extends Node

## Fireplace 2 — Audio Manager (Autoload)
## Procedurally generates music and sound effects using AudioStreamGenerator.

var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.4

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sample_rate := 22050.0
var _music_playback: AudioStreamGeneratorPlayback
var _music_phase: float = 0.0
var _music_time: float = 0.0
var _music_playing: bool = false

# Current melody state
var _melody_note_idx: int = 0
var _melody_timer: float = 0.0

# Pentatonic scale frequencies (warm fireplace vibe)
const SCALE: Array[float] = [
	196.0, 220.0, 261.6, 293.7, 329.6,  # G3, A3, C4, D4, E4
	392.0, 440.0, 523.3, 587.3, 659.3,  # G4, A4, C5, D5, E5
]
const BASS: Array[float] = [98.0, 110.0, 130.8, 146.8, 164.8]

var _current_melody: Array[int] = []
var _current_bass: Array[int] = []
var _note_duration: float = 0.5

func _ready() -> void:
	_setup_music_player()
	_setup_sfx_player()

func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = _sample_rate
	stream.buffer_length = 0.5
	_music_player.stream = stream
	_music_player.bus = "Master"
	add_child(_music_player)

func _setup_sfx_player() -> void:
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

func _process(delta: float) -> void:
	if _music_playing and _music_playback != null:
		_fill_music_buffer()

func start_music() -> void:
	_generate_melody()
	_music_player.play()
	_music_playback = _music_player.get_stream_playback()
	_music_playing = true
	_music_time = 0.0
	_melody_note_idx = 0
	_melody_timer = 0.0

func stop_music() -> void:
	_music_playing = false
	_music_player.stop()

func _generate_melody() -> void:
	_current_melody.clear()
	_current_bass.clear()
	for i in range(16):
		_current_melody.append(randi_range(0, SCALE.size() - 1))
		_current_bass.append(randi_range(0, BASS.size() - 1))
	_note_duration = randf_range(0.35, 0.6)

func _fill_music_buffer() -> void:
	var frames_available := _music_playback.get_frames_available()
	for i in range(frames_available):
		var t := _music_time
		_music_time += 1.0 / _sample_rate

		# Melody
		var note_idx := int(fmod(t / _note_duration, _current_melody.size()))
		var freq := SCALE[_current_melody[note_idx]]
		var bass_freq := BASS[_current_bass[note_idx % _current_bass.size()]]

		# Soft sine wave melody with envelope
		var env: float = _note_envelope(fmod(t, _note_duration), _note_duration)
		var melody_sample := sin(t * freq * TAU) * 0.15 * env

		# Warm bass pad
		var bass_sample := sin(t * bass_freq * TAU) * 0.1
		bass_sample += sin(t * bass_freq * 2.0 * TAU) * 0.03

		# Gentle crackle noise (fire ambience)
		var crackle := 0.0
		if randf() < 0.003:
			crackle = randf_range(-0.08, 0.08)

		var sample := (melody_sample + bass_sample + crackle) * music_volume * master_volume
		_music_playback.push_frame(Vector2(sample, sample))

	# Regenerate melody every ~16 bars
	if _music_time > _note_duration * _current_melody.size() * 4:
		_music_time = 0.0
		if randf() < 0.4:
			_generate_melody()

func _note_envelope(pos: float, dur: float) -> float:
	var t := pos / dur
	# Attack-decay-sustain-release
	if t < 0.05:
		return t / 0.05
	elif t < 0.2:
		return lerp(1.0, 0.6, (t - 0.05) / 0.15)
	elif t < 0.8:
		return 0.6
	else:
		return lerp(0.6, 0.0, (t - 0.8) / 0.2)

# ═══════════════════════════════════════════════════════════
# SOUND EFFECTS (procedurally generated one-shots)
# ═══════════════════════════════════════════════════════════

func play_sfx(type: String) -> void:
	var samples := PackedFloat32Array()
	match type:
		"burn":
			samples = _gen_burn_sfx()
		"log_spawn":
			samples = _gen_pop_sfx(300.0)
		"big_log":
			samples = _gen_pop_sfx(180.0)
		"button_click":
			samples = _gen_click_sfx()
		"shop_buy":
			samples = _gen_coin_sfx()
		"shop_fail":
			samples = _gen_buzz_sfx()
		"rain_start":
			samples = _gen_whoosh_sfx()
		"ending_explosion":
			samples = _gen_explosion_sfx()
		"achievement":
			samples = _gen_chime_sfx()
		"menu_hover":
			samples = _gen_tick_sfx()
		_:
			return

	if samples.size() == 0:
		return

	var player := AudioStreamPlayer.new()
	var wav := _samples_to_wav(samples)
	player.stream = wav
	player.volume_db = linear_to_db(sfx_volume * master_volume)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _gen_burn_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.4)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.4)
		s[i] = (sin(t * 220.0 * TAU) * 0.3 + randf_range(-0.2, 0.2)) * env
	return s

func _gen_pop_sfx(freq: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.15)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.15)
		var f := freq * (1.0 + (0.15 - t) * 3.0)
		s[i] = sin(t * f * TAU) * 0.4 * env * env
	return s

func _gen_click_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.05)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.05)
		s[i] = sin(t * 800.0 * TAU) * 0.3 * env
	return s

func _gen_tick_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.03)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		s[i] = sin(t * 1200.0 * TAU) * 0.15 * max(0.0, 1.0 - t / 0.03)
	return s

func _gen_coin_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.3)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.3)
		var f := 880.0 if t < 0.1 else 1320.0
		s[i] = sin(t * f * TAU) * 0.25 * env
	return s

func _gen_buzz_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.2)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.2)
		s[i] = (sin(t * 120.0 * TAU) * 0.5 + sin(t * 180.0 * TAU) * 0.3) * env * 0.4
	return s

func _gen_whoosh_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.5)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = sin(t / 0.5 * PI)
		s[i] = randf_range(-0.15, 0.15) * env
	return s

func _gen_explosion_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.8)
	s.resize(len_samples)
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.8) * maxf(0.0, 1.0 - t / 0.8)
		var low := sin(t * 60.0 * TAU) * 0.5
		var noise := randf_range(-0.4, 0.4)
		s[i] = (low + noise) * env * 0.5
	return s

func _gen_chime_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples := int(_sample_rate * 0.6)
	s.resize(len_samples)
	var notes: Array[float] = [523.3, 659.3, 784.0]  # C5, E5, G5
	for i in range(len_samples):
		var t := float(i) / _sample_rate
		var val := 0.0
		for n_idx in range(notes.size()):
			var delay := n_idx * 0.12
			if t > delay:
				var lt := t - delay
				var env: float = maxf(0.0, 1.0 - lt / 0.4)
				val += sin(lt * notes[n_idx] * TAU) * 0.15 * env
		s[i] = val
	return s

func _samples_to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(_sample_rate)
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val := clampi(int(samples[i] * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav
