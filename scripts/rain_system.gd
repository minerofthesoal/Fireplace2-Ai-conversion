extends Node2D

## Fireplace 2 — Rain & Wind System
## Random weather events: rain and wind gusts.

signal wind_started
signal wind_ended

@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var toggle_timer: Timer = $ToggleTimer
@onready var wind_timer: Timer = $WindTimer

var _wind_duration_timer: float = 0.0
const WIND_DURATION: float = 8.0

func _ready() -> void:
	rain_particles.emitting = false

	toggle_timer.wait_time = 6.0
	toggle_timer.timeout.connect(_on_rain_toggle)
	toggle_timer.start()

	wind_timer.wait_time = 15.0
	wind_timer.timeout.connect(_on_wind_check)
	wind_timer.start()

func _process(delta: float) -> void:
	if GameManager.wind_active:
		_wind_duration_timer += delta
		if _wind_duration_timer >= WIND_DURATION:
			_end_wind()

func _on_rain_toggle() -> void:
	if randf() < 0.222:
		GameManager.raining = true
		rain_particles.emitting = true
		AudioManager.play_sfx("rain_start")
	elif randf() < 0.333:
		GameManager.raining = false
		rain_particles.emitting = false

func _on_wind_check() -> void:
	if GameManager.wind_active:
		return
	if GameManager.fire_level < 1.0:
		return
	# Wind chance increases with game time
	var chance: float = 0.15 + minf(GameManager.game_time / 600.0, 0.25)
	if randf() < chance:
		_start_wind()

func _start_wind() -> void:
	GameManager.wind_active = true
	_wind_duration_timer = 0.0
	wind_started.emit()
	AudioManager.play_sfx("rain_start")

func _end_wind() -> void:
	GameManager.wind_active = false
	_wind_duration_timer = 0.0
	GameManager.wind_events_survived += 1
	wind_ended.emit()
	if GameManager.wind_events_survived >= 5:
		GameManager.try_achievement("survivor")
	if GameManager.wind_events_survived >= 20:
		GameManager.try_achievement("wind_master")

func force_stop() -> void:
	GameManager.raining = false
	GameManager.wind_active = false
	rain_particles.emitting = false
