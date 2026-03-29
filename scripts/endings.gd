extends Node

## Fireplace 2 — Endings
## Each ending is its own function. Called from the game scene.

signal ending_complete(won: bool, ending_name: String, score: int)

var _parent: Node2D

func setup(parent: Node2D) -> void:
	_parent = parent

func trigger() -> void:
	var s := GameManager.score
	if GameManager.secret_demon:
		_ending_demon()
	elif GameManager.upgrade_sacrifice and GameManager.fire_level >= 4:
		_ending_sacrifice()
	elif GameManager.upgrade_phoenix and s >= 2500:
		_ending_phoenix()
	elif s >= 3000:
		_ending_legendary()
	elif s >= 1500:
		_ending_great()
	elif s >= 500:
		_ending_good()
	else:
		_ending_cold()

# ═══════════════════════════════════════════════════════════
# ENDING 1 — Demon (Konami code secret)
# ═══════════════════════════════════════════════════════════

func _ending_demon() -> void:
	AudioManager.play_sfx("ending_explosion")
	for i in range(8):
		Effects.explosion(_parent, Vector2(randi_range(40, 600), randi_range(40, 440)), Color.DARK_RED)
		await _parent.get_tree().create_timer(0.2).timeout
	await _parent.get_tree().create_timer(1.5).timeout
	ending_complete.emit(false, "DEMON", GameManager.score)

# ═══════════════════════════════════════════════════════════
# ENDING 2 — Sacrifice (upgrade + fire at max)
# ═══════════════════════════════════════════════════════════

func _ending_sacrifice() -> void:
	AudioManager.play_sfx("ending_explosion")
	Effects.explosion(_parent, Vector2(320, 240), Color(0.8, 0.1, 0.0))
	Effects.explosion(_parent, Vector2(320, 240), Color(0.4, 0.0, 0.0))
	await _parent.get_tree().create_timer(2.0).timeout
	ending_complete.emit(true, "SACRIFICE", GameManager.score)

# ═══════════════════════════════════════════════════════════
# ENDING 3 — Phoenix (upgrade + high score)
# ═══════════════════════════════════════════════════════════

func _ending_phoenix() -> void:
	AudioManager.play_sfx("ending_explosion")
	for i in range(5):
		Effects.golden_burst(_parent, Vector2(randi_range(160, 480), randi_range(120, 360)))
		await _parent.get_tree().create_timer(0.3).timeout
	await _parent.get_tree().create_timer(2.0).timeout
	ending_complete.emit(true, "PHOENIX", GameManager.score)

# ═══════════════════════════════════════════════════════════
# ENDING 4 — Legendary (score >= 3000)
# ═══════════════════════════════════════════════════════════

func _ending_legendary() -> void:
	AudioManager.play_sfx("ending_explosion")
	Effects.explosion(_parent, Vector2(320, 240), Color(1.0, 0.85, 0.2))
	Effects.golden_burst(_parent, Vector2(320, 200))
	await _parent.get_tree().create_timer(2.5).timeout
	ending_complete.emit(true, "LEGENDARY", GameManager.score)

# ═══════════════════════════════════════════════════════════
# ENDING 5 — Great (score >= 1500)
# ═══════════════════════════════════════════════════════════

func _ending_great() -> void:
	AudioManager.play_sfx("ending_explosion")
	Effects.explosion(_parent, Vector2(320, 240), Color(1.0, 0.5, 0.1))
	await _parent.get_tree().create_timer(2.0).timeout
	ending_complete.emit(true, "GREAT FIRE", GameManager.score)

# ═══════════════════════════════════════════════════════════
# ENDING 6 — Good (score >= 500)
# ═══════════════════════════════════════════════════════════

func _ending_good() -> void:
	Effects.smoke_puff(_parent, Vector2(320, 240))
	await _parent.get_tree().create_timer(2.0).timeout
	ending_complete.emit(true, "WARM HEARTH", GameManager.score)

# ═══════════════════════════════════════════════════════════
# ENDING 7 — Cold (score < 500)
# ═══════════════════════════════════════════════════════════

func _ending_cold() -> void:
	Effects.smoke_puff(_parent, Vector2(320, 300))
	await _parent.get_tree().create_timer(2.0).timeout
	ending_complete.emit(false, "COLD ASHES", GameManager.score)
