extends Node2D

## Fireplace 2 — Main scene controller
## Coordinates all gameplay systems: fire, logs, rain, shop, endings, input.

# ── Constants (MakeCode 160x120 → Godot 640x480, scale factor = 4) ──
const SF := 4.0  # scale factor
const SCREEN_W := 640
const SCREEN_H := 480

# ── Node references (assigned in _ready) ──
@onready var background: Sprite2D = $Background
@onready var fireplace_sprite: Sprite2D = $Fireplace
@onready var fireplace_base: Sprite2D = $FireplaceBase
@onready var wall_zone: Area2D = $WallZone  # fire collision area
@onready var cursor: Sprite2D = $Cursor
@onready var heat_bar: ProgressBar = $UI/HeatBar
@onready var score_label: Label = $UI/ScoreLabel
@onready var rain_timer: Timer = $RainTimer
@onready var fire_decay_timer: Timer = $FireDecayTimer
@onready var log_spawn_timer: Timer = $LogSpawnTimer
@onready var score_timer: Timer = $ScoreTimer
@onready var spark_timer: Timer = $SparkTimer
@onready var playlist_timer: Timer = $PlaylistTimer
@onready var fire_anim: AnimatedSprite2D = $FireAnim
@onready var spider_sprite: Sprite2D = $Spider
@onready var temp_icon: Sprite2D = $TempIcon
@onready var end_button: Sprite2D = $EndButton
@onready var achievement_label: Label = $UI/AchievementLabel
@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var speech_label: Label = $UI/SpeechBubble
@onready var mode_label: Label = $UI/ModeLabel
@onready var shop_panel: Panel = $UI/ShopPanel
@onready var shop_label: Label = $UI/ShopPanel/ShopLabel
@onready var fire_particles: GPUParticles2D = $FireParticles

# ── Log slots ──
var log_slots: Array = [null, null, null]  # Sprite2D or null
var log_grabbed: Array[bool] = [false, false, false]
var log_is_big: Array[bool] = [false, false, false]

# ── Input ──
var dpad_speed := 8.0  # pixels per frame (was 2 at 160px, now 8 at 640px)

# ── Tutorial state ──
var _tutorial_running := false
var _tutorial_coroutine: int = 0

# ── Shop state ──
var _shop_open := false
var _shop_expecting_input := false

func _ready() -> void:
	GameManager.reset_game()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Position everything (MakeCode coords × SF)
	fireplace_base.position = Vector2(82, 87) * SF
	fireplace_sprite.position = Vector2(82, 92) * SF
	fireplace_sprite.scale = Vector2(1.32, 1.32)  # ~32.375% scaleByPercent → 1.32x base
	spider_sprite.position = Vector2(47, 33) * SF
	spider_sprite.scale = Vector2(0.75, 0.75)  # 50% scaleByPercent
	temp_icon.position = Vector2(47, 33) * SF
	temp_icon.scale = Vector2(0.75, 0.75)
	end_button.visible = false
	end_button.position = Vector2(23, 51) * SF
	end_button.scale = Vector2(0.375, 0.375)
	speech_label.visible = false
	achievement_label.visible = false
	shop_panel.visible = false
	mode_label.visible = false
	rain_particles.emitting = false
	fire_particles.emitting = false

	# Fire animation setup
	fire_anim.visible = false
	fire_anim.position = Vector2(82, 82) * SF
	fire_anim.scale = Vector2(1.69, 1.69)  # 169.375% scaleToPercent

	# Heat bar
	heat_bar.max_value = 5
	heat_bar.value = 0

	# Spawn first log
	_spawn_log(false)

	# Connect timers
	fire_decay_timer.timeout.connect(_on_fire_decay)
	fire_decay_timer.start(0.25)  # 250ms like original

	log_spawn_timer.timeout.connect(_on_log_spawn)
	log_spawn_timer.start(2.65)  # 2650ms

	score_timer.timeout.connect(_on_score_tick)
	score_timer.start(0.05)  # 50ms

	spark_timer.timeout.connect(_on_spark_tick)
	spark_timer.start(0.251)

	rain_timer.timeout.connect(_on_rain_toggle)
	rain_timer.start(6.0)

	playlist_timer.timeout.connect(_on_playlist_tick)
	playlist_timer.start(23.555)

