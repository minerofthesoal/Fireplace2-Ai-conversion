extends Node

## Fireplace 2 — Particle Effect Helpers
## Creates one-shot GPU particle bursts with warm fire colors.

static func fire_burst(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 30
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.emitting = true
	burst.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 16.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 50.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, -80, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	var gradient := _fire_gradient()
	mat.color_ramp = gradient
	mat.color = Color(1.0, 0.6, 0.1, 0.9)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 1.5)

static func explosion(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.3, 0.0)) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 60
	burst.lifetime = 1.5
	burst.one_shot = true
	burst.emitting = true
	burst.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 30.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 220.0
	mat.gravity = Vector3(0, 150, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = col
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 3.0)

static func log_spawn_puff(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 16
	burst.lifetime = 0.4
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 12.0
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Color(0.9, 0.6, 0.3, 0.7)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 1.0)

static func smoke_puff(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 14
	burst.lifetime = 1.0
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3(0, -40, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(0.55, 0.5, 0.45, 0.45)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 2.0)

static func golden_burst(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 35
	burst.lifetime = 1.0
	burst.one_shot = true
	burst.emitting = true
	burst.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0
	mat.spread = 180.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 130.0
	mat.gravity = Vector3(0, 60, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.85, 0.2, 1.0)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 2.5)

static func ember_trail(parent: Node, pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.position = pos
	burst.amount = 8
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(1.0, 0.4, 0.1, 0.8)
	burst.process_material = mat
	parent.add_child(burst)
	_auto_free(burst, 1.0)

static func _fire_gradient() -> GradientTexture1D:
	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	g.add_point(0.4, Color(1.0, 0.5, 0.1, 0.8))
	g.add_point(0.7, Color(0.8, 0.2, 0.0, 0.5))
	g.set_color(1, Color(0.4, 0.1, 0.0, 0.0))
	grad.gradient = g
	return grad

static func _auto_free(node: Node, delay: float) -> void:
	var timer := node.get_tree().create_timer(delay)
	timer.timeout.connect(node.queue_free)
