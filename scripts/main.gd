extends Node2D

## Fireplace 2 — Game Scene Controller
## Wires together all sub-systems.

const SCREEN_W := 640
const SCREEN_H := 480

@onready var fire_system: Node2D = $FireSystem
@onready var log_system: Node2D = $LogSystem
@onready var rain_system: Node2D = $RainSystem
@onready var input_mgr: Node2D = $InputManager
@onready var tutorial_node: Node2D = $Tutorial
@onready var shop_ui: PanelContainer = $UI/ShopUI
@onready var heat_bar: ProgressBar = $"UI/TopBar/HBox/HeatBar"
@onready var score_label: Label = $"UI/TopBar/HBox/ScoreLabel"
@onready var stats_label: Label = $"UI/TopBar/HBox/StatsLabel"
@onready var speech_bubble: PanelContainer = $"UI/SpeechBubble"
@onready var speech_label: Label = $"UI/SpeechBubble/SpeechLabel"
@onready var achievement_label: Label = $UI/AchievementLabel
@onready var mode_label: Label = $UI/ModeLabel
@onready var end_button: Sprite2D = $EndButton
@onready var combo_label: Label = $UI/ComboLabel
@onready var wind_label: Label = $UI/WindLabel
@onready var save_indicator: Label = $UI/SaveIndicator
@onready var shop_btn: Button = $"UI/BottomBar/ShopBtn"
@onready var pause_btn: Button = $"UI/BottomBar/PauseBtn"
@onready var menu_btn: Button = $"UI/BottomBar/MenuBtn"
@onready var spider_web: Node2D = $SpiderWeb
@onready var nav_left: Button = $"UI/NavLeft"
@onready var nav_right: Button = $"UI/NavRight"
@onready var room_label: Label = $"UI/RoomLabel"
@onready var coin_label: Label = $"UI/CoinLabel"
@onready var story_panel: PanelContainer = $"UI/StoryPanel"
@onready var story_label: Label = $"UI/StoryPanel/StoryLabel"

var _endings: Node
var _shop_open: bool = false
var _game_over_active: bool = false
var _achievement_tween: Tween
var _save_flash_tween: Tween

func _ready() -> void:
	# Apply theme to all UI Control children
	var ui_theme: Theme = ThemeBuilder.build()
	for child in $UI.get_children():
		if child is Control:
			child.theme = ui_theme

	# Try loading saved game
	if not SaveManager.load_game():
		GameManager.reset_game()
	SaveManager.enter_game()

	# Endings
	_endings = preload("res://scripts/endings.gd").new()
	_endings.setup(self)
	_endings.ending_complete.connect(_on_ending_complete)
	add_child(_endings)

	# Tutorial — spider follows web
	tutorial_node.set_speech_label(speech_label)
	tutorial_node.set_spider_web(spider_web)

	# Input signals
	input_mgr.grab_requested.connect(_on_grab)
	input_mgr.release_requested.connect(_on_release)
	input_mgr.shop_requested.connect(_on_shop_requested)

	# Shop signals
	shop_ui.shop_closed.connect(_on_shop_closed)
	shop_ui.item_purchased.connect(_on_item_purchased)

	# Fire events
	fire_system.fire_died.connect(_on_fire_died)

	# Rain/wind events
	rain_system.wind_started.connect(_on_wind_started)
	rain_system.wind_ended.connect(_on_wind_ended)

	# Achievement signal
	GameManager.achievement_earned.connect(_on_achievement_earned)
	GameManager.combo_changed.connect(_on_combo_changed)

	# UI button signals — pause button must work while paused
	$"UI/BottomBar".process_mode = Node.PROCESS_MODE_ALWAYS
	shop_btn.pressed.connect(_on_shop_btn_pressed)
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	menu_btn.pressed.connect(_on_menu_btn_pressed)
	nav_left.pressed.connect(_on_nav_left)
	nav_right.pressed.connect(_on_nav_right)

	# Initialize UI
	end_button.visible = false
	achievement_label.visible = false
	mode_label.visible = false
	speech_bubble.visible = false
	combo_label.visible = false
	wind_label.visible = false
	save_indicator.visible = false
	story_panel.visible = false
	_update_room_label()
	_update_coin_label()

	# Show story intro on first play
	if GameManager.story_stage == 0:
		_show_story(GameManager.get_story_text())
		GameManager.advance_story()

	# Heat bar max
	heat_bar.max_value = GameManager.get_fire_max()

	# Start music
	AudioManager.start_music()

	# Wire fire zone after positions settle
	await get_tree().process_frame
	log_system.set_fire_zone(fire_system.get_fire_zone_rect())

	# Spawn first log if fresh game
	if GameManager.log_count == 0:
		log_system.spawn_log(false)

