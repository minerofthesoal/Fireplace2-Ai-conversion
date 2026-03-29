extends Node

## Fireplace 2 — Particle Effect Helpers
## Creates one-shot GPU particle bursts.

static func fire_burst(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 24
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.emitting = true
	burst.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, -60, 0)
	mat.color = Color(1.0, 0.5, 0.1, 1.0)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 1.2)

static func explosion(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.3, 0.0)) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 50
	burst.lifetime = 1.5
	burst.one_shot = true
	burst.emitting = true
	burst.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 35.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 100.0
	mat.initial_velocity_max = 250.0
	mat.gravity = Vector3(0, 120, 0)
	mat.color = col
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 3.0)

static func log_spawn_puff(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 14
	burst.lifetime = 0.4
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 16.0
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 70.0
	mat.gravity = Vector3.ZERO
	mat.color = Color(1.0, 0.5, 0.1, 0.8)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 1.0)

static func smoke_puff(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 10
	burst.lifetime = 0.8
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 12.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -30, 0)
	mat.color = Color(0.5, 0.5, 0.5, 0.5)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 1.5)

static func golden_burst(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 30
	burst.lifetime = 1.0
	burst.one_shot = true
	burst.emitting = true
	burst.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 25.0
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3(0, 50, 0)
	mat.color = Color(1.0, 0.85, 0.2, 1.0)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 2.0)

static func _auto_free(node: Node, delay: float) -> void:
	var timer := node.get_tree().create_timer(delay)
	timer.timeout.connect(node.queue_free)
