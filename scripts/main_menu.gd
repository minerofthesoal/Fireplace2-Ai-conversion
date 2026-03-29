extends Control

## Fireplace 2 — Main Menu

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var play_btn: Button = $VBox/PlayBtn
@onready var options_btn: Button = $VBox/OptionsBtn
@onready var quit_btn: Button = $VBox/QuitBtn
@onready var fire_particles: GPUParticles2D = $FireDecor

func _ready() -> void:
	theme = ThemeBuilder.build()
	play_btn.pressed.connect(_on_play)
	options_btn.pressed.connect(_on_options)
	quit_btn.pressed.connect(_on_quit)
	play_btn.mouse_entered.connect(func(): AudioManager.play_sfx("menu_hover"))
	options_btn.mouse_entered.connect(func(): AudioManager.play_sfx("menu_hover"))
	quit_btn.mouse_entered.connect(func(): AudioManager.play_sfx("menu_hover"))
	play_btn.grab_focus()
	AudioManager.start_music()

func _on_play() -> void:
	AudioManager.play_sfx("button_click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options() -> void:
	AudioManager.play_sfx("button_click")
	get_tree().change_scene_to_file("res://scenes/options.tscn")

func _on_quit() -> void:
	AudioManager.play_sfx("button_click")
	get_tree().quit()