func _process(delta: float) -> void:
	if _game_over_active:
		return

	GameManager.game_time += delta

	# Marathon achievement
	if GameManager.game_time >= 600.0:
		GameManager.try_achievement("marathon")

	# Cursor to log system and spider web
	var cursor_pos: Vector2 = input_mgr.get_cursor_pos()
	log_system.drag_to(cursor_pos)
	spider_web.apply_cursor_force(cursor_pos)

	# Update UI
	heat_bar.max_value = GameManager.get_fire_max()
	heat_bar.value = GameManager.fire_level
	score_label.text = "Score: %d" % GameManager.score
	stats_label.text = "Logs: %d | %s | Best: %dx" % [
		GameManager.total_logs_burned,
		_format_time(GameManager.game_time),
		GameManager.combo_best,
	]

	# Sleep cooldown
	if GameManager.sleep_cooldown > 0.0:
		GameManager.sleep_cooldown -= delta
	if GameManager.sleep_bonus_active and GameManager.sleep_cooldown <= 0.0:
		GameManager.sleep_bonus_active = false

	_update_coin_label()

	# Tutorial
	tutorial_node.check_interaction(cursor_pos)

	# End button at 1325
	if GameManager.score >= 1325 and not GameManager.end_button_visible:
		GameManager.end_button_visible = true
		end_button.visible = true
		AudioManager.play_sfx("achievement")
		_show_achievement("END AVAILABLE", "Click the button to finish")

# ═══════════════════════════════════════════════════════════
# UI BUTTONS
# ═══════════════════════════════════════════════════════════

func _on_shop_btn_pressed() -> void:
	if not _shop_open and not _game_over_active:
		_open_shop()

func _on_pause_btn_pressed() -> void:
	if _game_over_active:
		return
	get_tree().paused = not get_tree().paused
	pause_btn.text = "Resume" if get_tree().paused else "Pause"

# ═══════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════

func _on_grab(cursor_pos: Vector2) -> void:
	if _shop_open or _game_over_active:
		return
	log_system.try_grab(cursor_pos)

func _on_release(cursor_pos: Vector2) -> void:
	if _shop_open or _game_over_active:
		return
	log_system.release_all()

	# End button
	if GameManager.end_button_visible and end_button.visible:
		if cursor_pos.distance_to(end_button.position) < 50:
			_press_end_button()

func _on_shop_requested() -> void:
	if not _shop_open and not _game_over_active:
		_open_shop()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_input_mode"):
		_show_mode("D-Pad mode ON" if GameManager.use_dpad else "Mouse mode ON")
	if event.is_action_pressed("ui_cancel") and not _shop_open and not _game_over_active:
		_open_shop()

# ═══════════════════════════════════════════════════════════
# SHOP
# ═══════════════════════════════════════════════════════════

func _open_shop() -> void:
	_shop_open = true
	shop_ui.open()
	AudioManager.play_sfx("button_click")

func _on_shop_closed() -> void:
	_shop_open = false
	SaveManager.save_game()
	_flash_save()

func _on_item_purchased(item_name: String) -> void:
	_show_achievement(item_name, "Purchased!")
	if item_name == "Buy Log":
		log_system.spawn_log(false)

# ═══════════════════════════════════════════════════════════
# ENDINGS
# ═══════════════════════════════════════════════════════════

func _press_end_button() -> void:
	if _game_over_active:
		return
	_game_over_active = true
	SaveManager.leave_game()
	AudioManager.play_sfx("button_click")
	await get_tree().create_timer(0.15).timeout
	Effects.fire_burst(self, end_button.position)
	_endings.trigger()

func _on_ending_complete(won: bool, ending_name: String, final_score: int) -> void:
	AudioManager.stop_music()
	SaveManager.delete_save()
	_show_game_over(won, ending_name, final_score)

func _show_game_over(won: bool, ending_name: String, final_score: int) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(SCREEN_W, SCREEN_H)
	overlay.z_index = 100
	$UI.add_child(overlay)

	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.92), 1.5)
	await tween.finished

	var result_vbox := VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_vbox.size = Vector2(SCREEN_W, SCREEN_H)
	result_vbox.z_index = 101
	$UI.add_child(result_vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	result_vbox.add_child(spacer)

	var title := Label.new()
	title.text = "YOU WIN!" if won else "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.GOLD if won else Color.INDIAN_RED)
	result_vbox.add_child(title)

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

	var stats := Label.new()
	stats.text = "Logs burned: %d  |  Time: %s  |  Peak fire: %.1f\nBest combo: %dx  |  Wind survived: %d  |  Prestige: x%d" % [
		GameManager.total_logs_burned,
		_format_time(GameManager.game_time),
		GameManager.highest_fire_level,
		GameManager.combo_best,
		GameManager.wind_events_survived,
		GameManager.prestige_count,
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	result_vbox.add_child(stats)

	if GameManager.achievements_unlocked.size() > 0:
		var ach_lbl := Label.new()
		ach_lbl.text = "Achievements: %d / %d" % [
			GameManager.achievements_unlocked.size(),
			GameManager.ACHIEVEMENTS.size()
		]
		ach_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ach_lbl.add_theme_font_size_override("font_size", 14)
		ach_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		result_vbox.add_child(ach_lbl)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
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
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	)
	btn_row.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(160, 44)
	menu_btn.pressed.connect(func():
		GameManager.reset_game()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	btn_row.add_child(menu_btn)

	retry_btn.grab_focus()

# ═══════════════════════════════════════════════════════════
# WEATHER EVENTS
# ═══════════════════════════════════════════════════════════

func _on_fire_died() -> void:
	Effects.smoke_puff(self, Vector2(320, 300))

func _on_wind_started() -> void:
	wind_label.text = "WIND GUST!"
	wind_label.visible = true
	wind_label.modulate = Color(1, 1, 1, 1)
	wind_label.add_theme_font_size_override("font_size", 22)
	wind_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))

