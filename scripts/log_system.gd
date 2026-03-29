extends Node2D

## Fireplace 2 — Log System
## Spawning, dragging, burning, and auto-log upgrade.

signal log_burned(pos: Vector2, was_big: bool)

const SF := 4.0
const SCREEN_W := 640
const SCREEN_H := 480
const Y_POSITIONS := [74, 58, 42]  # MakeCode coords for 3 log slots

var log_slots: Array = [null, null, null]
var log_grabbed: Array[bool] = [false, false, false]
var log_is_big: Array[bool] = [false, false, false]

var _fire_zone: Rect2 = Rect2()
var _auto_log_timer: float = 0.0
const AUTO_LOG_INTERVAL := 8.0  # seconds between auto-fed logs

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	spawn_timer.wait_time = 2.65
	spawn_timer.timeout.connect(_on_spawn_tick)
	spawn_timer.start()

func set_fire_zone(rect: Rect2) -> void:
	_fire_zone = rect

func _process(delta: float) -> void:
	_check_fire_overlap()
	_remove_offscreen()

	# Auto-log upgrade
	if GameManager.upgrade_auto_log and GameManager.fire_level > 0:
		_auto_log_timer += delta
		if _auto_log_timer >= AUTO_LOG_INTERVAL:
			_auto_log_timer = 0.0
			_auto_feed_log()

func drag_to(cursor_pos: Vector2) -> void:
	for i in range(3):
		if log_grabbed[i] and log_slots[i] != null:
			log_slots[i].position = cursor_pos

func try_grab(cursor_pos: Vector2) -> bool:
	for i in range(3):
		if log_slots[i] != null:
			if log_slots[i].position.distance_to(cursor_pos) < 30.0 * SF:
				log_grabbed[i] = true
				return true
	return false

func release_all() -> void:
	for i in range(3):
		log_grabbed[i] = false

func any_grabbed() -> bool:
	return log_grabbed[0] or log_grabbed[1] or log_grabbed[2]

func all_null() -> bool:
	return log_slots[0] == null and log_slots[1] == null and log_slots[2] == null

func spawn_log(is_big: bool) -> void:
	if GameManager.log_count >= GameManager.get_log_cap():
		return
	var slot := _find_empty_slot()
	if slot == -1:
		return

	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/BIGwood.png") if is_big else preload("res://assets/sprites/wood0.png")
	spr.position = Vector2(134, Y_POSITIONS[slot]) * SF
	log_is_big[slot] = is_big
	add_child(spr)
	log_slots[slot] = spr
	GameManager.log_count += 1
	Effects.log_spawn_puff(self, spr.position)
	AudioManager.play_sfx("big_log" if is_big else "log_spawn")

func _burn_log(slot: int) -> void:
	var pos := log_slots[slot].position
	var was_big := log_is_big[slot]
	log_slots[slot].queue_free()
	log_slots[slot] = null
	log_grabbed[slot] = false

	var fire_add := GameManager.get_fire_bonus()
	if was_big:
		fire_add += 1.0
	if GameManager.upgrade_kindling and GameManager.fire_level < 1.0:
		fire_add += 1.0
	GameManager.add_fire(fire_add)
	GameManager.log_count = max(0, GameManager.log_count - 1)
	GameManager.total_logs_burned += 1
	log_is_big[slot] = false

	Effects.fire_burst(self, pos)
	AudioManager.play_sfx("burn")
	log_burned.emit(pos, was_big)

func _check_fire_overlap() -> void:
	if _fire_zone.size == Vector2.ZERO:
		return
	for i in range(3):
		if log_slots[i] == null:
			continue
		if _fire_zone.has_point(log_slots[i].position):
			_burn_log(i)

func _remove_offscreen() -> void:
	for i in range(3):
		if log_slots[i] == null:
			continue
		var p: Vector2 = log_slots[i].position
		if p.x < -80 or p.x > SCREEN_W + 80 or p.y < -80 or p.y > SCREEN_H + 80:
			log_slots[i].queue_free()
			log_slots[i] = null
			GameManager.log_count = max(0, GameManager.log_count - 1)
			log_grabbed[i] = false

func _find_empty_slot() -> int:
	for i in range(3):
		if log_slots[i] == null:
			return i
	return -1

func _auto_feed_log() -> void:
	# Find a log and teleport it into the fire zone
	for i in range(3):
		if log_slots[i] != null and not log_grabbed[i]:
			var fire_center := _fire_zone.get_center()
			log_slots[i].position = fire_center
			Effects.smoke_puff(self, fire_center + Vector2(0, -20))
			return
	# No log exists — spawn and burn instantly
	if GameManager.log_count < GameManager.get_log_cap():
		spawn_log(false)
		# The fire overlap check will burn it next frame

# ═══════════════════════════════════════════════════════════
# SPAWNING LOGIC (pity system from original)
# ═══════════════════════════════════════════════════════════

func _on_spawn_tick() -> void:
	var can_spawn: bool = GameManager.log_count < GameManager.get_log_cap() \
		and GameManager.fire_level > 0 \
		and not any_grabbed()

	if not can_spawn:
		if GameManager.fire_level > 0:
			GameManager.pity += 1
		return

	# Normal log
	var normal_roll := randf() < 0.2164
	var normal_pity := GameManager.pity >= 8 and randf() < 0.6125
	if normal_roll or normal_pity:
		GameManager.pity = 0
		spawn_log(false)
		return

	# Big log (lucky_logs doubles chance)
	var big_chance := 0.0056 * (2.0 if GameManager.upgrade_lucky_logs else 1.0)
	var big_roll := randf() < 0.19875 and randf() < big_chance
	var big_pity := GameManager.pity >= 10 and randf() < 0.8575
	if big_roll or big_pity:
		GameManager.pity = 0
		spawn_log(true)
		AudioManager.play_sfx("achievement")
		if GameManager.score < 500:
			GameManager.change_score(485)
		else:
			GameManager.change_score(120)
		return

	GameManager.pity += 1
