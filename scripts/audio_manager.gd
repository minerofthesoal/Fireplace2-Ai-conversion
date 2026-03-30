extends Node

## Fireplace 2 — Audio Manager (Autoload)
## Procedurally generates warm ambient music and crisp sound effects.

var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.4

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sample_rate := 22050.0
var _music_playback: AudioStreamGeneratorPlayback
var _music_time: float = 0.0
var _music_playing: bool = false

# Warm pentatonic scale (C major pentatonic + octave)
const SCALE: Array[float] = [
	261.6, 293.7, 329.6, 392.0, 440.0,  # C4 D4 E4 G4 A4
	523.3, 587.3, 659.3, 784.0, 880.0,  # C5 D5 E5 G5 A5
]
const BASS: Array[float] = [65.4, 73.4, 82.4, 98.0, 110.0]  # C2-A2

var _current_melody: Array[int] = []
var _current_bass: Array[int] = []
var _note_duration: float = 0.5
var _melody_bar: int = 0

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

func _process(_delta: float) -> void:
	if _music_playing and _music_playback != null:
		_fill_music_buffer()

func start_music() -> void:
	_generate_melody()
	_music_player.play()
	_music_playback = _music_player.get_stream_playback()
	_music_playing = true
	_music_time = 0.0
	_melody_bar = 0

func stop_music() -> void:
	_music_playing = false
	_music_player.stop()

func _generate_melody() -> void:
	_current_melody.clear()
	_current_bass.clear()
	# Create a gentle 8-note melody phrase
	for i in range(8):
		# Favor lower notes for warmth
		var note_idx: int = randi_range(0, 7)
		_current_melody.append(note_idx)
		_current_bass.append(randi_range(0, BASS.size() - 1))
	_note_duration = randf_range(0.4, 0.65)

func _fill_music_buffer() -> void:
	var frames_available: int = _music_playback.get_frames_available()
	for i in range(frames_available):
		var t: float = _music_time
		_music_time += 1.0 / _sample_rate

		# Current note
		var note_pos: float = fmod(t / _note_duration, float(_current_melody.size()))
		var note_idx: int = int(note_pos)
		var note_progress: float = note_pos - float(note_idx)

		var freq: float = SCALE[_current_melody[note_idx]]
		var bass_freq: float = BASS[_current_bass[note_idx % _current_bass.size()]]

		# Soft sine melody with warm envelope
		var env: float = _warm_envelope(note_progress)
		var melody_val: float = sin(t * freq * TAU) * 0.12 * env
		# Add soft harmonic
		melody_val += sin(t * freq * 2.0 * TAU) * 0.02 * env

		# Deep warm bass pad (low sine + sub-octave)
		var bass_env: float = 0.8 + 0.2 * sin(t * 0.5 * TAU)
		var bass_val: float = sin(t * bass_freq * TAU) * 0.08 * bass_env
		bass_val += sin(t * bass_freq * 0.5 * TAU) * 0.04 * bass_env

		# Fire crackle ambience
		var crackle: float = 0.0
		if randf() < 0.005:
			crackle = randf_range(-0.06, 0.06)

		# Soft wind pad
		var wind_pad: float = sin(t * 0.3 * TAU) * 0.015

		var sample: float = (melody_val + bass_val + crackle + wind_pad) * music_volume * master_volume
		_music_playback.push_frame(Vector2(sample, sample))

	# Regenerate melody every ~4 bars
	if _music_time > _note_duration * _current_melody.size() * 4:
		_music_time = 0.0
		_melody_bar += 1
		if _melody_bar % 2 == 0 or randf() < 0.3:
			_generate_melody()

func _warm_envelope(progress: float) -> float:
	# Soft attack, long sustain, gentle release
	if progress < 0.08:
		return progress / 0.08
	elif progress < 0.15:
		return lerpf(1.0, 0.7, (progress - 0.08) / 0.07)
	elif progress < 0.75:
		return 0.7
	else:
		return lerpf(0.7, 0.0, (progress - 0.75) / 0.25)

