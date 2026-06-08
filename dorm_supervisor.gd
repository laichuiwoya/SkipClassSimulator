extends Node2D

@export var patrol_start := Vector2.ZERO
@export var patrol_end := Vector2.ZERO
@export var speed := 82.0
@export var min_pause_time := 0.45
@export var max_pause_time := 1.2
@export var min_patrol_step_distance := 120.0
@export var sprite_visual: Sprite2D
@export var back_facing_rotation_degrees := 0.0
@export var randomize_spawn := true
@export var initial_direction := 1
@export var player_path: NodePath
@export var horizontal_vision_line_thickness := 155.0
@export var vertical_vision_line_thickness := 210.0
@export var caught_pause_time := 1.5

var _rng := RandomNumberGenerator.new()
var _pause_time_left := 0.0
var _caught_pause_time_left := 0.0
var _anim_time := 0.0
var _sprite_base_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _direction_sign := 1
var _player: Node2D = null
var _facing_direction := Vector2.RIGHT
var _was_player_seen := false
var _caught_bubble: Node2D = null


func _ready() -> void:
	_rng.randomize()
	if sprite_visual == null:
		var found_sprite := get_node_or_null("Sprite2D")
		if found_sprite is Sprite2D:
			sprite_visual = found_sprite

	if sprite_visual != null:
		_sprite_base_position = sprite_visual.position
		sprite_visual.rotation_degrees = back_facing_rotation_degrees

	_build_caught_bubble()

	if patrol_start == Vector2.ZERO and patrol_end == Vector2.ZERO:
		patrol_start = global_position
		patrol_end = global_position

	_find_player()
	_direction_sign = 1 if initial_direction >= 0 else -1
	if randomize_spawn:
		global_position = patrol_start.lerp(patrol_end, _rng.randf())
		if _rng.randf() < 0.5:
			_direction_sign = -1
	else:
		global_position = patrol_start
	_choose_next_opposite_target()
	_update_facing_from_target()
	z_index = int(global_position.y)


func _process(delta: float) -> void:
	if _caught_pause_time_left > 0.0:
		_caught_pause_time_left -= delta
		_update_sprite_animation(delta, Vector2.ZERO)
		if _caught_pause_time_left <= 0.0 and _caught_bubble != null:
			_caught_bubble.visible = false
		return

	if _pause_time_left > 0.0:
		_pause_time_left -= delta
		_update_sprite_animation(delta, Vector2.ZERO)
		_check_player_visibility()
		return

	var to_target := _target_position - global_position
	if to_target.length() <= speed * delta:
		global_position = _target_position
		_pause_time_left = _rng.randf_range(min_pause_time, max_pause_time)
		_direction_sign *= -1
		_choose_next_opposite_target()
		_update_sprite_animation(delta, Vector2.ZERO)
		_check_player_visibility()
		return

	var direction := to_target.normalized()
	_facing_direction = direction
	global_position += direction * speed * delta
	z_index = int(global_position.y)
	_update_sprite_animation(delta, direction)
	_check_player_visibility()


func _choose_next_opposite_target() -> void:
	var patrol_delta := patrol_end - patrol_start
	if patrol_delta == Vector2.ZERO:
		_target_position = patrol_start
		return

	var current_ratio := _get_patrol_ratio(global_position)
	var min_ratio := 0.0
	var max_ratio := maxf(0.0, current_ratio - 0.08)
	if _direction_sign > 0:
		min_ratio = minf(1.0, current_ratio + 0.08)
		max_ratio = 1.0

	if max_ratio < min_ratio:
		_direction_sign *= -1
		_choose_next_opposite_target()
		return

	for attempt in range(8):
		var next_ratio := _rng.randf_range(min_ratio, max_ratio)
		var candidate := patrol_start.lerp(patrol_end, next_ratio)
		if candidate.distance_to(global_position) >= min_patrol_step_distance:
			_target_position = candidate
			return

	if _direction_sign > 0:
		_target_position = patrol_end
	else:
		_target_position = patrol_start


func _get_patrol_ratio(position: Vector2) -> float:
	var patrol_delta := patrol_end - patrol_start
	var length_squared := patrol_delta.length_squared()
	if length_squared <= 0.0:
		return 0.0
	return clampf((position - patrol_start).dot(patrol_delta) / length_squared, 0.0, 1.0)


func _update_facing_from_target() -> void:
	var to_target := _target_position - global_position
	if to_target != Vector2.ZERO:
		_facing_direction = to_target.normalized()


