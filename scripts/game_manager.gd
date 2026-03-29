extends Node

## Fireplace 2 — Game Manager (Autoload singleton)
## Holds all shared game state so scenes/nodes can read/write it.

# ── Score ──
var score: int = 0

# ── Fire ──
var fire_level: float = 0.0
var fire_tick: int = 0

# ── Upgrades ──
var upgrade_firebrick: bool = false
var upgrade_bellows: bool = false
var upgrade_roofing: bool = false
var upgrade_phoenix: bool = false
var upgrade_sacrifice: bool = false
var upgrade_log_cap: bool = false

# ── Secret ──
var secret_demon: bool = false

# ── State ──
var use_dpad: bool = false
var raining: bool = false
var tutorial_done: bool = false
var fire_anim_playing: bool = false  # "an" in original
var end_button_visible: bool = false
var log_count: int = 0
var pity: int = 0
var playlist_index: int = 0

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
	secret_demon = false
	use_dpad = false
	raining = false
	tutorial_done = false
	fire_anim_playing = false
	end_button_visible = false
	log_count = 0
	pity = 0
	playlist_index = 0
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