# ═══════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _shop_open:
		_handle_shop_input(event)
		return

	# Konami code tracking
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP: GameManager.add_combo_input("up")
			KEY_DOWN: GameManager.add_combo_input("down")
			KEY_LEFT: GameManager.add_combo_input("left")
			KEY_RIGHT: GameManager.add_combo_input("right")
			KEY_B: GameManager.add_combo_input("b")
			KEY_A: GameManager.add_combo_input("a")

	# Toggle input mode (A, Down, Left quickly = press T)
	if event.is_action_pressed("toggle_input_mode"):
		GameManager.use_dpad = not GameManager.use_dpad
		_show_mode_label("D-Pad mode ON" if GameManager.use_dpad else "Mouse mode ON")

	# B = open shop in dpad mode
	if event.is_action_pressed("button_b") and GameManager.use_dpad:
		_open_shop()
		return

	# Mouse movement
	if event is InputEventMouseMotion and not GameManager.use_dpad:
		cursor.position = event.position

	# Mouse click - grab logs
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not GameManager.use_dpad:
			_try_grab_log()
		elif not event.pressed and not GameManager.use_dpad:
			_release_logs()
			# Check shop click (bottom-left when no logs)
			if _all_logs_null() and cursor.position.x < 40 * SF and cursor.position.y > 100 * SF:
				_open_shop()
				return
			# Check end button click
			if GameManager.end_button_visible and end_button.visible:
				if _sprites_overlap(cursor, end_button):
					_press_end_button()

	# A button - grab/release in dpad mode
	if event.is_action_pressed("button_a") and GameManager.use_dpad:
		_try_grab_log()
	if event.is_action_released("button_a") and GameManager.use_dpad:
		_release_logs()
		if GameManager.end_button_visible and end_button.visible:
			if _sprites_overlap(cursor, end_button):
				_press_end_button()

func _process(delta: float) -> void:
	# D-pad cursor movement
	if GameManager.use_dpad:
		if Input.is_action_pressed("move_left"):
			cursor.position.x = max(0, cursor.position.x - dpad_speed)
		if Input.is_action_pressed("move_right"):
			cursor.position.x = min(SCREEN_W, cursor.position.x + dpad_speed)
		if Input.is_action_pressed("move_up"):
			cursor.position.y = max(0, cursor.position.y - dpad_speed)
		if Input.is_action_pressed("move_down"):
			cursor.position.y = min(SCREEN_H, cursor.position.y + dpad_speed)

	# Drag grabbed logs
	for i in range(3):
		if log_grabbed[i] and log_slots[i] != null:
			log_slots[i].position = cursor.position

	# Check log-fire overlaps (every frame)
	_check_log_fire_overlap()

	# Update UI
	heat_bar.value = GameManager.fire_level
	score_label.text = "Score: %d" % GameManager.score

	# Spider/tutorial interaction
	if spider_sprite.visible and temp_icon.visible:
		if cursor.position.distance_to(temp_icon.position) < 30 * SF:
			if not GameManager.tutorial_done and GameManager.score <= 155 and GameManager.score > 98:
				if not _tutorial_running:
					_start_tutorial()
			elif GameManager.score <= 155 and GameManager.score > 98:
				if not _tutorial_running:
					_web_clicked_has_money()

# ═══════════════════════════════════════════════════════════
# LOG SYSTEM
# ═══════════════════════════════════════════════════════════

func _spawn_log(is_big: bool) -> void:
	var log_cap := 3 if GameManager.upgrade_log_cap else 2
	if GameManager.log_count >= log_cap:
		return

	var slot := -1
	for i in range(3):
		if log_slots[i] == null:
			slot = i
			break
	if slot == -1:
		return

	var log_sprite := Sprite2D.new()
	if is_big:
		log_sprite.texture = preload("res://assets/sprites/BIGwood.png")
		log_is_big[slot] = true
	else:
		log_sprite.texture = preload("res://assets/sprites/wood0.png")
		log_is_big[slot] = false

	# Position logs at right side, stacked vertically
	var y_positions := [74, 58, 42]
	log_sprite.position = Vector2(134, y_positions[slot]) * SF
	add_child(log_sprite)
	log_slots[slot] = log_sprite
	GameManager.log_count += 1
	_spawn_log_effect(log_sprite.position)

