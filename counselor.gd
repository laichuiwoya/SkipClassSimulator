extends CharacterBody2D

@export var speed := 95.0
@export var spawn_area := Rect2(80, 80, 880, 460)
@export var target_reached_distance := 18.0
@export var stuck_check_time := 0.45
@export var stuck_distance := 5.0
@export var max_avoid_time := 1.6
@export var safe_point_attempts := 30
@export var min_phone_check_time := 1.2
@export var max_phone_check_time := 2.1
@export var min_phone_check_interval := 4.0
@export var max_phone_check_interval := 8.0
@export var sprite_visual: Sprite2D
@export var sight_visual: Polygon2D
@export var caught_bubble: CanvasItem
@export var player_path: NodePath
@export var vision_range := 320.0
@export var vision_half_angle_degrees := 38.0
@export var vision_segments := 12
@export var edge_margin := 72.0
@export var obstacle_parent_path: NodePath
@export var caught_pause_time := 1.3

var _rng := RandomNumberGenerator.new()
var _direction := Vector2.ZERO
var _facing_direction := Vector2.DOWN
var _anim_time := 0.0
var _sprite_base_position := Vector2.ZERO
var _player: Node2D
var _obstacle_parent: Node
var _was_player_seen := false
var _patrol_points: Array[Vector2] = []
var _patrol_index := 0
var _target_position := Vector2.ZERO
var _stuck_time_left := 0.0
var _last_stuck_check_position := Vector2.ZERO
var _avoid_time_left := 0.0
var _avoid_target_direction := Vector2.ZERO
var _avoid_total_time := 0.0
var _avoid_direction := Vector2.ZERO
var _phone_check_time_left := 0.0
var _phone_check_interval_left := 0.0
var _caught_pause_time_left := 0.0


func _ready() -> void:
	_rng.randomize()
	if sprite_visual == null:
		var found_sprite: Node = get_node_or_null("Sprite2D")
		if found_sprite is Sprite2D:
			sprite_visual = found_sprite
	if sprite_visual != null:
		_sprite_base_position = sprite_visual.position
	if sight_visual == null:
		var found_sight: Node = get_node_or_null("SightVisual")
		if found_sight is Polygon2D:
			sight_visual = found_sight
	if caught_bubble == null:
		var found_bubble: Node = get_node_or_null("CaughtBubble")
		if found_bubble is CanvasItem:
			caught_bubble = found_bubble
	if caught_bubble != null:
		caught_bubble.visible = false
	_find_player()
	_find_obstacle_parent()
	_move_to_safe_random_position()
	_build_patrol_points()
	_choose_next_target()
	_reset_stuck_check()
	_schedule_next_phone_check()
	_update_sight_visual()


func _physics_process(delta: float) -> void:
	if _caught_pause_time_left > 0.0:
		_process_caught_pause(delta)
		return

	if _phone_check_time_left > 0.0:
		_process_phone_check(delta)
		return

	_update_phone_check_interval(delta)
	_update_patrol_direction(delta)

	velocity = _direction * speed
	move_and_slide()
	var hit_screen_edge := _clamp_to_screen_bounds()

	if get_slide_collision_count() > 0:
		_recover_from_collision()
	elif hit_screen_edge:
		_finish_avoidance()
		_choose_next_target()
		_reset_stuck_check()

	_check_stuck(delta)

	_update_sight_visual()
	_update_sprite_animation(delta)
	_check_player_visibility()


func _update_patrol_direction(delta: float) -> void:
	if global_position.distance_to(_target_position) <= target_reached_distance:
		_choose_next_target()

	if _avoid_time_left > 0.0:
		_avoid_time_left -= delta
		_avoid_total_time += delta
		if _avoid_total_time >= max_avoid_time:
			_finish_avoidance()
		return

	var to_target := _target_position - global_position
	if to_target.length() <= target_reached_distance:
		_direction = Vector2.ZERO
		return

	_direction = to_target.normalized()
	_facing_direction = _direction


func _start_avoidance() -> void:
	if _direction == Vector2.ZERO:
		_choose_next_target()
		return

	var turn_side := -1.0
	if _rng.randf() < 0.5:
		turn_side = 1.0
	_direction = _direction.rotated(PI * 0.5 * turn_side).normalized()
	_facing_direction = _direction
	_avoid_time_left = _rng.randf_range(0.45, 0.9)


