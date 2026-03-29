extends Node

## Fireplace 2 — Game Manager (Autoload singleton)
## Holds all shared game state.

signal score_changed(new_score: int)
signal fire_level_changed(new_level: float)
signal upgrade_purchased(upgrade_name: String)
signal achievement_earned(achievement_id: String)
signal combo_changed(new_combo: int)

# ── Score ──
var score: int = 0
var total_score_earned: int = 0

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
var upgrade_heat_shield: bool = false # 1000 — fire max raised to 7
var upgrade_log_magnet: bool = false  # 450 — logs auto-snap when near fire
var upgrade_combo_master: bool = false # 850 — combo decays slower

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

# ── Combo system ──
var combo_count: int = 0       # consecutive logs burned within window
var combo_timer: float = 0.0   # time since last log burn
var combo_best: int = 0
const COMBO_WINDOW: float = 4.0        # seconds to maintain combo
const COMBO_WINDOW_MASTER: float = 6.0 # with combo_master upgrade

# ── Wind events ──
var wind_active: bool = false
var wind_events_survived: int = 0

# ── Prestige ──
var prestige_count: int = 0
var prestige_bonus: float = 0.0  # +10% score per prestige

# ── Achievements ──
var achievements_unlocked: Array = []
const ACHIEVEMENTS := {
	"first_flame":    {"name": "First Flame",    "desc": "Light your first fire"},
	"log_master":     {"name": "Log Master",     "desc": "Burn 50 logs"},
	"inferno":        {"name": "Inferno",        "desc": "Reach max fire level"},
	"shopper":        {"name": "Shopper",        "desc": "Buy 5 upgrades"},
	"combo_3":        {"name": "Hot Streak",     "desc": "Get a 3x combo"},
	"combo_5":        {"name": "Blazing",        "desc": "Get a 5x combo"},
	"combo_10":       {"name": "Unstoppable",    "desc": "Get a 10x combo"},
	"survivor":       {"name": "Storm Survivor", "desc": "Survive 5 wind events"},
	"big_score":      {"name": "High Scorer",    "desc": "Reach 2000 score"},
	"huge_score":     {"name": "Score Legend",    "desc": "Reach 5000 score"},
	"burn_100":       {"name": "Pyromaniac",     "desc": "Burn 100 logs"},
	"prestige_1":     {"name": "Reborn",         "desc": "Prestige for the first time"},
	"all_upgrades":   {"name": "Fully Loaded",   "desc": "Buy all upgrades"},
	"marathon":       {"name": "Marathon",        "desc": "Play for 10 minutes"},
	"wind_master":    {"name": "Wind Master",    "desc": "Survive 20 wind events"},
	"secret_finder":  {"name": "Secret Finder",  "desc": "Discover the Konami code"},
}

# ── Settings (persisted across scenes) ──
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.4
var fullscreen: bool = false

# ── Konami code tracking ──
var combo_sequence: Array[String] = []
const KONAMI: Array[String] = ["down","down","up","up","left","right","left","right","b","a"]

func _process(delta: float) -> void:
	# Combo decay
	if combo_count > 0:
		combo_timer += delta
		var window: float = COMBO_WINDOW_MASTER if upgrade_combo_master else COMBO_WINDOW
		if combo_timer >= window:
			combo_count = 0
			combo_timer = 0.0
			combo_changed.emit(combo_count)

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
	upgrade_heat_shield = false
	upgrade_log_magnet = false
	upgrade_combo_master = false
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
	combo_count = 0
	combo_timer = 0.0
	wind_active = false
	# Don't reset: prestige_count, prestige_bonus, combo_best,
	# achievements_unlocked, total_score_earned, wind_events_survived
	combo_sequence.clear()

func add_combo_input(dir: String) -> void:
	combo_sequence.append(dir)
	if combo_sequence.size() > 10:
		combo_sequence = combo_sequence.slice(combo_sequence.size() - 10)
	if combo_sequence == KONAMI:
		secret_demon = true
		combo_sequence.clear()
		try_achievement("secret_finder")