func _try_grab_log() -> void:
	for i in range(3):
		if log_slots[i] != null and _sprites_overlap(log_slots[i], cursor):
			log_grabbed[i] = true
			return

func _release_logs() -> void:
	for i in range(3):
		log_grabbed[i] = false

func _check_log_fire_overlap() -> void:
	var fire_rect := Rect2(wall_zone.position - Vector2(32, 32), Vector2(64, 64))
	for i in range(3):
		if log_slots[i] == null:
			continue
		if fire_rect.has_point(log_slots[i].position):
			_burn_log(i)

func _burn_log(slot: int) -> void:
	var pos := log_slots[slot].position
	log_slots[slot].queue_free()
	log_slots[slot] = null
	log_grabbed[slot] = false
	GameManager.fire_level += 1
	if GameManager.upgrade_bellows:
		GameManager.fire_level += 1
	GameManager.log_count = max(0, GameManager.log_count - 1)
	if log_is_big[slot]:
		GameManager.fire_level += 1
		log_is_big[slot] = false
	_spawn_fire_burst(pos)

func _remove_offscreen_logs() -> void:
	for i in range(3):
		if log_slots[i] == null:
			continue
		var p: Vector2 = log_slots[i].position
		if p.x < -80 or p.x > SCREEN_W + 80 or p.y < -80 or p.y > SCREEN_H + 80:
			log_slots[i].queue_free()
			log_slots[i] = null
			GameManager.log_count = max(0, GameManager.log_count - 1)
			log_grabbed[i] = false

func _all_logs_null() -> bool:
	return log_slots[0] == null and log_slots[1] == null and log_slots[2] == null

func _any_log_grabbed() -> bool:
	return log_grabbed[0] or log_grabbed[1] or log_grabbed[2]

# ═══════════════════════════════════════════════════════════
# FIRE SYSTEM
# ═══════════════════════════════════════════════════════════

func _on_fire_decay() -> void:
	if GameManager.fire_level >= 0.5:
		GameManager.fire_tick += 1

	heat_bar.value = GameManager.fire_level

	var decay_thresh := 80 if GameManager.upgrade_firebrick else 64
	if GameManager.fire_tick >= decay_thresh and GameManager.fire_level >= 0.5:
		GameManager.fire_level -= 1
		if GameManager.raining and not GameManager.upgrade_roofing:
			GameManager.fire_level -= 1
		GameManager.fire_tick = 0

	_remove_offscreen_logs()

	# End button appears at score 1325
	if GameManager.score >= 1325 and not GameManager.end_button_visible:
		GameManager.end_button_visible = true
		end_button.visible = true
		end_button.texture = preload("res://assets/sprites/bigButtonPress0.png")

func _on_score_tick() -> void:
	if GameManager.fire_level >= 1:
		GameManager.change_score(1)
		_update_fire_animation()
	elif GameManager.fire_level < 0.5:
		GameManager.fire_anim_playing = false
		fire_anim.visible = false
		fire_particles.emitting = false
		fireplace_sprite.texture = preload("res://assets/sprites/myImage1.png")
		fireplace_sprite.position = Vector2(82, 92) * SF

func _update_fire_animation() -> void:
	if GameManager.fire_anim_playing:
		return
	GameManager.fire_anim_playing = true

	if GameManager.secret_demon:
		fire_anim.visible = true
		fire_anim.play("fireplace_demon")
		fireplace_sprite.position = Vector2(82, 78) * SF
		_show_achievement("DEMON", "Discover the fire demon")
	else:
		fire_anim.visible = true
		fire_anim.play("fireplace_normal")
		fire_particles.emitting = true

func _on_spark_tick() -> void:
	if GameManager.fire_level > 0:
		fire_particles.emitting = true