func _recover_from_collision() -> void:
	var collision_normal := Vector2.ZERO
	if get_slide_collision_count() > 0:
		var collision: KinematicCollision2D = get_slide_collision(0)
		collision_normal = collision.get_normal().normalized()

	var to_target := (_target_position - global_position).normalized()
	if to_target == Vector2.ZERO:
		to_target = _direction
	if to_target == Vector2.ZERO:
		to_target = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))

	if collision_normal == Vector2.ZERO:
		collision_normal = -to_target

	var tangent_a := collision_normal.rotated(PI * 0.5).normalized()
	var tangent_b := collision_normal.rotated(-PI * 0.5).normalized()
	if tangent_b.dot(to_target) > tangent_a.dot(to_target):
		tangent_a = tangent_b

	if _avoid_time_left <= 0.0:
		_avoid_direction = (tangent_a * 0.9 + collision_normal * 0.25).normalized()
		_avoid_total_time = 0.0

	_direction = _avoid_direction
	_avoid_target_direction = to_target
	_facing_direction = _direction
	_avoid_time_left = 0.9
	_reset_stuck_check()


func _clamp_to_screen_bounds() -> bool:
	var viewport_size := get_viewport_rect().size
	var bounds := _get_movement_bounds(viewport_size)
	var clamped_position := Vector2(
		clampf(global_position.x, bounds.position.x, bounds.end.x),
		clampf(global_position.y, bounds.position.y, bounds.end.y)
	)
	var hit_screen_edge := clamped_position != global_position
	global_position = clamped_position
	return hit_screen_edge


func _get_movement_bounds(viewport_size: Vector2) -> Rect2:
	var screen_bounds := Rect2(
		Vector2(edge_margin, edge_margin),
		Vector2(viewport_size.x - edge_margin * 2.0, viewport_size.y - edge_margin * 2.0)
	)
	return screen_bounds.intersection(spawn_area)


func _build_patrol_points() -> void:
	_patrol_points.clear()
	var bounds := _get_movement_bounds(get_viewport_rect().size)
	var columns := 4
	var rows := 2
	if bounds.size.y >= 260.0:
		rows = 3

	for row in range(rows):
		for column in range(columns):
			var x_ratio := 0.15 + 0.7 * float(column) / float(columns - 1)
			var y_ratio := 0.18 + 0.64 * float(row) / float(rows - 1)
			if row % 2 == 1:
				x_ratio = 1.0 - x_ratio
			var patrol_point := bounds.position + bounds.size * Vector2(x_ratio, y_ratio)
			if not _is_position_blocked(patrol_point):
				_patrol_points.append(patrol_point)

	_patrol_points.shuffle()


func _choose_next_target() -> void:
	if _patrol_points.is_empty():
		_build_patrol_points()
	if _patrol_points.is_empty():
		_target_position = global_position
		_direction = Vector2.ZERO
		return

	_target_position = _patrol_points[_patrol_index]
	_patrol_index = (_patrol_index + 1) % _patrol_points.size()


func _check_stuck(delta: float) -> void:
	_stuck_time_left -= delta
	if _stuck_time_left > 0.0:
		return

	var moved_distance := global_position.distance_to(_last_stuck_check_position)
	if moved_distance < stuck_distance:
		_recover_from_stuck()
	_reset_stuck_check()


func _reset_stuck_check() -> void:
	_stuck_time_left = stuck_check_time
	_last_stuck_check_position = global_position


func _recover_from_stuck() -> void:
	_move_to_nearest_safe_position()
	_finish_avoidance()
	_choose_next_target()


