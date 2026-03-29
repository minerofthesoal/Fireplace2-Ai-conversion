extends Control

## Fireplace 2 — Options Menu

@onready var master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var fullscreen_check: CheckButton = $Panel/VBox/FullscreenRow/FullscreenCheck
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var master_val: Label = $Panel/VBox/MasterRow/MasterVal
@onready var sfx_val: Label = $Panel/VBox/SfxRow/SfxVal
@onready var music_val: Label = $Panel/VBox/MusicRow/MusicVal

func _ready() -> void:
	theme = ThemeBuilder.build()

	master_slider.value = GameManager.master_volume * 100
	sfx_slider.value = GameManager.sfx_volume * 100
	music_slider.value = GameManager.music_volume * 100
	fullscreen_check.button_pressed = GameManager.fullscreen

	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_btn.pressed.connect(_on_back)
	back_btn.grab_focus()

	_update_labels()

func _on_master_changed(val: float) -> void:
	GameManager.master_volume = val / 100.0
	AudioManager.master_volume = GameManager.master_volume
	_update_labels()

func _on_sfx_changed(val: float) -> void:
	GameManager.sfx_volume = val / 100.0
	AudioManager.sfx_volume = GameManager.sfx_volume
	AudioManager.play_sfx("button_click")
	_update_labels()

func _on_music_changed(val: float) -> void:
	GameManager.music_volume = val / 100.0
	AudioManager.music_volume = GameManager.music_volume
	_update_labels()

func _on_fullscreen_toggled(pressed: bool) -> void:
	GameManager.fullscreen = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	AudioManager.play_sfx("button_click")

func _on_back() -> void:
	AudioManager.play_sfx("button_click")
	SaveManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_labels() -> void:
	master_val.text = "%d%%" % int(master_slider.value)
	sfx_val.text = "%d%%" % int(sfx_slider.value)
	music_val.text = "%d%%" % int(music_slider.value)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