# ═══════════════════════════════════════════════════════════
# RAIN
# ═══════════════════════════════════════════════════════════

func _on_rain_toggle() -> void:
	if randf() < 0.222:
		GameManager.raining = true
		rain_particles.emitting = true
	elif randf() < 0.333:
		GameManager.raining = false
		rain_particles.emitting = false

# ═══════════════════════════════════════════════════════════
# LOG SPAWNING
# ═══════════════════════════════════════════════════════════

func _on_log_spawn() -> void:
	var log_cap := 3 if GameManager.upgrade_log_cap else 2
	var can_spawn: bool = GameManager.log_count < log_cap and GameManager.fire_level > 0 and not _any_log_grabbed()
	if not can_spawn:
		if can_spawn == false and GameManager.fire_level > 0:
			GameManager.pity += 1
		return

	# Normal log roll
	var normal_roll := randf() < 0.2164 and can_spawn
	var normal_pity := GameManager.pity >= 8 and randf() < 0.6125 and can_spawn
	if normal_roll or normal_pity:
		GameManager.pity = 0
		_spawn_log(false)
		return

	# Big log roll
	var big_roll := randf() < 0.19875 and randf() < 0.0056 and can_spawn
	var big_pity := GameManager.pity >= 10 and randf() < 0.8575 and can_spawn
	if big_roll or big_pity:
		GameManager.pity = 0
		_spawn_log(true)
		_show_achievement("BIGLOG", "FIRE BIT")
		if GameManager.score < 500:
			GameManager.change_score(485)
		else:
			GameManager.change_score(120)
		return

	# Build pity
	GameManager.pity += 1

# ═══════════════════════════════════════════════════════════
# SHOP
# ═══════════════════════════════════════════════════════════

func _open_shop() -> void:
	_shop_open = true
	_shop_expecting_input = true
	shop_panel.visible = true
	shop_label.text = "SHOP [score:%d]\n1 Firebrick  200\n2 Bellows    350\n3 Roofing    500\n4 Phoenix    800\n5 Sacrifice 1200\n6 Log Cap    650\n7 Buy Log    115\n0 Exit" % GameManager.score

func _handle_shop_input(event: InputEvent) -> void:
	if not _shop_expecting_input:
		return
	if not (event is InputEventKey and event.pressed):
		return

	var choice := -1
	match event.keycode:
		KEY_0, KEY_KP_0: choice = 0
		KEY_1, KEY_KP_1: choice = 1
		KEY_2, KEY_KP_2: choice = 2
		KEY_3, KEY_KP_3: choice = 3
		KEY_4, KEY_KP_4: choice = 4
		KEY_5, KEY_KP_5: choice = 5
		KEY_6, KEY_KP_6: choice = 6
		KEY_7, KEY_KP_7: choice = 7
		KEY_ESCAPE: choice = 0
		_: return

	_shop_expecting_input = false
	_process_shop_choice(choice)
	shop_panel.visible = false
	_shop_open = false

