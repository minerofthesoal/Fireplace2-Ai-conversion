extends Node2D

## Fireplace 2 — Fire System
## Fire decay, animation, sparks, and inferno achievement.

signal fire_died
signal fire_started

@onready var fireplace_sprite: Sprite2D = $FireplaceSprite
@onready var fire_anim: AnimatedSprite2D = $FireAnim
@onready var fire_particles: GPUParticles2D = $FireParticles
@onready var wall_zone: Area2D = $WallZone
@onready var decay_timer: Timer = $DecayTimer
@onready var score_timer: Timer = $ScoreTimer
@onready var spark_timer: Timer = $SparkTimer

var _was_burning: bool = false

func _ready() -> void:
	fire_anim.visible = false
	fire_particles.emitting = false

	decay_timer.wait_time = 0.25
	decay_timer.timeout.connect(_on_decay_tick)
	decay_timer.start()

	score_timer.wait_time = 0.05
	score_timer.timeout.connect(_on_score_tick)
	score_timer.start()

	spark_timer.wait_time = 0.25
	spark_timer.timeout.connect(_on_spark_tick)
	spark_timer.start()

func _on_decay_tick() -> void:
	if GameManager.fire_level < 0.5:
		return
	GameManager.fire_tick += 1
	var thresh: int = 80 if GameManager.upgrade_firebrick else 64
	if GameManager.fire_tick >= thresh:
		var amount: float = 1.0
		if GameManager.raining:
			if GameManager.upgrade_roofing:
				pass
			elif GameManager.upgrade_wind_guard:
				amount += 0.5
			else:
				amount += 1.0
		if GameManager.wind_active:
			if GameManager.upgrade_wind_guard:
				amount += 0.5
			else:
				amount += 1.5
		GameManager.decay_fire(amount)
		GameManager.fire_tick = 0

func _on_score_tick() -> void:
	if GameManager.fire_level >= 1.0:
		GameManager.change_score(GameManager.get_score_per_tick())
		_ensure_fire_anim()
		if not _was_burning:
			_was_burning = true
			fire_started.emit()
	elif GameManager.fire_level < 0.5:
		if _was_burning:
			_was_burning = false
			fire_died.emit()
		GameManager.fire_anim_playing = false
		fire_anim.visible = false
		fire_particles.emitting = false
		fireplace_sprite.texture = preload("res://assets/sprites/myImage1.png")

	# Inferno achievement
	if GameManager.fire_level >= GameManager.get_fire_max():
		GameManager.try_achievement("inferno")

func _ensure_fire_anim() -> void:
	if GameManager.fire_anim_playing:
		return
	GameManager.fire_anim_playing = true
	fire_anim.visible = true
	if GameManager.secret_demon:
		fire_anim.play("fireplace_demon")
	else:
		fire_anim.play("fireplace_normal")
	fire_particles.emitting = true

func _on_spark_tick() -> void:
	fire_particles.emitting = GameManager.fire_level > 0
	# Adjust particle intensity based on fire level
	var mat: ParticleProcessMaterial = fire_particles.process_material as ParticleProcessMaterial
	if mat:
		var intensity: float = clampf(GameManager.fire_level / GameManager.get_fire_max(), 0.0, 1.0)
		mat.initial_velocity_min = 30.0 + intensity * 40.0
		mat.initial_velocity_max = 80.0 + intensity * 60.0
		fire_particles.amount = int(15 + intensity * 25)

func get_fire_zone_rect() -> Rect2:
	return Rect2(wall_zone.global_position - Vector2(60, 30), Vector2(120, 60))
