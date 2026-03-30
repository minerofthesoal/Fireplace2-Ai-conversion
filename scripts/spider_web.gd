extends Node2D

## Fireplace 2 — Spider Web with Soft Body Physics
## A short web hangs from the top of the screen. The cursor pushes web points.

const GRAVITY := 120.0
const DAMPING := 0.96
const STIFFNESS := 800.0
const CURSOR_PUSH_RADIUS := 60.0
const CURSOR_PUSH_FORCE := 250.0
const SEGMENT_COUNT := 8
const SEGMENT_REST_LENGTH := 16.0
const WEB_COLOR := Color(0.8, 0.8, 0.85, 0.7)
const WEB_COLOR_THIN := Color(0.75, 0.75, 0.8, 0.4)

# Each point has position and velocity
var points_pos: Array[Vector2] = []
var points_vel: Array[Vector2] = []
var points_pinned: Array[bool] = []

# Cross strands for visual web effect
var cross_strands: Array[Array] = []

@onready var web_sprite: Sprite2D = $WebSprite

func _ready() -> void:
	# Hide the static sprite; we draw dynamically
	web_sprite.visible = false

	# Create web points along a vertical line
	for i in range(SEGMENT_COUNT + 1):
		var y_pos: float = i * SEGMENT_REST_LENGTH
		points_pos.append(Vector2(0, y_pos))
		points_vel.append(Vector2.ZERO)
		points_pinned.append(i == 0)  # Pin top point

	# Cross strands at intervals for web look
	for i in range(2, SEGMENT_COUNT, 2):
		var width: float = 8.0 + i * 3.0
		cross_strands.append([i, -width, width])

func _process(delta: float) -> void:
	_simulate(delta)
	queue_redraw()

func _simulate(delta: float) -> void:
	# Apply gravity and damping
	for i in range(points_pos.size()):
		if points_pinned[i]:
			continue
		points_vel[i].y += GRAVITY * delta
		points_vel[i] *= DAMPING
		points_pos[i] += points_vel[i] * delta

	# Satisfy distance constraints (multiple iterations for stability)
	for _iter in range(4):
		for i in range(points_pos.size() - 1):
			var diff: Vector2 = points_pos[i + 1] - points_pos[i]
			var dist: float = diff.length()
			if dist < 0.001:
				continue
			var error: float = dist - SEGMENT_REST_LENGTH
			var correction: Vector2 = diff.normalized() * error * 0.5

			if not points_pinned[i]:
				points_pos[i] += correction
			if not points_pinned[i + 1]:
				points_pos[i + 1] -= correction

	# Spring force for more natural movement
	for i in range(points_pos.size() - 1):
		if points_pinned[i] and points_pinned[i + 1]:
			continue
		var diff: Vector2 = points_pos[i + 1] - points_pos[i]
		var dist: float = diff.length()
		var spring_force: Vector2 = diff.normalized() * (dist - SEGMENT_REST_LENGTH) * STIFFNESS * delta
		if not points_pinned[i]:
			points_vel[i] += spring_force * 0.5
		if not points_pinned[i + 1]:
			points_vel[i + 1] -= spring_force * 0.5

func apply_cursor_force(cursor_global_pos: Vector2) -> void:
	var local_cursor: Vector2 = cursor_global_pos - global_position
	for i in range(points_pos.size()):
		if points_pinned[i]:
			continue
		var dist: float = points_pos[i].distance_to(local_cursor)
		if dist < CURSOR_PUSH_RADIUS and dist > 1.0:
			var push_dir: Vector2 = (points_pos[i] - local_cursor).normalized()
			var strength: float = (1.0 - dist / CURSOR_PUSH_RADIUS) * CURSOR_PUSH_FORCE
			points_vel[i] += push_dir * strength

func _draw() -> void:
	# Draw main web strand
	for i in range(points_pos.size() - 1):
		draw_line(points_pos[i], points_pos[i + 1], WEB_COLOR, 2.0)

	# Draw thin secondary line
	for i in range(points_pos.size() - 1):
		var offset := Vector2(1.5, 0)
		draw_line(points_pos[i] + offset, points_pos[i + 1] + offset, WEB_COLOR_THIN, 1.0)

	# Draw cross strands
	for strand in cross_strands:
		var idx: int = int(strand[0])
		var left: float = float(strand[1])
		var right: float = float(strand[2])
		if idx < points_pos.size():
			var center: Vector2 = points_pos[idx]
			var left_pt: Vector2 = center + Vector2(left, absf(left) * 0.15)
			var right_pt: Vector2 = center + Vector2(right, absf(right) * 0.15)
			draw_line(left_pt, center, WEB_COLOR_THIN, 1.0)
			draw_line(center, right_pt, WEB_COLOR_THIN, 1.0)
			# Sag curve
			var mid_left: Vector2 = (left_pt + center) / 2.0 + Vector2(0, 3)
			draw_line(left_pt, mid_left, WEB_COLOR_THIN, 1.0)
			draw_line(mid_left, center, WEB_COLOR_THIN, 1.0)
			var mid_right: Vector2 = (center + right_pt) / 2.0 + Vector2(0, 3)
			draw_line(center, mid_right, WEB_COLOR_THIN, 1.0)
			draw_line(mid_right, right_pt, WEB_COLOR_THIN, 1.0)

	# Draw small dot at each joint
	for i in range(points_pos.size()):
		draw_circle(points_pos[i], 1.5, WEB_COLOR)

func get_end_position() -> Vector2:
	## Returns the global position of the last web point (where spider hangs).
	if points_pos.size() > 0:
		return global_position + points_pos[points_pos.size() - 1]
	return global_position