func _move_to_safe_random_position() -> void:
	var bounds := _get_movement_bounds(get_viewport_rect().size)
	for attempt in range(safe_point_attempts):
		var candidate := Vector2(
			_rng.randf_range(bounds.position.x, bounds.end.x),
			_rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if not _is_position_blocked(candidate):
			global_position = candidate
			return

	global_position = bounds.get_center()
	_move_to_nearest_safe_position()


func _move_to_nearest_safe_position() -> void:
	if not _is_position_blocked(global_position):
		return

	var bounds := _get_movement_bounds(get_viewport_rect().size)
	var origin := global_position
	var step := 28.0
	for ring in range(1, 8):
		for index in range(12):
			var offset := Vector2.RIGHT.rotated(TAU * float(index) / 12.0) * step * float(ring)
			var candidate := origin + offset
			candidate = Vector2(
				clampf(candidate.x, bounds.position.x, bounds.end.x),
				clampf(candidate.y, bounds.position.y, bounds.end.y)
			)
			if not _is_position_blocked(candidate):
				global_position = candidate
				return


func _finish_avoidance() -> void:
	_avoid_time_left = 0.0
	_avoid_total_time = 0.0
	_avoid_direction = Vector2.ZERO
	_avoid_target_direction = Vector2.ZERO


func _is_position_blocked(position_to_check: Vector2) -> bool:
	var collision_shape: CollisionShape2D = _get_collision_shape()
	if collision_shape == null or collision_shape.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(0.0, position_to_check + collision_shape.position)
	query.collision_mask = 2
	query.exclude = [_get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hits: Array = get_world_2d().direct_space_state.intersect_shape(query, 1)
	return not hits.is_empty()


func _get_collision_shape() -> CollisionShape2D:
	var child: Node = get_node_or_null("CollisionShape2D")
	if child is CollisionShape2D:
		return child
	return null


func _start_phone_check() -> void:
	_phone_check_time_left = _rng.randf_range(min_phone_check_time, max_phone_check_time)
	_phone_check_interval_left = 0.0
	_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	if sight_visual != null:
		sight_visual.visible = false


func _process_phone_check(delta: float) -> void:
	_phone_check_time_left -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	_update_phone_animation(delta)

	if _phone_check_time_left <= 0.0:
		if sight_visual != null:
			sight_visual.visible = true
		_reset_stuck_check()
		_schedule_next_phone_check()


func _update_phone_check_interval(delta: float) -> void:
	_phone_check_interval_left -= delta
	if _phone_check_interval_left <= 0.0:
		_start_phone_check()


func _schedule_next_phone_check() -> void:
	_phone_check_interval_left = _rng.randf_range(min_phone_check_interval, max_phone_check_interval)


func show_caught_bubble() -> void:
	_caught_pause_time_left = caught_pause_time
	_phone_check_time_left = 0.0
	_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	if caught_bubble != null:
		caught_bubble.visible = true
	if sight_visual != null:
		sight_visual.visible = false


func _process_caught_pause(delta: float) -> void:
	_caught_pause_time_left -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	_update_sprite_animation(delta)

	if _caught_pause_time_left <= 0.0:
		if caught_bubble != null:
			caught_bubble.visible = false
		if sight_visual != null:
			sight_visual.visible = true
		_was_player_seen = false
		_reset_stuck_check()
		_schedule_next_phone_check()


func _find_player() -> void:
	if player_path != NodePath():
		var path_player: Node = get_node_or_null(player_path)
		if path_player is Node2D:
			_player = path_player
	if _player == null:
		var parent_scene: Node = get_tree().current_scene
		if parent_scene != null:
			var scene_player: Node = parent_scene.get_node_or_null("Player")
			if scene_player is Node2D:
				_player = scene_player


func _update_sight_visual() -> void:
	if sight_visual == null:
		return

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for index in range(vision_segments + 1):
		var t := float(index) / float(vision_segments)
		var angle := deg_to_rad(lerpf(-vision_half_angle_degrees, vision_half_angle_degrees, t))
		points.append(_facing_direction.rotated(angle).normalized() * vision_range)
	sight_visual.polygon = points


func _check_player_visibility() -> void:
	if _player == null:
		_find_player()
	if _player == null:
		return
	if _player.has_method("is_forced_returning") and _player.call("is_forced_returning") == true:
		_was_player_seen = false
		return

	var can_see_player := _is_player_in_vision_cone() and not _is_player_behind_obstacle()
	if can_see_player and not _was_player_seen:
		var parent_scene: Node = get_tree().current_scene
		if parent_scene != null and parent_scene.has_method("handle_counselor_found_player"):
			parent_scene.call("handle_counselor_found_player", self)
	_was_player_seen = can_see_player


func _is_player_in_vision_cone() -> bool:
	var to_player := _player.global_position - global_position
	if to_player.length() > vision_range:
		return false
	if to_player == Vector2.ZERO:
		return true

	var angle_degrees := absf(rad_to_deg(_facing_direction.angle_to(to_player.normalized())))
	return angle_degrees <= vision_half_angle_degrees


func _find_obstacle_parent() -> void:
	if obstacle_parent_path != NodePath():
		_obstacle_parent = get_node_or_null(obstacle_parent_path)
	if _obstacle_parent == null:
		var parent_scene: Node = get_tree().current_scene
		if parent_scene != null:
			_obstacle_parent = parent_scene.get_node_or_null("Obstacles")


func _is_player_behind_obstacle() -> bool:
	if _player == null:
		return false
	if _obstacle_parent == null:
		_find_obstacle_parent()
	if _obstacle_parent == null:
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position)
	query.collision_mask = 2
	query.exclude = [_get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider: Variant = hit.get("collider")
	return collider is Node and _obstacle_parent.is_ancestor_of(collider)


func _get_rid() -> RID:
	if self is CollisionObject2D:
		return get_rid()
	return RID()


func _update_sprite_animation(delta: float) -> void:
	if sprite_visual == null:
		return

	if _direction.length() > 0.0:
		_anim_time += delta
		var stride := sin(_anim_time * 12.0)
		sprite_visual.position = _sprite_base_position + Vector2(stride, -absf(stride) * 1.5)
		sprite_visual.rotation_degrees = stride * 2.0
		sprite_visual.flip_h = _direction.x < 0.0
	else:
		sprite_visual.position = _sprite_base_position
		sprite_visual.rotation_degrees = 0.0


func _update_phone_animation(delta: float) -> void:
	if sprite_visual == null:
		return

	_anim_time += delta
	var bob := sin(_anim_time * 8.0)
	sprite_visual.position = _sprite_base_position + Vector2(0.0, -2.0 + bob * 0.8)
	sprite_visual.rotation_degrees = -8.0
