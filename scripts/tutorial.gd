extends Node2D

## Fireplace 2 — Tutorial (Spider character)
## Shows tutorial messages when cursor hovers over the spider.

signal tutorial_complete

@onready var spider_sprite: Sprite2D = $SpiderSprite
@onready var temp_icon: Sprite2D = $TempIcon

var _running := false
var _speech_label: Label  # assigned by parent

func set_speech_label(lbl: Label) -> void:
	_speech_label = lbl

func check_interaction(cursor_pos: Vector2) -> void:
	if _running or _speech_label == null:
		return
	if cursor_pos.distance_to(temp_icon.global_position) > 120:
		return
	if GameManager.score <= 155 and GameManager.score > 98:
		if not GameManager.tutorial_done:
			_run_tutorial()
		else:
			_run_money_gift()

func _run_tutorial() -> void:
	_running = true
	_say("HI, and welcome to my game!")
	await get_tree().create_timer(3.0).timeout
	_say("Use your mouse to click and drag logs to the fire!")
	await get_tree().create_timer(3.0).timeout
	_say("Press T to toggle D-Pad mode")
	await get_tree().create_timer(3.0).timeout
	_say("Click bottom-left (no logs on screen) or B for Shop")
	await get_tree().create_timer(5.0).timeout
	_say("That's it, enjoy!")
	await get_tree().create_timer(3.5).timeout
	_hide_speech()
	GameManager.tutorial_done = true
	_running = false
	tutorial_complete.emit()

func _run_money_gift() -> void:
	_running = true
	_say("YOU DON'T NEED ME ANYMORE!")
	await get_tree().create_timer(2.5).timeout
	_say("Unless you need more help?")
	await get_tree().create_timer(2.5).timeout
	_say("I bet you do")
	await get_tree().create_timer(1.5).timeout
	_say("Fine, here's some money. Only this one time!")
	GameManager.change_score(415)
	AudioManager.play_sfx("shop_buy")
	await get_tree().create_timer(5.5).timeout
	_hide_speech()
	_running = false

func _say(text: String) -> void:
	if _speech_label:
		_speech_label.text = text
		_speech_label.visible = true

func _hide_speech() -> void:
	if _speech_label:
		_speech_label.visible = false
