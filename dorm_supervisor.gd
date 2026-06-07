extends Node2D

@export var patrol_start := Vector2.ZERO
@export var patrol_end := Vector2.ZERO
@export var speed := 82.0
@export var end_pause_time := 0.7
@export var sprite_visual: Sprite2D
@export var back_facing_rotation_degrees := 180.0

var _moving_to_end := true
var _pause_time_left := 0.0
var _anim_time := 0.0
var _sprite_base_position := Vector2.ZERO


func _ready() -> void:
	if sprite_visual == null:
		var found_sprite := get_node_or_null("Sprite2D")
		if found_sprite is Sprite2D:
			sprite_visual = found_sprite

	if sprite_visual != null:
		_sprite_base_position = sprite_visual.position
		sprite_visual.rotation_degrees = back_facing_rotation_degrees

	if patrol_start == Vector2.ZERO and patrol_end == Vector2.ZERO:
		patrol_start = global_position
		patrol_end = global_position

	global_position = patrol_start
	z_index = int(global_position.y)


func _process(delta: float) -> void:
	if _pause_time_left > 0.0:
		_pause_time_left -= delta
		_update_sprite_animation(delta, Vector2.ZERO)
		return

	var target := patrol_end if _moving_to_end else patrol_start
	var to_target := target - global_position
	if to_target.length() <= speed * delta:
		global_position = target
		_moving_to_end = not _moving_to_end
		_pause_time_left = end_pause_time
		_update_sprite_animation(delta, Vector2.ZERO)
		return

	var direction := to_target.normalized()
	global_position += direction * speed * delta
	z_index = int(global_position.y)
	_update_sprite_animation(delta, direction)


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