func _process_shop_choice(choice: int) -> void:
	match choice:
		0:
			pass  # exit
		1:  # Firebrick 200
			if GameManager.upgrade_firebrick:
				_show_splash("Already owned: Firebrick")
			elif GameManager.score < 200:
				_show_splash("Need 200 (have %d)" % GameManager.score)
			else:
				GameManager.change_score(-200)
				GameManager.upgrade_firebrick = true
				_show_splash("Firebrick! Fire decays slower")
		2:  # Bellows 350
			if GameManager.upgrade_bellows:
				_show_splash("Already owned: Bellows")
			elif GameManager.score < 350:
				_show_splash("Need 350 (have %d)" % GameManager.score)
			else:
				GameManager.change_score(-350)
				GameManager.upgrade_bellows = true
				_show_splash("Bellows! Logs burn hotter")
		3:  # Roofing 500
			if GameManager.upgrade_roofing:
				_show_splash("Already owned: Roofing")
			elif GameManager.score < 500:
				_show_splash("Need 500 (have %d)" % GameManager.score)
			else:
				GameManager.change_score(-500)
				GameManager.upgrade_roofing = true
				_show_splash("Roofing! Rain can't hurt you")
		4:  # Phoenix 800
			if GameManager.upgrade_phoenix:
				_show_splash("Already owned: Phoenix")
			elif GameManager.score < 800:
				_show_splash("Need 800 (have %d)" % GameManager.score)
			else:
				GameManager.change_score(-800)
				GameManager.upgrade_phoenix = true
				_show_splash("Phoenix! A new ending awaits")
		5:  # Sacrifice 1200
			if GameManager.upgrade_sacrifice:
				_show_splash("Already owned: Sacrifice")
			elif GameManager.score < 1200:
				_show_splash("Need 1200 (have %d)" % GameManager.score)
			else:
				GameManager.change_score(-1200)
				GameManager.upgrade_sacrifice = true
				_show_splash("Sacrifice! Feed the demon")
		6:  # Log Cap 650
			if GameManager.upgrade_log_cap:
				_show_splash("Already owned: Log Cap")
			elif GameManager.score < 650:
				_show_splash("Need 650 (have %d)" % GameManager.score)
			else:
				GameManager.change_score(-650)
				GameManager.upgrade_log_cap = true
				_show_splash("Log Cap! Hold 3 logs at once")
		7:  # Buy Log 115
			if GameManager.score < 115:
				_show_splash("Need 115 (have %d)" % GameManager.score)
			else:
				var log_cap := 3 if GameManager.upgrade_log_cap else 2
				if GameManager.log_count >= log_cap:
					_show_splash("Log cap full! No room for more")
				else:
					GameManager.change_score(-115)
					_spawn_log(false)

# ═══════════════════════════════════════════════════════════
# ENDINGS
# ═══════════════════════════════════════════════════════════

func _press_end_button() -> void:
	end_button.texture = preload("res://assets/sprites/bigButtonPress1.png")
	await get_tree().create_timer(0.1).timeout
	_spawn_fire_burst(Vector2(78, 56) * SF)
	_trigger_ending()

func _trigger_ending() -> void:
	var s := GameManager.score

	# Demon ending
	if GameManager.secret_demon:
		for i in range(6):
			_spawn_explosion(Vector2(randi_range(40, 600), randi_range(40, 440)))
		await get_tree().create_timer(2.0).timeout
		_game_over(false)
		return

	# Sacrifice ending
	if GameManager.upgrade_sacrifice and GameManager.fire_level >= 4:
		_spawn_explosion(Vector2(320, 240))
		await get_tree().create_timer(2.0).timeout
		_game_over(true)
		return

	# Phoenix ending
	if GameManager.upgrade_phoenix and s >= 2500:
		for i in range(4):
			_spawn_explosion(Vector2(randi_range(160, 480), randi_range(120, 360)))
		await get_tree().create_timer(2.0).timeout
		_game_over(true)
		return

	# Standard score-based
	if s >= 3000:
		_spawn_explosion(Vector2(320, 240))
	elif s >= 1500:
		_spawn_explosion(Vector2(320, 240))

	await get_tree().create_timer(2.0).timeout
	_game_over(s >= 500)

func _game_over(won: bool) -> void:
	# Show game over screen
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(SCREEN_W, SCREEN_H)
	overlay.z_index = 100
	add_child(overlay)

	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 1.5)
	await tween.finished

	var result_label := Label.new()
	result_label.text = "YOU WIN!\nScore: %d" % GameManager.score if won else "GAME OVER\nScore: %d" % GameManager.score
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.size = Vector2(SCREEN_W, SCREEN_H)
	result_label.add_theme_font_size_override("font_size", 32)
	result_label.add_theme_color_override("font_color", Color.WHITE)
	result_label.z_index = 101
	add_child(result_label)

	var restart_label := Label.new()
	restart_label.text = "Click or press any key to restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.position = Vector2(0, 340)
	restart_label.size = Vector2(SCREEN_W, 40)
	restart_label.add_theme_font_size_override("font_size", 18)
	restart_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	restart_label.z_index = 101
	add_child(restart_label)

	await get_tree().create_timer(1.0).timeout
	# Wait for input then restart
	set_process_input(false)
	await _wait_for_any_input()
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _wait_for_any_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_anything_pressed() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return

