extends Node2D

## Fireplace 2 — Game Scene Controller
## Wires together all sub-systems: fire, logs, rain, shop, endings, input, tutorial.

const SF := 4.0
const SCREEN_W := 640
const SCREEN_H := 480

@onready var fire_system: Node2D = $FireSystem
@onready var log_system: Node2D = $LogSystem
@onready var rain_system: Node2D = $RainSystem
@onready var input_mgr: Node2D = $InputManager
@onready var tutorial_node: Node2D = $Tutorial
@onready var shop_ui: PanelContainer = $UI/ShopUI
@onready var heat_bar: ProgressBar = $UI/HeatBar
@onready var score_label: Label = $UI/ScoreLabel
@onready var speech_label: Label = $UI/SpeechBubble
@onready var achievement_label: Label = $UI/AchievementLabel
@onready var mode_label: Label = $UI/ModeLabel
@onready var end_button: Sprite2D = $EndButton
@onready var stats_label: Label = $UI/StatsLabel

var _endings: Node
var _shop_open := false
var _game_over_active := false
var _achievement_tween: Tween

func _ready() -> void:
	theme = ThemeBuilder.build()
	GameManager.reset_game()

	# Endings system
	_endings = preload("res://scripts/endings.gd").new()
	_endings.setup(self)
	_endings.ending_complete.connect(_on_ending_complete)
	add_child(_endings)

	# Tutorial
	tutorial_node.set_speech_label(speech_label)

	# Connect input signals
	input_mgr.grab_requested.connect(_on_grab)
	input_mgr.release_requested.connect(_on_release)
	input_mgr.shop_requested.connect(_on_shop_requested)

	# Connect shop signals
	shop_ui.shop_closed.connect(_on_shop_closed)
	shop_ui.item_purchased.connect(_on_item_purchased)

	# Connect fire system
	fire_system.fire_died.connect(_on_fire_died)

	# Initialize
	end_button.visible = false
	achievement_label.visible = false
	mode_label.visible = false
	speech_label.visible = false

	# Start music
	AudioManager.start_music()

	# Give fire_zone to log_system after 1 frame (positions settle)
	await get_tree().process_frame
	log_system.set_fire_zone(fire_system.get_fire_zone_rect())

	# Spawn first log
	log_system.spawn_log(false)

func _process(delta: float) -> void:
	if _game_over_active:
		return

	GameManager.game_time += delta

	# Pass cursor pos to log system for dragging
	log_system.drag_to(input_mgr.get_cursor_pos())

	# Update UI
	heat_bar.value = GameManager.fire_level
	score_label.text = "Score: %d" % GameManager.score
	stats_label.text = "Logs burned: %d  |  Time: %s" % [
		GameManager.total_logs_burned,
		_format_time(GameManager.game_time)
	]

	# Tutorial check
	tutorial_node.check_interaction(input_mgr.get_cursor_pos())

	# End button at 1325 score
	if GameManager.score >= 1325 and not GameManager.end_button_visible:
		GameManager.end_button_visible = true
		end_button.visible = true
		end_button.texture = preload("res://assets/sprites/bigButtonPress0.png")
		AudioManager.play_sfx("achievement")
		_show_achievement("END AVAILABLE", "Click the button to finish")

# ═══════════════════════════════════════════════════════════
# INPUT HANDLING
# ═══════════════════════════════════════════════════════════

func _on_grab(cursor_pos: Vector2) -> void:
	if _shop_open or _game_over_active:
		return
	log_system.try_grab(cursor_pos)

func _on_release(cursor_pos: Vector2) -> void:
	if _shop_open or _game_over_active:
		return
	log_system.release_all()

	# Shop click (bottom-left, no logs)
	if log_system.all_null() and cursor_pos.x < 40 * SF and cursor_pos.y > 100 * SF:
		_open_shop()
		return

	# End button click
	if GameManager.end_button_visible and end_button.visible:
		if cursor_pos.distance_to(end_button.position) < 30 * SF:
			_press_end_button()

func _on_shop_requested() -> void:
	if not _shop_open and not _game_over_active:
		_open_shop()

func _input(event: InputEvent) -> void:
	# Toggle mode notification
	if event.is_action_pressed("toggle_input_mode"):
		_show_mode("D-Pad mode ON" if GameManager.use_dpad else "Mouse mode ON")