func _find_player() -> void:
	if player_path != NodePath():
		var path_player := get_node_or_null(player_path)
		if path_player is Node2D:
			_player = path_player
	if _player == null:
		var parent_scene := get_tree().current_scene
		if parent_scene != null:
			var scene_player := parent_scene.get_node_or_null("Player")
			if scene_player is Node2D:
				_player = scene_player


func _check_player_visibility() -> void:
	if _player == null:
		_find_player()
	if _player == null or not _player.visible:
		_was_player_seen = false
		return

	var can_see_player := _is_player_in_front_view()
	if can_see_player and not _was_player_seen:
		var parent_scene := get_tree().current_scene
		if parent_scene != null and parent_scene.has_method("handle_dorm_supervisor_found_player"):
			parent_scene.call("handle_dorm_supervisor_found_player", self)
	_was_player_seen = can_see_player


func _is_player_in_front_view() -> bool:
	var to_player := _player.global_position - global_position
	if to_player == Vector2.ZERO:
		return true

	var forward_distance := to_player.dot(_facing_direction)
	if forward_distance < 0.0:
		return false

	var side_distance := absf(to_player.cross(_facing_direction))
	var line_thickness := _get_current_vision_line_thickness()
	return side_distance <= line_thickness * 0.5 + _get_player_detection_margin()


func _get_current_vision_line_thickness() -> float:
	if absf(_facing_direction.x) >= absf(_facing_direction.y):
		return horizontal_vision_line_thickness
	return vertical_vision_line_thickness


func _get_player_detection_margin() -> float:
	if _player == null:
		return 0.0

	var collision_shape := _player.get_node_or_null("CollisionShape2D")
	if collision_shape is CollisionShape2D and collision_shape.shape is RectangleShape2D:
		var rectangle_shape := collision_shape.shape as RectangleShape2D
		var scaled_size := rectangle_shape.size * _player.scale.abs()
		if absf(_facing_direction.x) >= absf(_facing_direction.y):
			return scaled_size.y * 0.5
		return scaled_size.x * 0.5

	return 20.0


func show_caught_bubble() -> void:
	_caught_pause_time_left = caught_pause_time
	_was_player_seen = false
	if _caught_bubble != null:
		_caught_bubble.visible = true


func _build_caught_bubble() -> void:
	var old_bubble := get_node_or_null("CaughtBubble")
	if old_bubble != null:
		old_bubble.queue_free()

	_caught_bubble = Node2D.new()
	_caught_bubble.name = "CaughtBubble"
	_caught_bubble.position = Vector2(28, -76)
	_caught_bubble.visible = false
	_caught_bubble.z_index = 1000
	add_child(_caught_bubble)

	_add_rect(_caught_bubble, "BubbleBack", -28, -24, 212, 24, Color(1.0, 0.96, 0.82, 1.0))
	_add_rect(_caught_bubble, "BubbleBorderTop", -32, -28, 216, -24, Color(0.2, 0.11, 0.07, 1.0))
	_add_rect(_caught_bubble, "BubbleBorderBottom", -32, 24, 216, 28, Color(0.2, 0.11, 0.07, 1.0))
	_add_rect(_caught_bubble, "BubbleBorderLeft", -32, -24, -28, 24, Color(0.2, 0.11, 0.07, 1.0))
	_add_rect(_caught_bubble, "BubbleBorderRight", 212, -24, 216, 24, Color(0.2, 0.11, 0.07, 1.0))

	var label := Label.new()
	label.name = "BubbleText"
	label.offset_left = -18.0
	label.offset_top = -16.0
	label.offset_right = 202.0
	label.offset_bottom = 16.0
	label.add_theme_color_override("font_color", Color(0.23, 0.06, 0.03, 1.0))
	label.add_theme_font_size_override("font_size", 20)
	label.text = "想溜走？快回教室！"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caught_bubble.add_child(label)


func _update_sprite_animation(delta: float, direction: Vector2) -> void:
	if sprite_visual == null:
		return

	sprite_visual.rotation_degrees = back_facing_rotation_degrees
	sprite_visual.flip_h = direction.x < 0.0

	if direction == Vector2.ZERO:
		sprite_visual.position = _sprite_base_position
		return

	_anim_time += delta
	var stride := sin(_anim_time * 12.0)
	sprite_visual.position = _sprite_base_position + Vector2(stride * 0.8, -absf(stride) * 1.4)


func _add_rect(parent: Node, node_name: String, left: float, top: float, right: float, bottom: float, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.offset_left = left
	rect.offset_top = top
	rect.offset_right = right
	rect.offset_bottom = bottom
	rect.color = color
	parent.add_child(rect)
	return rect
