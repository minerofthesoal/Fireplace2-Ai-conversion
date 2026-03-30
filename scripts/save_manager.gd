extends Node

## Fireplace 2 — Save Manager (Autoload)
## Auto-saves game state and settings. Loads on startup.

const SAVE_PATH := "user://fireplace2_save.dat"
const SETTINGS_PATH := "user://fireplace2_settings.dat"
const AUTO_SAVE_INTERVAL := 30.0  # seconds

var _auto_save_timer: float = 0.0
var _in_game: bool = false

func _ready() -> void:
	load_settings()

func _process(delta: float) -> void:
	if not _in_game:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()

func enter_game() -> void:
	_in_game = true
	_auto_save_timer = 0.0

func leave_game() -> void:
	_in_game = false

# ═══════════════════════════════════════════════════════════
# GAME SAVE / LOAD
# ═══════════════════════════════════════════════════════════

func save_game() -> void:
	var data := {
		"score": GameManager.score,
		"fire_level": GameManager.fire_level,
		"fire_tick": GameManager.fire_tick,
		"upgrade_firebrick": GameManager.upgrade_firebrick,
		"upgrade_bellows": GameManager.upgrade_bellows,
		"upgrade_roofing": GameManager.upgrade_roofing,
		"upgrade_phoenix": GameManager.upgrade_phoenix,
		"upgrade_sacrifice": GameManager.upgrade_sacrifice,
		"upgrade_log_cap": GameManager.upgrade_log_cap,
		"upgrade_auto_log": GameManager.upgrade_auto_log,
		"upgrade_kindling": GameManager.upgrade_kindling,
		"upgrade_ember_glow": GameManager.upgrade_ember_glow,
		"upgrade_wind_guard": GameManager.upgrade_wind_guard,
		"upgrade_lucky_logs": GameManager.upgrade_lucky_logs,
		"upgrade_gold_fire": GameManager.upgrade_gold_fire,
		"upgrade_heat_shield": GameManager.upgrade_heat_shield,
		"upgrade_log_magnet": GameManager.upgrade_log_magnet,
		"upgrade_combo_master": GameManager.upgrade_combo_master,
		"secret_demon": GameManager.secret_demon,
		"tutorial_done": GameManager.tutorial_done,
		"total_logs_burned": GameManager.total_logs_burned,
		"game_time": GameManager.game_time,
		"highest_fire_level": GameManager.highest_fire_level,
		"prestige_count": GameManager.prestige_count,
		"prestige_bonus": GameManager.prestige_bonus,
		"combo_best": GameManager.combo_best,
		"achievements_unlocked": GameManager.achievements_unlocked.duplicate(),
		"total_score_earned": GameManager.total_score_earned,
		"wind_events_survived": GameManager.wind_events_survived,
		"current_room": GameManager.current_room,
		"coins": GameManager.coins,
		"chopped_logs": GameManager.chopped_logs,
		"current_tool": GameManager.current_tool,
		"chop_power": GameManager.chop_power,
		"sleep_cooldown": GameManager.sleep_cooldown,
		"story_stage": GameManager.story_stage,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var data: Variant = file.get_var()
	file.close()
	if not data is Dictionary:
		return false
	var d: Dictionary = data
	GameManager.score = d.get("score", 0)
	GameManager.fire_level = d.get("fire_level", 0.0)
	GameManager.fire_tick = d.get("fire_tick", 0)
	GameManager.upgrade_firebrick = d.get("upgrade_firebrick", false)
	GameManager.upgrade_bellows = d.get("upgrade_bellows", false)
	GameManager.upgrade_roofing = d.get("upgrade_roofing", false)
	GameManager.upgrade_phoenix = d.get("upgrade_phoenix", false)
	GameManager.upgrade_sacrifice = d.get("upgrade_sacrifice", false)
	GameManager.upgrade_log_cap = d.get("upgrade_log_cap", false)
	GameManager.upgrade_auto_log = d.get("upgrade_auto_log", false)
	GameManager.upgrade_kindling = d.get("upgrade_kindling", false)
	GameManager.upgrade_ember_glow = d.get("upgrade_ember_glow", false)
	GameManager.upgrade_wind_guard = d.get("upgrade_wind_guard", false)
	GameManager.upgrade_lucky_logs = d.get("upgrade_lucky_logs", false)
	GameManager.upgrade_gold_fire = d.get("upgrade_gold_fire", false)
	GameManager.upgrade_heat_shield = d.get("upgrade_heat_shield", false)
	GameManager.upgrade_log_magnet = d.get("upgrade_log_magnet", false)
	GameManager.upgrade_combo_master = d.get("upgrade_combo_master", false)
	GameManager.secret_demon = d.get("secret_demon", false)
	GameManager.tutorial_done = d.get("tutorial_done", false)
	GameManager.total_logs_burned = d.get("total_logs_burned", 0)
	GameManager.game_time = d.get("game_time", 0.0)
	GameManager.highest_fire_level = d.get("highest_fire_level", 0.0)
	GameManager.prestige_count = d.get("prestige_count", 0)
	GameManager.prestige_bonus = d.get("prestige_bonus", 0.0)
	GameManager.combo_best = d.get("combo_best", 0)
	GameManager.achievements_unlocked = d.get("achievements_unlocked", [])
	GameManager.total_score_earned = d.get("total_score_earned", 0)
	GameManager.wind_events_survived = d.get("wind_events_survived", 0)
	GameManager.current_room = d.get("current_room", 0)
	GameManager.coins = d.get("coins", 0)
	GameManager.chopped_logs = d.get("chopped_logs", 0)
	GameManager.current_tool = d.get("current_tool", 0)
	GameManager.chop_power = d.get("chop_power", 1.0)
	GameManager.sleep_cooldown = d.get("sleep_cooldown", 0.0)
	GameManager.story_stage = d.get("story_stage", 0)
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# ═══════════════════════════════════════════════════════════
# SETTINGS SAVE / LOAD (persists across sessions)
# ═══════════════════════════════════════════════════════════

func save_settings() -> void:
	var data := {
		"master_volume": GameManager.master_volume,
		"sfx_volume": GameManager.sfx_volume,
		"music_volume": GameManager.music_volume,
		"fullscreen": GameManager.fullscreen,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var data: Variant = file.get_var()
	file.close()
	if not data is Dictionary:
		return
	var d: Dictionary = data
	GameManager.master_volume = d.get("master_volume", 0.8)
	GameManager.sfx_volume = d.get("sfx_volume", 1.0)
	GameManager.music_volume = d.get("music_volume", 0.4)
	GameManager.fullscreen = d.get("fullscreen", false)
	AudioManager.master_volume = GameManager.master_volume
	AudioManager.sfx_volume = GameManager.sfx_volume
	AudioManager.music_volume = GameManager.music_volume
	if GameManager.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
