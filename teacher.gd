extends CharacterBody2D

const TEACHER_WRITE_TEXTURE := preload("res://assets/teacher_write.png")

@export var speed := 120.0
@export var patrol_left_x := 396.0
@export var patrol_right_x := 756.0
@export var front_marker: Node2D
@export var back_marker: CanvasItem
@export var visual_root: Node2D
@export var sprite_visual: Sprite2D
@export var chalk_stick: ColorRect
@export var writing_marks: Node2D
@export var sight_visual: Polygon2D
@export var anger_bubble: CanvasItem
@export var game_over_popup: CanvasItem
@export var player_path: NodePath
@export var vision_range := 900.0
@export var vision_half_angle_degrees := 40.0
@export var vision_segments := 18
@export var first_desk_row_y := 220.0
@export var min_move_time := 1.2
@export var max_move_time := 2.4
@export var min_blackboard_time := 0.7
@export var max_blackboard_time := 1.5
@export var anger_bubble_time := 1.6
@export var max_caught_count := 3

var _target_x := 756.0
var _state_time_left := 0.0
var _is_facing_blackboard := true
var _is_moving := true
var _player: Node2D
var _was_player_visible := false
var _anim_time := 0.0
var _sprite_base_position := Vector2.ZERO
var _teacher_walk_texture: Texture2D
var _anger_bubble_time_left := 0.0
var _is_caught_pause_active := false
var _caught_count := 0
var _is_game_over := false


func _ready() -> void:
	randomize()
	_find_child_nodes()
	_find_player()
	if sprite_visual != null:
		_sprite_base_position = sprite_visual.position
		_teacher_walk_texture = sprite_visual.texture
	_target_x = patrol_right_x
	_start_moving()