func change_score(amount: int) -> void:
	if amount > 0:
		var bonus_amount: int = int(float(amount) * (1.0 + prestige_bonus))
		score += bonus_amount
		total_score_earned += bonus_amount
	else:
		score += amount
	if score < 0:
		score = 0
	score_changed.emit(score)
	_check_score_achievements()

func add_fire(amount: float) -> void:
	fire_level += amount
	var max_fire: float = 7.0 if upgrade_heat_shield else 5.0
	if fire_level > max_fire:
		fire_level = max_fire
	if fire_level > highest_fire_level:
		highest_fire_level = fire_level
	fire_level_changed.emit(fire_level)

func decay_fire(amount: float) -> void:
	fire_level -= amount
	var minimum: float = 0.5 if upgrade_ember_glow else 0.0
	if fire_level < minimum:
		fire_level = minimum
	fire_level_changed.emit(fire_level)

func get_log_cap() -> int:
	return 3 if upgrade_log_cap else 2

func get_fire_bonus() -> float:
	var bonus: float = 1.0
	if upgrade_bellows:
		bonus += 1.0
	return bonus

func get_score_per_tick() -> int:
	return 2 if upgrade_gold_fire else 1

func get_fire_max() -> float:
	return 7.0 if upgrade_heat_shield else 5.0

func register_log_burn() -> void:
	total_logs_burned += 1
	combo_count += 1
	combo_timer = 0.0
	if combo_count > combo_best:
		combo_best = combo_count
	combo_changed.emit(combo_count)
	_check_combo_achievements()
	_check_burn_achievements()

func get_combo_multiplier() -> float:
	if combo_count < 2:
		return 1.0
	return 1.0 + (combo_count - 1) * 0.25  # 2x=1.25, 3x=1.5, etc.

# ── Prestige ──
func can_prestige() -> bool:
	return score >= 3000

func do_prestige() -> void:
	prestige_count += 1
	prestige_bonus = prestige_count * 0.1  # +10% per prestige
	try_achievement("prestige_1")
	reset_game()

# ── Achievements ──
func try_achievement(id: String) -> bool:
	if id in achievements_unlocked:
		return false
	if id not in ACHIEVEMENTS:
		return false
	achievements_unlocked.append(id)
	achievement_earned.emit(id)
	return true

func get_achievement_name(id: String) -> String:
	if id in ACHIEVEMENTS:
		return ACHIEVEMENTS[id]["name"]
	return id

func get_achievement_desc(id: String) -> String:
	if id in ACHIEVEMENTS:
		return ACHIEVEMENTS[id]["desc"]
	return ""

func get_upgrade_count() -> int:
	var count: int = 0
	var upgrade_keys: Array[String] = [
		"upgrade_firebrick", "upgrade_bellows", "upgrade_roofing",
		"upgrade_phoenix", "upgrade_sacrifice", "upgrade_log_cap",
		"upgrade_auto_log", "upgrade_kindling", "upgrade_ember_glow",
		"upgrade_wind_guard", "upgrade_lucky_logs", "upgrade_gold_fire",
		"upgrade_heat_shield", "upgrade_log_magnet", "upgrade_combo_master",
	]
	for key in upgrade_keys:
		if get(key):
			count += 1
	return count

func _check_score_achievements() -> void:
	if score >= 2000:
		try_achievement("big_score")
	if score >= 5000:
		try_achievement("huge_score")

func _check_combo_achievements() -> void:
	if combo_count >= 3:
		try_achievement("combo_3")
	if combo_count >= 5:
		try_achievement("combo_5")
	if combo_count >= 10:
		try_achievement("combo_10")

func _check_burn_achievements() -> void:
	if total_logs_burned >= 1:
		try_achievement("first_flame")
	if total_logs_burned >= 50:
		try_achievement("log_master")
	if total_logs_burned >= 100:
		try_achievement("burn_100")
	if get_upgrade_count() >= 5:
		try_achievement("shopper")
	if get_upgrade_count() >= 15:
		try_achievement("all_upgrades")
