extends Control

## Fireplace 2 — Main Menu

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var play_btn: Button = $VBox/PlayBtn
@onready var continue_btn: Button = $VBox/ContinueBtn
@onready var options_btn: Button = $VBox/OptionsBtn
@onready var quit_btn: Button = $VBox/QuitBtn
@onready var fire_decor: GPUParticles2D = $FireDecor
@onready var prestige_label: Label = $VBox/PrestigeLabel
@onready var achievements_label: Label = $VBox/AchievementsLabel

func _ready() -> void:
	theme = ThemeBuilder.build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Style title
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.65, 0.45))

	# Show/hide continue button
	if SaveManager.has_save():
		continue_btn.visible = true
		continue_btn.grab_focus()
	else:
		continue_btn.visible = false
		play_btn.grab_focus()

	# Prestige info
	if GameManager.prestige_count > 0:
		prestige_label.text = "Prestige: x%d (+%d%% score)" % [GameManager.prestige_count, int(GameManager.prestige_bonus * 100)]
		prestige_label.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0))
		prestige_label.visible = true
	else:
		prestige_label.visible = false

	# Achievements count
	if GameManager.achievements_unlocked.size() > 0:
		achievements_label.text = "Achievements: %d / %d" % [
			GameManager.achievements_unlocked.size(),
			GameManager.ACHIEVEMENTS.size()
		]
		achievements_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		achievements_label.visible = true
	else:
		achievements_label.visible = false

	# Hover SFX
	for btn: Button in [play_btn, continue_btn, options_btn, quit_btn]:
		btn.mouse_entered.connect(func(): AudioManager.play_sfx("menu_hover"))

	play_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	options_btn.pressed.connect(_on_options)
	quit_btn.pressed.connect(_on_quit)

	# Load settings and start menu music
	SaveManager.load_settings()
	AudioManager.start_music()

func _on_new_game() -> void:
	AudioManager.play_sfx("button_click")
	AudioManager.stop_music()
	SaveManager.delete_save()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_continue() -> void:
	AudioManager.play_sfx("button_click")
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options() -> void:
	AudioManager.play_sfx("button_click")
	get_tree().change_scene_to_file("res://scenes/options.tscn")

func _on_quit() -> void:
	AudioManager.play_sfx("button_click")
	get_tree().quit()
