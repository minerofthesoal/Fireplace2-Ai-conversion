extends Node2D

## Fireplace 2 — Rain System
## Controls random weather events and rain particles.

@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var toggle_timer: Timer = $ToggleTimer

func _ready() -> void:
	rain_particles.emitting = false
	toggle_timer.wait_time = 6.0
	toggle_timer.timeout.connect(_on_toggle)
	toggle_timer.start()

func _on_toggle() -> void:
	if randf() < 0.222:
		GameManager.raining = true
		rain_particles.emitting = true
		AudioManager.play_sfx("rain_start")
	elif randf() < 0.333:
		GameManager.raining = false
		rain_particles.emitting = false

func force_stop() -> void:
	GameManager.raining = false
	rain_particles.emitting = false