# ═══════════════════════════════════════════════════════════
# TUTORIAL
# ═══════════════════════════════════════════════════════════

func _start_tutorial() -> void:
	_tutorial_running = true
	_say("HI, and welcome to my game!", 2.755)
	await get_tree().create_timer(3.0).timeout
	_say("To play, use your mouse to click and drag the logs", 2.7)
	await get_tree().create_timer(3.0).timeout
	_say("Or press T to toggle D-Pad mode", 3.0)
	await get_tree().create_timer(3.0).timeout
	_say("When no logs are on screen, left click bottom-right for shop", 4.8)
	await get_tree().create_timer(5.0).timeout
	_say("That's it, enjoy!", 3.0)
	await get_tree().create_timer(3.5).timeout
	speech_label.visible = false
	GameManager.tutorial_done = true
	_tutorial_running = false

func _web_clicked_has_money() -> void:
	_tutorial_running = true
	_say("YOU DON'T NEED ME ANYMORE!", 2.0)
	await get_tree().create_timer(2.5).timeout
	_say("Unless you need more help?", 2.0)
	await get_tree().create_timer(2.5).timeout
	_say("I bet you do", 1.0)
	await get_tree().create_timer(1.5).timeout
	_say("Fine, I give you some money, only this one time", 5.0)
	GameManager.change_score(415)
	await get_tree().create_timer(5.5).timeout
	speech_label.visible = false
	_tutorial_running = false

# ═══════════════════════════════════════════════════════════
# MUSIC / PLAYLIST
# ═══════════════════════════════════════════════════════════

func _on_playlist_tick() -> void:
	GameManager.playlist_index += 1
	if GameManager.playlist_index > 5:
		GameManager.playlist_index = 1
	# Music is procedurally generated in original — we just cycle placeholder silence
	# since MakeCode songs can't be directly converted to audio files

# ═══════════════════════════════════════════════════════════
# EFFECTS
# ═══════════════════════════════════════════════════════════

func _spawn_fire_burst(pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 20
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, -50, 0)
	mat.color = Color(1.0, 0.5, 0.1, 1.0)
	burst.process_material = mat
	burst.z_index = 50
	add_child(burst)
	await get_tree().create_timer(1.0).timeout
	burst.queue_free()

func _spawn_explosion(pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 40
	burst.lifetime = 1.5
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 30.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 200.0
	mat.gravity = Vector3(0, 100, 0)
	mat.color = Color(1.0, 0.3, 0.0, 1.0)
	burst.process_material = mat
	burst.z_index = 50
	add_child(burst)
	await get_tree().create_timer(3.0).timeout
	burst.queue_free()

func _spawn_log_effect(pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 12
	burst.lifetime = 0.4
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 15.0
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3.ZERO
	mat.color = Color(1.0, 0.5, 0.1, 0.8)
	burst.process_material = mat
	add_child(burst)
	await get_tree().create_timer(0.8).timeout
	burst.queue_free()

# ═══════════════════════════════════════════════════════════
# UI HELPERS
# ═══════════════════════════════════════════════════════════

func _say(text: String, duration: float) -> void:
	speech_label.text = text
	speech_label.visible = true
	await get_tree().create_timer(duration).timeout
	if speech_label.text == text:
		speech_label.visible = false

func _show_splash(text: String) -> void:
	achievement_label.text = text
	achievement_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if achievement_label.text == text:
		achievement_label.visible = false

func _show_achievement(title: String, desc: String) -> void:
	achievement_label.text = "%s\n%s" % [title, desc]
	achievement_label.visible = true
	await get_tree().create_timer(3.0).timeout
	achievement_label.visible = false

func _show_mode_label(text: String) -> void:
	mode_label.text = text
	mode_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if mode_label.text == text:
		mode_label.visible = false

func _sprites_overlap(a: Node2D, b: Node2D) -> bool:
	return a.position.distance_to(b.position) < 30.0 * SF
