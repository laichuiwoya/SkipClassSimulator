extends CharacterBody2D
@export var speed = 300
@export var min_y := 155.0
@export var screen_bounds_padding := 0.0
@export var forced_return_speed := 520.0
@export var forced_return_delay := 1.6

@export var sprite_visual: Sprite2D

var _anim_time := 0.0
var _sprite_base_position := Vector2.ZERO
var _spawn_position := Vector2.ZERO
var _is_forced_returning := false
var _forced_return_delay_left := 0.0
var _is_control_locked := false


func _ready() -> void:
	if sprite_visual == null:
		var found_sprite := get_node_or_null("Sprite2D")
		if found_sprite is Sprite2D:
			sprite_visual = found_sprite
	if sprite_visual != null:
		_sprite_base_position = sprite_visual.position
	_clamp_to_screen_bounds()
	_spawn_position = global_position


func _physics_process(delta):
	if _is_control_locked:
		velocity = Vector2.ZERO
		_update_sprite_animation(delta, Vector2.ZERO)
		return

	if _is_forced_returning:
		_process_forced_return(delta)
		return

	var direction = Vector2.ZERO
	direction.x=Input.get_axis("ui_left","ui_right")
	direction.y=Input.get_axis("ui_up","ui_down")
	
	velocity = direction.normalized() * speed
	move_and_slide()
	_clamp_to_screen_bounds()
	_update_sprite_animation(delta, direction)
 


func _on_dorm_body_entered(_body: Node2D) -> void:
	pass # Replace with function body.


func force_return_to_spawn() -> void:
	_is_forced_returning = true
	_forced_return_delay_left = forced_return_delay
	velocity = Vector2.ZERO


func is_forced_returning() -> bool:
	return _is_forced_returning


func lock_control() -> void:
	_is_control_locked = true
	_is_forced_returning = false
	_forced_return_delay_left = 0.0
	velocity = Vector2.ZERO


func _process_forced_return(delta: float) -> void:
	if _forced_return_delay_left > 0.0:
		_forced_return_delay_left -= delta
		velocity = Vector2.ZERO
		_update_sprite_animation(delta, Vector2.ZERO)
		return

	var to_spawn := _spawn_position - global_position
	if to_spawn.length() <= 4.0:
		global_position = _spawn_position
		velocity = Vector2.ZERO
		_is_forced_returning = false
		_update_sprite_animation(delta, Vector2.ZERO)
		return

	var direction := to_spawn.normalized()
	velocity = Vector2.ZERO
	global_position = global_position.move_toward(_spawn_position, forced_return_speed * delta)
	_clamp_to_screen_bounds()
	_update_sprite_animation(delta, direction)


func _clamp_to_screen_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	var left := screen_bounds_padding
	var right := viewport_size.x - screen_bounds_padding
	var top := maxf(min_y, screen_bounds_padding)
	var bottom := viewport_size.y - screen_bounds_padding

	if sprite_visual != null and sprite_visual.texture != null:
		var visual_half_size := sprite_visual.texture.get_size() * sprite_visual.scale.abs() * 0.5
		left = maxf(left, visual_half_size.x - sprite_visual.position.x + screen_bounds_padding)
		right = minf(right, viewport_size.x - visual_half_size.x - sprite_visual.position.x - screen_bounds_padding)
		top = maxf(top, visual_half_size.y - sprite_visual.position.y + screen_bounds_padding)
		bottom = minf(bottom, viewport_size.y - visual_half_size.y - sprite_visual.position.y - screen_bounds_padding)

	if right < left:
		right = left
	if bottom < top:
		bottom = top

	global_position = Vector2(
		clampf(global_position.x, left, right),
		clampf(global_position.y, top, bottom)
	)


func _update_sprite_animation(delta: float, direction: Vector2) -> void:
	if sprite_visual == null:
		return

	if direction.length() > 0.0:
		_anim_time += delta
		var stride := sin(_anim_time * 16.0)
		sprite_visual.position = _sprite_base_position + Vector2(stride * 1.2, -absf(stride) * 2.0)
		if absf(direction.x) > absf(direction.y):
			sprite_visual.flip_h = false
			sprite_visual.rotation_degrees = _get_horizontal_facing_rotation(direction) + stride * 3.0
		else:
			sprite_visual.flip_h = false
			sprite_visual.rotation_degrees = _get_vertical_facing_rotation(direction) + stride * 3.0
	else:
		sprite_visual.position = _sprite_base_position
		sprite_visual.rotation_degrees = 0.0
		sprite_visual.flip_h = false


func _get_vertical_facing_rotation(direction: Vector2) -> float:
	if direction.y < 0.0:
		return 180.0

	return 0.0


func _get_horizontal_facing_rotation(direction: Vector2) -> float:
	if direction.x > 0.0:
		return -90.0
	return 90.0