# ═══════════════════════════════════════════════════════════
# SOUND EFFECTS
# ═══════════════════════════════════════════════════════════

func play_sfx(type: String) -> void:
	var samples := PackedFloat32Array()
	match type:
		"burn":
			samples = _gen_burn_sfx()
		"log_spawn":
			samples = _gen_pop_sfx(340.0)
		"big_log":
			samples = _gen_pop_sfx(200.0)
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
		"wind_gust":
			samples = _gen_wind_sfx()
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
	var len_samples: int = int(_sample_rate * 0.5)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.5)
		# Crackling fire sound with pitch sweep
		var freq: float = 200.0 + (0.5 - t) * 300.0
		var val: float = sin(t * freq * TAU) * 0.2 * env
		val += randf_range(-0.15, 0.15) * env * env  # Noise
		# Add sizzle
		val += sin(t * 3000.0 * TAU) * 0.03 * env * env * env
		s[i] = val
	return s

func _gen_pop_sfx(freq: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.18)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.18)
		var f: float = freq * (1.0 + (0.18 - t) * 4.0)
		s[i] = sin(t * f * TAU) * 0.35 * env * env
	return s

func _gen_click_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.06)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.06)
		s[i] = sin(t * 900.0 * TAU) * 0.25 * env
		s[i] += sin(t * 1800.0 * TAU) * 0.1 * env * env
	return s

func _gen_tick_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.04)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.04)
		s[i] = sin(t * 1400.0 * TAU) * 0.12 * env
	return s

func _gen_coin_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.35)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.35)
		# Two-tone rising chime
		var f: float = 660.0 if t < 0.12 else 990.0
		s[i] = sin(t * f * TAU) * 0.2 * env
		s[i] += sin(t * f * 2.0 * TAU) * 0.08 * env  # Harmonic
	return s

func _gen_buzz_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.25)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 0.25)
		s[i] = (sin(t * 110.0 * TAU) * 0.4 + sin(t * 165.0 * TAU) * 0.25) * env * 0.35
	return s

func _gen_whoosh_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.6)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = sin(t / 0.6 * PI)
		# Filtered noise
		var noise: float = randf_range(-0.12, 0.12) * env
		# Add gentle sweep
		noise += sin(t * 80.0 * TAU) * 0.04 * env
		s[i] = noise
	return s

func _gen_wind_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 1.0)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = sin(t * PI)
		var noise: float = randf_range(-0.1, 0.1) * env
		noise += sin(t * 40.0 * TAU) * 0.06 * env
		noise += sin(t * 60.0 * TAU) * 0.03 * env
		s[i] = noise
	return s

func _gen_explosion_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 1.0)
	s.resize(len_samples)
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var env: float = maxf(0.0, 1.0 - t / 1.0)
		env = env * env  # Squared for fast decay
		var low: float = sin(t * 50.0 * TAU) * 0.4
		var mid: float = sin(t * 120.0 * TAU) * 0.2 * maxf(0.0, 1.0 - t / 0.3)
		var noise: float = randf_range(-0.35, 0.35)
		s[i] = (low + mid + noise) * env * 0.45
	return s

func _gen_chime_sfx() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var len_samples: int = int(_sample_rate * 0.7)
	s.resize(len_samples)
	var notes: Array[float] = [523.3, 659.3, 784.0, 1047.0]  # C5 E5 G5 C6
	for i in range(len_samples):
		var t: float = float(i) / _sample_rate
		var val: float = 0.0
		for n_idx in range(notes.size()):
			var delay: float = n_idx * 0.1
			if t > delay:
				var lt: float = t - delay
				var env: float = maxf(0.0, 1.0 - lt / 0.5)
				val += sin(lt * notes[n_idx] * TAU) * 0.12 * env
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
		var val: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav
