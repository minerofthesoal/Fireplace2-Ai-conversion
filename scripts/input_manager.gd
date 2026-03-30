extends Node2D

## Fireplace 2 — Input Manager
## Handles mouse, d-pad, and Konami code input for the cursor.

signal grab_requested(cursor_pos: Vector2)
signal release_requested(cursor_pos: Vector2)
signal shop_requested

const DPAD_SPEED := 8.0
const SCREEN_W := 640
const SCREEN_H := 480

@onready var cursor: Sprite2D = $Cursor

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _input(event: InputEvent) -> void:
	# Konami code tracking
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP: GameManager.add_combo_input("up")
			KEY_DOWN: GameManager.add_combo_input("down")
			KEY_LEFT: GameManager.add_combo_input("left")
			KEY_RIGHT: GameManager.add_combo_input("right")
			KEY_B: GameManager.add_combo_input("b")
			KEY_A: GameManager.add_combo_input("a")

	# Toggle input mode
	if event.is_action_pressed("toggle_input_mode"):
		GameManager.use_dpad = not GameManager.use_dpad

	# Mouse movement
	if event is InputEventMouseMotion and not GameManager.use_dpad:
		cursor.position = event.position

	# Mouse click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not GameManager.use_dpad:
			grab_requested.emit(cursor.position)
		elif not event.pressed and not GameManager.use_dpad:
			release_requested.emit(cursor.position)

	# D-pad grab/release
	if event.is_action_pressed("button_a") and GameManager.use_dpad:
		grab_requested.emit(cursor.position)
	if event.is_action_released("button_a") and GameManager.use_dpad:
		release_requested.emit(cursor.position)

	# Shop via B
	if event.is_action_pressed("button_b") and GameManager.use_dpad:
		shop_requested.emit()

func _process(_delta: float) -> void:
	if not GameManager.use_dpad:
		return
	if Input.is_action_pressed("move_left"):
		cursor.position.x = maxf(0.0, cursor.position.x - DPAD_SPEED)
	if Input.is_action_pressed("move_right"):
		cursor.position.x = minf(float(SCREEN_W), cursor.position.x + DPAD_SPEED)
	if Input.is_action_pressed("move_up"):
		cursor.position.y = maxf(0.0, cursor.position.y - DPAD_SPEED)
	if Input.is_action_pressed("move_down"):
		cursor.position.y = minf(float(SCREEN_H), cursor.position.y + DPAD_SPEED)

func get_cursor_pos() -> Vector2:
	return cursor.position
