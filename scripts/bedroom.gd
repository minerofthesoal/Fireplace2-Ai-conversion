extends Node2D

## Fireplace 2 — Bedroom
## Sleep to restore fire + gain score. Buy tools on the computer.

@onready var sleep_btn: Button = $UI/Panel/VBox/SleepBtn
@onready var status_label: Label = $UI/Panel/VBox/StatusLabel
@onready var computer_btn: Button = $UI/Panel/VBox/ComputerBtn
@onready var nav_left: Button = $UI/NavLeft
@onready var nav_right: Button = $UI/NavRight
@onready var coin_label: Label = $UI/CoinLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var tool_shop_panel: PanelContainer = $UI/ToolShopPanel

var _shop_open: bool = false

func _ready() -> void:
	var ui_theme: Theme = ThemeBuilder.build()
	for child in $UI.get_children():
		if child is Control:
			child.theme = ui_theme

	SaveManager.enter_game()

	sleep_btn.pressed.connect(_on_sleep)
	computer_btn.pressed.connect(_on_computer)
	nav_left.pressed.connect(_on_nav_left)
	nav_right.pressed.connect(_on_nav_right)

	tool_shop_panel.visible = false
	_update_ui()

	# Story progression
	if GameManager.story_stage == 1:
		GameManager.advance_story()

	AudioManager.start_music()

func _process(delta: float) -> void:
	if GameManager.sleep_cooldown > 0.0:
		GameManager.sleep_cooldown -= delta
	_update_ui()

func _update_ui() -> void:
	coin_label.text = "Coins: %d" % GameManager.coins
	room_label.text = "Bedroom"

	if GameManager.can_sleep():
		sleep_btn.text = "Sleep (Restore Fire + 50 pts)"
		sleep_btn.disabled = false
	else:
		var remaining: int = int(GameManager.sleep_cooldown)
		sleep_btn.text = "Rest... (%ds)" % remaining
		sleep_btn.disabled = true

	status_label.text = "Score: %d | Fire: %.1f | Tool: %s" % [
		GameManager.score,
		GameManager.fire_level,
		GameManager.tool_names[GameManager.current_tool],
	]

func _on_sleep() -> void:
	if not GameManager.can_sleep():
		return
	GameManager.do_sleep()
	AudioManager.play_sfx("achievement")
	SaveManager.save_game()
	_update_ui()

func _on_computer() -> void:
	_shop_open = not _shop_open
	tool_shop_panel.visible = _shop_open
	if _shop_open:
		_build_tool_shop()
	AudioManager.play_sfx("button_click")

func _build_tool_shop() -> void:
	for child in tool_shop_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	tool_shop_panel.add_child(vbox)

	var title := Label.new()
	title.text = "~ TOOL SHOP ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var coins_lbl := Label.new()
	coins_lbl.text = "Coins: %d" % GameManager.coins
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(coins_lbl)

	vbox.add_child(HSeparator.new())

	for i in range(GameManager.tool_names.size()):
		var btn := Button.new()
		if i <= GameManager.current_tool:
			if i == GameManager.current_tool:
				btn.text = "%s  [EQUIPPED]" % GameManager.tool_names[i]
			else:
				btn.text = "%s  [OWNED]" % GameManager.tool_names[i]
			btn.disabled = true
		else:
			btn.text = "%s  -  %d coins" % [GameManager.tool_names[i], GameManager.tool_costs[i]]
			if GameManager.coins < GameManager.tool_costs[i]:
				btn.disabled = true
			btn.pressed.connect(_on_buy_tool.bind(i))
		btn.custom_minimum_size = Vector2(250, 32)
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.pressed.connect(func():
		_shop_open = false
		tool_shop_panel.visible = false
	)
	vbox.add_child(close_btn)

func _on_buy_tool(idx: int) -> void:
	if GameManager.buy_tool(idx):
		AudioManager.play_sfx("shop_buy")
		_build_tool_shop()
		SaveManager.save_game()
	else:
		AudioManager.play_sfx("shop_fail")

func _on_nav_left() -> void:
	SaveManager.save_game()
	GameManager.current_room = GameManager.Room.LIVING_ROOM
	AudioManager.play_sfx("button_click")
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_nav_right() -> void:
	SaveManager.save_game()
	GameManager.current_room = GameManager.Room.OUTSIDE
	AudioManager.play_sfx("button_click")
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/outside.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _shop_open:
			_shop_open = false
			tool_shop_panel.visible = false
		else:
			_on_nav_left()