func _on_wind_ended() -> void:
	var tw := create_tween()
	tw.tween_property(wind_label, "modulate", Color(1, 1, 1, 0), 1.0)
	tw.tween_callback(func(): wind_label.visible = false)

# ═══════════════════════════════════════════════════════════
# COMBO / ACHIEVEMENTS
# ═══════════════════════════════════════════════════════════

func _on_combo_changed(new_combo: int) -> void:
	if new_combo >= 2:
		combo_label.text = "COMBO x%d!" % new_combo
		combo_label.add_theme_font_size_override("font_size", 20)
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		combo_label.visible = true
		combo_label.modulate = Color(1, 1, 1, 1)
		var tw := create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(combo_label, "modulate", Color(1, 1, 1, 0), 0.5)
	else:
		combo_label.visible = false

func _on_achievement_earned(id: String) -> void:
	var ach_name: String = GameManager.get_achievement_name(id)
	var ach_desc: String = GameManager.get_achievement_desc(id)
	_show_achievement(ach_name, ach_desc)
	AudioManager.play_sfx("achievement")

# ═══════════════════════════════════════════════════════════
# UI HELPERS
# ═══════════════════════════════════════════════════════════

func _show_achievement(title_text: String, desc: String) -> void:
	achievement_label.text = "%s\n%s" % [title_text, desc]
	achievement_label.add_theme_font_size_override("font_size", 18)
	achievement_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
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

func _flash_save() -> void:
	save_indicator.text = "Saved"
	save_indicator.visible = true
	save_indicator.modulate = Color.WHITE
	if _save_flash_tween:
		_save_flash_tween.kill()
	_save_flash_tween = create_tween()
	_save_flash_tween.tween_interval(1.0)
	_save_flash_tween.tween_property(save_indicator, "modulate", Color(1, 1, 1, 0), 0.5)
	_save_flash_tween.tween_callback(func(): save_indicator.visible = false)

func _on_menu_btn_pressed() -> void:
	if _game_over_active:
		return
	SaveManager.save_game()
	SaveManager.leave_game()
	AudioManager.stop_music()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ═══════════════════════════════════════════════════════════
# ROOM NAVIGATION
# ═══════════════════════════════════════════════════════════

const ROOM_NAMES: Array[String] = ["Living Room", "Bedroom", "Outside"]

func _on_nav_left() -> void:
	if _shop_open or _game_over_active:
		return
	_navigate_room(-1)

func _on_nav_right() -> void:
	if _shop_open or _game_over_active:
		return
	_navigate_room(1)

func _navigate_room(direction: int) -> void:
	var new_room: int = GameManager.current_room + direction
	if new_room < 0 or new_room > 2:
		return
	SaveManager.save_game()
	GameManager.current_room = new_room
	AudioManager.play_sfx("button_click")
	match new_room:
		GameManager.Room.LIVING_ROOM:
			get_tree().change_scene_to_file("res://scenes/game.tscn")
		GameManager.Room.BEDROOM:
			get_tree().change_scene_to_file("res://scenes/bedroom.tscn")
		GameManager.Room.OUTSIDE:
			get_tree().change_scene_to_file("res://scenes/outside.tscn")

func _update_room_label() -> void:
	if room_label:
		room_label.text = ROOM_NAMES[GameManager.current_room]

func _update_coin_label() -> void:
	if coin_label:
		coin_label.text = "Coins: %d" % GameManager.coins

func _show_story(text: String) -> void:
	story_label.text = text
	story_panel.visible = true
	story_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(story_panel, "modulate", Color.WHITE, 0.5)
	tw.tween_interval(4.0)
	tw.tween_property(story_panel, "modulate", Color(1, 1, 1, 0), 1.0)
	tw.tween_callback(func(): story_panel.visible = false)

func _format_time(t: float) -> String:
	var m: int = int(t) / 60
	var s: int = int(t) % 60
	return "%d:%02d" % [m, s]
