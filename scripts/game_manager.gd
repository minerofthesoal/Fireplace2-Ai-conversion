extends Node

## Fireplace 2 — Game Manager (Autoload singleton)
## Holds all shared game state.

signal score_changed(new_score: int)
signal fire_level_changed(new_level: float)
signal upgrade_purchased(upgrade_name: String)
signal ending_triggered(ending_name: String)

# ── Score ──
var score: int = 0

# ── Fire ──
var fire_level: float = 0.0
var fire_tick: int = 0

# ── Original upgrades ──
var upgrade_firebrick: bool = false   # 200 — fire decays slower
var upgrade_bellows: bool = false     # 350 — logs burn hotter (+1 fire)
var upgrade_roofing: bool = false     # 500 — rain penalty removed
var upgrade_phoenix: bool = false     # 800 — unlocks Phoenix ending
var upgrade_sacrifice: bool = false   # 1200 — unlocks Sacrifice ending
var upgrade_log_cap: bool = false     # 650 — 2 → 3 log cap

# ── New upgrades ──
var upgrade_auto_log: bool = false    # 900 — auto-feeds logs periodically
var upgrade_kindling: bool = false    # 150 — fire starts easier (+1 on first log)
var upgrade_ember_glow: bool = false  # 400 — fire never fully dies (min 0.5)
var upgrade_wind_guard: bool = false  # 600 — 50% rain resistance
var upgrade_lucky_logs: bool = false  # 750 — big log chance doubled
var upgrade_gold_fire: bool = false   # 1500 — score ticks give +2 instead of +1

# ── Secret ──
var secret_demon: bool = false

# ── State ──
var use_dpad: bool = false
var raining: bool = false
var tutorial_done: bool = false
var fire_anim_playing: bool = false
var end_button_visible: bool = false
var log_count: int = 0
var pity: int = 0
var playlist_index: int = 0
var total_logs_burned: int = 0
var game_time: float = 0.0
var highest_fire_level: float = 0.0

# ── Settings (persisted across scenes) ──
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.4
var fullscreen: bool = false

# ── Konami code tracking ──
var combo_sequence: Array[String] = []
const KONAMI: Array[String] = ["down","down","up","up","left","right","left","right","b","a"]

func reset_game() -> void:
	score = 0
	fire_level = 0.0
	fire_tick = 0
	upgrade_firebrick = false
	upgrade_bellows = false
	upgrade_roofing = false
	upgrade_phoenix = false
	upgrade_sacrifice = false
	upgrade_log_cap = false
	upgrade_auto_log = false
	upgrade_kindling = false
	upgrade_ember_glow = false
	upgrade_wind_guard = false
	upgrade_lucky_logs = false
	upgrade_gold_fire = false
	secret_demon = false
	use_dpad = false
	raining = false
	tutorial_done = false
	fire_anim_playing = false
	end_button_visible = false
	log_count = 0
	pity = 0
	playlist_index = 0
	total_logs_burned = 0
	game_time = 0.0
	highest_fire_level = 0.0
	combo_sequence.clear()

func add_combo_input(dir: String) -> void:
	combo_sequence.append(dir)
	if combo_sequence.size() > 10:
		combo_sequence = combo_sequence.slice(combo_sequence.size() - 10)
	if combo_sequence == KONAMI:
		secret_demon = true
		combo_sequence.clear()

func change_score(amount: int) -> void:
	score += amount
	if score < 0:
		score = 0
	score_changed.emit(score)

func add_fire(amount: float) -> void:
	fire_level += amount
	if fire_level > 5.0:
		fire_level = 5.0
	if fire_level > highest_fire_level:
		highest_fire_level = fire_level
	fire_level_changed.emit(fire_level)

func decay_fire(amount: float) -> void:
	fire_level -= amount
	var minimum := 0.5 if upgrade_ember_glow else 0.0
	if fire_level < minimum:
		fire_level = minimum
	fire_level_changed.emit(fire_level)

func get_log_cap() -> int:
	return 3 if upgrade_log_cap else 2

func get_fire_bonus() -> float:
	var bonus := 1.0
	if upgrade_bellows:
		bonus += 1.0
	return bonus

func get_score_per_tick() -> int:
	return 2 if upgrade_gold_fire else 1
