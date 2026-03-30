extends Node2D

## Fireplace 2 — Tutorial (Spider character)
## The spider hangs on its web in the top-right corner.
## Cursor nearby triggers tutorial dialogue or money gift.

signal tutorial_complete

@onready var spider_sprite: Sprite2D = $SpiderSprite
@onready var temp_icon: Sprite2D = $TempIcon

var _running := false
var _speech_label: Label
var _spider_bob_time: float = 0.0
var _spider_base_pos: Vector2

func _ready() -> void:
	_spider_base_pos = spider_sprite.position
	temp_icon.visible = false

func set_speech_label(lbl: Label) -> void:
	_speech_label = lbl

func _process(delta: float) -> void:
	# Gentle bobbing animation for spider
	_spider_bob_time += delta
	spider_sprite.position.y = _spider_base_pos.y + sin(_spider_bob_time * 2.0) * 4.0

func check_interaction(cursor_pos: Vector2) -> void:
	if _running or _speech_label == null:
		return
	if cursor_pos.distance_to(spider_sprite.global_position) > 100:
		return
	if GameManager.score <= 155 and GameManager.score > 98:
		if not GameManager.tutorial_done:
			_run_tutorial()
		else:
			_run_money_gift()

func _run_tutorial() -> void:
	_running = true
	_say("Hey there! Welcome to Fireplace 2!")
	await get_tree().create_timer(3.0).timeout
	_say("Grab those logs on the left and drag them into the fire!")
	await get_tree().create_timer(3.5).timeout
	_say("The fire bar at the top shows your heat level.")
	await get_tree().create_timer(3.0).timeout
	_say("Click SHOP below or press B to buy upgrades!")
	await get_tree().create_timer(3.5).timeout
	_say("Chain burns fast for COMBO bonus score!")
	await get_tree().create_timer(3.0).timeout
	_say("Good luck! Keep that fire burning!")
	await get_tree().create_timer(3.0).timeout
	_hide_speech()
	GameManager.tutorial_done = true
	_running = false
	tutorial_complete.emit()

func _run_money_gift() -> void:
	_running = true
	_say("Oh, you're back! Need a little help?")
	await get_tree().create_timer(2.5).timeout
	_say("Here, take some points. Don't spend them all at once!")
	GameManager.change_score(415)
	AudioManager.play_sfx("shop_buy")
	await get_tree().create_timer(4.0).timeout
	_hide_speech()
	_running = false

func _say(text: String) -> void:
	if _speech_label:
		_speech_label.text = text
		_speech_label.get_parent().visible = true

func _hide_speech() -> void:
	if _speech_label:
		_speech_label.get_parent().visible = false
