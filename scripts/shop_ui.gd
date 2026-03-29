extends PanelContainer

## Fireplace 2 — Shop UI
## Button-based shop with styled items. 15 upgrade items + buy log + prestige.

signal shop_closed
signal item_purchased(item_name: String)

var _vbox: VBoxContainer
var _title_label: Label
var _status_label: Label

# Item definitions: [name, cost, description, upgrade_key]
const ITEMS: Array[Array] = [
	["Kindling",      150,  "Fire starts easier (+1 on first log)", "upgrade_kindling"],
	["Firebrick",     200,  "Fire decays slower",                   "upgrade_firebrick"],
	["Bellows",       350,  "Logs burn hotter (+1 fire)",            "upgrade_bellows"],
	["Ember Glow",    400,  "Fire never fully dies (min 0.5)",       "upgrade_ember_glow"],
	["Log Magnet",    450,  "Logs auto-snap when near fire",         "upgrade_log_magnet"],
	["Roofing",       500,  "Rain can't hurt your fire",             "upgrade_roofing"],
	["Wind Guard",    600,  "50% rain resistance",                   "upgrade_wind_guard"],
	["Log Cap",       650,  "Hold 3 logs at once",                   "upgrade_log_cap"],
	["Lucky Logs",    750,  "Double big log chance",                 "upgrade_lucky_logs"],
	["Phoenix",       800,  "Unlocks Phoenix ending",                "upgrade_phoenix"],
	["Combo Master",  850,  "Combo window lasts longer",             "upgrade_combo_master"],
	["Auto Log",      900,  "Auto-feeds logs every 8 seconds",       "upgrade_auto_log"],
	["Heat Shield",   1000, "Fire max raised to 7",                  "upgrade_heat_shield"],
	["Sacrifice",     1200, "Unlocks Sacrifice ending",              "upgrade_sacrifice"],
	["Gold Fire",     1500, "Score ticks give +2",                   "upgrade_gold_fire"],
]

func _ready() -> void:
	visible = false

func open() -> void:
	_build_ui()
	visible = true

func close() -> void:
	visible = false
	shop_closed.emit()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 370)
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "~ SHOP ~    Score: %d" % GameManager.score
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_vbox.add_child(_title_label)

	# Combo display
	if GameManager.combo_count > 1:
		var combo_lbl := Label.new()
		combo_lbl.text = "Combo: x%d (%.1fx score)" % [GameManager.combo_count, GameManager.get_combo_multiplier()]
		combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combo_lbl.add_theme_font_size_override("font_size", 14)
		combo_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_vbox.add_child(combo_lbl)

	# Prestige info
	if GameManager.prestige_count > 0:
		var prest_lbl := Label.new()
		prest_lbl.text = "Prestige: x%d (+%d%% score)" % [GameManager.prestige_count, int(GameManager.prestige_bonus * 100)]
		prest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prest_lbl.add_theme_font_size_override("font_size", 14)
		prest_lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0))
		_vbox.add_child(prest_lbl)

	_vbox.add_child(HSeparator.new())

	# Upgrade items
	for item_def in ITEMS:
		var item_name: String = str(item_def[0])
		var cost: int = int(item_def[1])
		var desc: String = str(item_def[2])
		var key: String = str(item_def[3])
		var owned: bool = GameManager.get(key) as bool
		var can_afford: bool = GameManager.score >= cost

		var btn := Button.new()
		if owned:
			btn.text = "%s  [OWNED]" % item_name
			btn.disabled = true
		else:
			btn.text = "%s  -  %d pts" % [item_name, cost]
			if not can_afford:
				btn.disabled = true
		btn.tooltip_text = desc
		btn.custom_minimum_size = Vector2(340, 30)
		btn.pressed.connect(_on_item_pressed.bind(item_name, cost, key))
		_vbox.add_child(btn)

	_vbox.add_child(HSeparator.new())

	# Buy Log (repeatable)
	var buy_log_btn := Button.new()
	buy_log_btn.text = "Buy Log  -  115 pts"
	buy_log_btn.custom_minimum_size = Vector2(340, 30)
	if GameManager.score < 115:
		buy_log_btn.disabled = true
	elif GameManager.log_count >= GameManager.get_log_cap():
		buy_log_btn.text = "Buy Log  -  FULL"
		buy_log_btn.disabled = true
	buy_log_btn.pressed.connect(_on_buy_log)
	_vbox.add_child(buy_log_btn)

	# Prestige button
	if GameManager.can_prestige():
		_vbox.add_child(HSeparator.new())
		var prestige_btn := Button.new()
		prestige_btn.text = "PRESTIGE  -  Reset for +10%% score"
		prestige_btn.custom_minimum_size = Vector2(340, 36)
		prestige_btn.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
		prestige_btn.pressed.connect(_on_prestige)
		_vbox.add_child(prestige_btn)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_vbox.add_child(_status_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close Shop (Esc)"
	close_btn.custom_minimum_size = Vector2(200, 34)
	close_btn.pressed.connect(close)
	_vbox.add_child(close_btn)

func _on_item_pressed(item_name: String, cost: int, key: String) -> void:
	if GameManager.get(key):
		_show_status("Already owned!")
		AudioManager.play_sfx("shop_fail")
		return
	if GameManager.score < cost:
		_show_status("Need %d (have %d)" % [cost, GameManager.score])
		AudioManager.play_sfx("shop_fail")
		return
	GameManager.change_score(-cost)
	GameManager.set(key, true)
	AudioManager.play_sfx("shop_buy")
	GameManager.upgrade_purchased.emit(item_name)
	item_purchased.emit(item_name)
	_build_ui()

func _on_buy_log() -> void:
	if GameManager.score < 115:
		_show_status("Need 115 (have %d)" % GameManager.score)
		AudioManager.play_sfx("shop_fail")
		return
	if GameManager.log_count >= GameManager.get_log_cap():
		_show_status("Log cap full!")
		AudioManager.play_sfx("shop_fail")
		return
	GameManager.change_score(-115)
	AudioManager.play_sfx("shop_buy")
	item_purchased.emit("Buy Log")
	_build_ui()

func _on_prestige() -> void:
	AudioManager.play_sfx("achievement")
	GameManager.do_prestige()
	SaveManager.save_game()
	close()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _show_status(text: String) -> void:
	if _status_label:
		_status_label.text = text

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