func _physics_process(delta: float) -> void:
	if _is_game_over:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite_animation(delta)
		return

	if _is_caught_pause_active:
		_update_anger_bubble(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite_animation(delta)
		return

	_update_state(delta)
	_update_anger_bubble(delta)

	if _is_moving:
		_patrol()
	else:
		velocity = Vector2.ZERO
		move_and_slide()

	_update_sprite_animation(delta)
	_check_player_visibility()


func _patrol() -> void:
	var direction := signf(_target_x - global_position.x)
	if direction == 0.0:
		_switch_target()
		direction = signf(_target_x - global_position.x)

	velocity = Vector2(direction * speed, 0)
	move_and_slide()

	if absf(global_position.x - _target_x) < 4.0:
		_switch_target()


func _find_child_nodes() -> void:
	if visual_root == null:
		var found_visual_root := get_node_or_null("VisualRoot")
		if found_visual_root is Node2D:
			visual_root = found_visual_root
	if front_marker == null:
		var found_front_marker := get_node_or_null("VisualRoot/FrontMarker")
		if found_front_marker is Node2D:
			front_marker = found_front_marker
	if back_marker == null:
		var found_back_marker := get_node_or_null("VisualRoot/BackMarker")
		if found_back_marker is CanvasItem:
			back_marker = found_back_marker
	if sprite_visual == null:
		var found_sprite_visual := get_node_or_null("Sprite2D")
		if found_sprite_visual == null:
			found_sprite_visual = get_node_or_null("VisualRoot/Sprite2D")
		if found_sprite_visual is Sprite2D:
			sprite_visual = found_sprite_visual
	if chalk_stick == null:
		var found_chalk_stick := get_node_or_null("ChalkStick")
		if found_chalk_stick is ColorRect:
			chalk_stick = found_chalk_stick
	if writing_marks == null:
		var blackboard := get_parent().get_node_or_null("Blackboard")
		if blackboard != null:
			var found_writing_marks := blackboard.get_node_or_null("WritingMarks")
			if found_writing_marks is Node2D:
				writing_marks = found_writing_marks
	if sight_visual == null:
		var found_sight_visual := get_node_or_null("VisualRoot/SightVisual")
		if found_sight_visual is Polygon2D:
			sight_visual = found_sight_visual
	if anger_bubble == null:
		var found_anger_bubble := get_node_or_null("AngerBubble")
		if found_anger_bubble is CanvasItem:
			anger_bubble = found_anger_bubble
	if game_over_popup == null:
		var found_game_over_popup := get_parent().get_node_or_null("GameOverPopup")
		if found_game_over_popup is CanvasItem:
			game_over_popup = found_game_over_popup


func _find_player() -> void:
	if player_path != NodePath():
		var path_player := get_node_or_null(player_path)
		if path_player is Node2D:
			_player = path_player
	if _player == null:
		var grouped_player := get_tree().get_first_node_in_group("player")
		if grouped_player is Node2D:
			_player = grouped_player
	if _player == null:
		var sibling_player := get_parent().get_node_or_null("Player")
		if sibling_player is Node2D:
			_player = sibling_player


func _update_state(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return

	if _is_moving:
		_start_looking_at_blackboard()
	else:
		_start_moving()


func _start_moving() -> void:
	_is_moving = true
	_is_facing_blackboard = false
	_set_writing_visible(false)
	_state_time_left = randf_range(min_move_time, max_move_time)
	_apply_facing()


func _start_looking_at_blackboard() -> void:
	_is_moving = false
	_is_facing_blackboard = true
	_was_player_visible = false
	_set_writing_visible(true)
	_state_time_left = randf_range(min_blackboard_time, max_blackboard_time)
	_apply_facing()


func _switch_target() -> void:
	if _target_x == patrol_right_x:
		_target_x = patrol_left_x
	else:
		_target_x = patrol_right_x


func _apply_facing() -> void:
	if _is_facing_blackboard:
		if visual_root != null:
			visual_root.scale = Vector2(1, 1)
		if sprite_visual != null:
			sprite_visual.visible = true
			sprite_visual.flip_h = false
			sprite_visual.texture = TEACHER_WRITE_TEXTURE
		if front_marker != null:
			front_marker.visible = sprite_visual == null
			front_marker.position = Vector2(0, -10)
		if back_marker != null:
			back_marker.visible = false
		if sight_visual != null:
			sight_visual.visible = false
	else:
		if visual_root != null:
			visual_root.scale = Vector2(1, 1)
		if sprite_visual != null:
			sprite_visual.visible = true
			sprite_visual.flip_h = velocity.x < 0.0
			if _teacher_walk_texture != null:
				sprite_visual.texture = _teacher_walk_texture
		if front_marker != null:
			front_marker.visible = sprite_visual == null
			front_marker.position = Vector2(0, 10)
		if back_marker != null:
			back_marker.visible = false
		if sight_visual != null:
			sight_visual.visible = true
			_update_sight_visual()
		_check_player_visibility()


func _check_player_visibility() -> void:
	if _player == null:
		_find_player()
	if _player == null:
		return
	if _is_player_forced_returning():
		_was_player_visible = false
		return

	var can_see_player := _is_player_above_first_desk_row() or (_is_player_in_vision_cone() and _has_no_desk_cover_above_player())
	if can_see_player and not _was_player_visible:
		_handle_player_caught()
	_was_player_visible = can_see_player


func _is_player_in_vision_cone() -> bool:
	if _is_facing_blackboard:
		return false

	var to_player := _player.global_position - global_position
	if to_player.length() > vision_range:
		return false
	if to_player == Vector2.ZERO:
		return true

	var angle_degrees := absf(rad_to_deg(Vector2.DOWN.angle_to(to_player.normalized())))
	return angle_degrees <= vision_half_angle_degrees


func _is_player_above_first_desk_row() -> bool:
	return _player.global_position.y < first_desk_row_y


func _has_no_desk_cover_above_player() -> bool:
	var start_position := _player.global_position
	var end_position := Vector2(_player.global_position.x, global_position.y)
	var query := PhysicsRayQueryParameters2D.create(start_position, end_position)
	query.exclude = _get_visibility_ray_excludes()
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	return not _is_desk(hit.get("collider"))


func _get_visibility_ray_excludes() -> Array[RID]:
	var excludes: Array[RID] = [get_rid()]
	var player_rid := _get_player_rid()
	if player_rid.is_valid():
		excludes.append(player_rid)
	return excludes


func _get_player_rid() -> RID:
	if _player is CollisionObject2D:
		return _player.get_rid()
	return RID()


func _is_desk(collider: Object) -> bool:
	if collider == null or not collider is Node:
		return false

	var node := collider as Node
	var parent := node.get_parent()
	return node.name.begins_with("Desk") or (parent != null and parent.name == "Desks")


func _update_sight_visual() -> void:
	var half_angle := deg_to_rad(vision_half_angle_degrees)
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(vision_segments + 1):
		var t := float(index) / float(vision_segments)
		var angle := lerpf(-half_angle, half_angle, t)
		points.append(Vector2.DOWN.rotated(angle) * vision_range)
	sight_visual.polygon = points


func _handle_player_caught() -> void:
	print("被老师发现了！")
	_caught_count += 1
	if _caught_count >= max_caught_count:
		_trigger_game_over()
		return

	_show_anger_bubble()
	if _player != null and _player.has_method("force_return_to_spawn"):
		_player.set("forced_return_delay", anger_bubble_time)
		_player.call("force_return_to_spawn")


func _trigger_game_over() -> void:
	_is_game_over = true
	_is_caught_pause_active = false
	_anger_bubble_time_left = 0.0
	velocity = Vector2.ZERO
	if sight_visual != null:
		sight_visual.visible = false
	if anger_bubble != null:
		anger_bubble.visible = false
	if game_over_popup != null:
		game_over_popup.visible = true
	if _player != null and _player.has_method("lock_control"):
		_player.call("lock_control")


func _show_anger_bubble() -> void:
	_anger_bubble_time_left = anger_bubble_time
	_is_caught_pause_active = true
	velocity = Vector2.ZERO
	if anger_bubble != null:
		anger_bubble.visible = true


func _update_anger_bubble(delta: float) -> void:
	if _anger_bubble_time_left <= 0.0:
		return

	_anger_bubble_time_left -= delta
	if _anger_bubble_time_left <= 0.0:
		_is_caught_pause_active = false
		if anger_bubble != null:
			anger_bubble.visible = false


func _is_player_forced_returning() -> bool:
	if _player != null and _player.has_method("is_forced_returning"):
		return _player.call("is_forced_returning") == true
	return false


func _update_sprite_animation(delta: float) -> void:
	_anim_time += delta
	if sprite_visual == null:
		return

	if _is_moving:
		var stride := sin(_anim_time * 14.0)
		sprite_visual.position = _sprite_base_position + Vector2(stride * 1.5, -absf(stride) * 2.0)
		sprite_visual.rotation_degrees = stride * 3.0
		if chalk_stick != null:
			chalk_stick.visible = false
		return

	if _is_facing_blackboard:
		var write_motion := sin(_anim_time * 18.0)
		sprite_visual.position = _sprite_base_position + Vector2(write_motion * 1.0, -2.0)
		sprite_visual.rotation_degrees = write_motion * 2.0
		if chalk_stick != null:
			chalk_stick.visible = true
			chalk_stick.position = Vector2(18.0 + write_motion * 8.0, -36.0)
		_update_writing_marks()
	else:
		sprite_visual.position = _sprite_base_position
		sprite_visual.rotation_degrees = 0.0


func _set_writing_visible(is_visible: bool) -> void:
	if chalk_stick != null:
		chalk_stick.visible = is_visible
	if writing_marks != null:
		writing_marks.visible = is_visible


func _update_writing_marks() -> void:
	if writing_marks == null:
		return

	var active_count := 1 + int(fposmod(_anim_time * 5.0, max(1, writing_marks.get_child_count())))
	for index in range(writing_marks.get_child_count()):
		var mark := writing_marks.get_child(index)
		if mark is CanvasItem:
			mark.visible = index < active_count