# ═══════════════════════════════════════════════════════════
# SHOP
# ═══════════════════════════════════════════════════════════

func _open_shop() -> void:
	_shop_open = true
	shop_ui.open()
	AudioManager.play_sfx("button_click")

func _on_shop_closed() -> void:
	_shop_open = false

func _on_item_purchased(item_name: String) -> void:
	_show_achievement(item_name, "Purchased!")
	# If Buy Log was purchased, spawn it
	if item_name == "Buy Log":
		log_system.spawn_log(false)

# ═══════════════════════════════════════════════════════════
# ENDINGS
# ═══════════════════════════════════════════════════════════

func _press_end_button() -> void:
	if _game_over_active:
		return
	_game_over_active = true
	end_button.texture = preload("res://assets/sprites/bigButtonPress1.png")
	AudioManager.play_sfx("button_click")
	await get_tree().create_timer(0.15).timeout
	Effects.fire_burst(self, Vector2(78, 56) * SF)
	_endings.trigger()

func _on_ending_complete(won: bool, ending_name: String, final_score: int) -> void:
	AudioManager.stop_music()
	_show_game_over(won, ending_name, final_score)

func _show_game_over(won: bool, ending_name: String, final_score: int) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(SCREEN_W, SCREEN_H)
	overlay.z_index = 100
	$UI.add_child(overlay)

	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.9), 1.5)
	await tween.finished

	var result_vbox := VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_vbox.size = Vector2(SCREEN_W, SCREEN_H)
	result_vbox.z_index = 101
	$UI.add_child(result_vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	result_vbox.add_child(spacer)

	var result_title := Label.new()
	result_title.text = "YOU WIN!" if won else "GAME OVER"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 40)
	result_title.add_theme_color_override("font_color", Color.GOLD if won else Color.INDIAN_RED)
	result_vbox.add_child(result_title)

	var ending_lbl := Label.new()
	ending_lbl.text = "Ending: %s" % ending_name
	ending_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_lbl.add_theme_font_size_override("font_size", 22)
	result_vbox.add_child(ending_lbl)

	var score_lbl := Label.new()
	score_lbl.text = "Final Score: %d" % final_score
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 20)
	result_vbox.add_child(score_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "Logs burned: %d  |  Time: %s  |  Peak fire: %.1f" % [
		GameManager.total_logs_burned,
		_format_time(GameManager.game_time),
		GameManager.highest_fire_level
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 14)
	result_vbox.add_child(stats_lbl)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	result_vbox.add_child(spacer2)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	result_vbox.add_child(btn_row)

	var retry_btn := Button.new()
	retry_btn.text = "Play Again"
	retry_btn.custom_minimum_size = Vector2(160, 44)
	retry_btn.pressed.connect(func():
		GameManager.reset_game()
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	)
	btn_row.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(160, 44)
	menu_btn.pressed.connect(func():
		GameManager.reset_game()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	btn_row.add_child(menu_btn)

	retry_btn.grab_focus()

# ═══════════════════════════════════════════════════════════
# FIRE EVENTS
# ═══════════════════════════════════════════════════════════

func _on_fire_died() -> void:
	Effects.smoke_puff(self, Vector2(320, 320))

# ═══════════════════════════════════════════════════════════
# UI HELPERS
# ═══════════════════════════════════════════════════════════

func _show_achievement(title: String, desc: String) -> void:
	achievement_label.text = "%s\n%s" % [title, desc]
	achievement_label.visible = true
	achievement_label.modulate = Color(1, 1, 1, 0)
	if _achievement_tween:
		_achievement_tween.kill()
	_achievement_tween = create_tween()
	_achievement_tween.tween_property(achievement_label, "modulate", Color.WHITE, 0.3)
	_achievement_tween.tween_interval(2.5)
	_achievement_tween.tween_property(achievement_label, "modulate", Color(1, 1, 1, 0), 0.5)
	_achievement_tween.tween_callback(func(): achievement_label.visible = false)

func _show_mode(text: String) -> void:
	mode_label.text = text
	mode_label.visible = true
	mode_label.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(mode_label, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_callback(func(): mode_label.visible = false)

func _format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%d:%02d" % [m, s]
