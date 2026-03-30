extends Node2D

## Fireplace 2 — Outside
## Chop logs in a 2.5D minigame, sell them for coins.

@onready var chop_btn: Button = $UI/Panel/VBox/ChopBtn
@onready var sell_btn: Button = $UI/Panel/VBox/SellBtn
@onready var status_label: Label = $UI/Panel/VBox/StatusLabel
@onready var nav_left: Button = $UI/NavLeft
@onready var nav_right: Button = $UI/NavRight
@onready var coin_label: Label = $UI/CoinLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var chop_area: Node2D = $ChopArea
@onready var log_sprite: Sprite2D = $ChopArea/LogSprite
@onready var axe_sprite: Sprite2D = $ChopArea/AxeSprite
@onready var hp_bar: ProgressBar = $UI/Panel/VBox/LogHP

var _log_hp: float = 5.0
var _log_hp_max: float = 5.0
var _chopping: bool = false
var _chop_anim_time: float = 0.0

func _ready() -> void:
	var ui_theme: Theme = ThemeBuilder.build()
	for child in $UI.get_children():
		if child is Control:
			child.theme = ui_theme

	SaveManager.enter_game()

	chop_btn.pressed.connect(_on_chop)
	sell_btn.pressed.connect(_on_sell)
	nav_left.pressed.connect(_on_nav_left)
	nav_right.pressed.connect(_on_nav_right)

	_reset_log()
	_update_ui()

	# Story progression
	if GameManager.story_stage <= 2:
		GameManager.story_stage = 2
		GameManager.advance_story()

	AudioManager.start_music()

func _process(delta: float) -> void:
	# Axe swing animation
	if _chopping:
		_chop_anim_time += delta * 12.0
		axe_sprite.rotation_degrees = -45.0 + sin(_chop_anim_time * PI) * 60.0
		if _chop_anim_time >= 1.0:
			_chopping = false
			axe_sprite.rotation_degrees = -45.0
			_chop_anim_time = 0.0

	# Sleep cooldown
	if GameManager.sleep_cooldown > 0.0:
		GameManager.sleep_cooldown -= delta

	_update_ui()

func _reset_log() -> void:
	_log_hp_max = 5.0 + GameManager.chopped_logs * 0.5  # Logs get tougher
	if _log_hp_max > 20.0:
		_log_hp_max = 20.0
	_log_hp = _log_hp_max
	if log_sprite:
		log_sprite.modulate = Color.WHITE

func _on_chop() -> void:
	if _chopping:
		return
	_chopping = true
	_chop_anim_time = 0.0

	_log_hp -= GameManager.chop_power
	AudioManager.play_sfx("burn")

	# Visual feedback — log gets redder as it takes damage
	var ratio: float = _log_hp / _log_hp_max
	log_sprite.modulate = Color(1.0, ratio, ratio)

	if _log_hp <= 0.0:
		# Log chopped!
		GameManager.chopped_logs += 1
		AudioManager.play_sfx("achievement")
		Effects.log_spawn_puff(chop_area, log_sprite.position)
		_reset_log()
		SaveManager.save_game()

func _on_sell() -> void:
	if GameManager.chopped_logs <= 0:
		AudioManager.play_sfx("shop_fail")
		return
	var earned: int = GameManager.sell_chopped_logs(GameManager.chopped_logs)
	AudioManager.play_sfx("shop_buy")
	SaveManager.save_game()
	_update_ui()

func _update_ui() -> void:
	coin_label.text = "Coins: %d" % GameManager.coins
	room_label.text = "Outside"

	status_label.text = "Chopped Logs: %d | Tool: %s (%.0fx)" % [
		GameManager.chopped_logs,
		GameManager.tool_names[GameManager.current_tool],
		GameManager.chop_power,
	]

	if GameManager.chopped_logs > 0:
		sell_btn.text = "Sell %d Logs (%d coins)" % [
			GameManager.chopped_logs,
			GameManager.chopped_logs * GameManager.sell_price_per_log
		]
		sell_btn.disabled = false
	else:
		sell_btn.text = "Sell Logs (none)"
		sell_btn.disabled = true

	hp_bar.max_value = _log_hp_max
	hp_bar.value = _log_hp

func _on_nav_left() -> void:
	SaveManager.save_game()
	GameManager.current_room = GameManager.Room.LIVING_ROOM
	AudioManager.play_sfx("button_click")
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_nav_right() -> void:
	SaveManager.save_game()
	GameManager.current_room = GameManager.Room.BEDROOM
	AudioManager.play_sfx("button_click")
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/bedroom.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_nav_left()
	# Spacebar or A to chop
	if event.is_action_pressed("button_a") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_on_chop()
