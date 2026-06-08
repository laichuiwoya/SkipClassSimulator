extends Control

@export var radius := 72.0
@export var knob_radius := 28.0
@export var deadzone := 0.18

var _touch_index := -1
var _vector := Vector2.ZERO
var _pressed := false


func _ready() -> void:
	add_to_group("virtual_joystick")
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size


func get_vector() -> Vector2:
	if _vector.length() < deadzone:
		return Vector2.ZERO
	return _vector


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_pressed = true
			_update_vector(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_reset()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_vector(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pressed = event.pressed
			if _pressed:
				_update_vector(event.position)
			else:
				_reset()
			accept_event()
	elif event is InputEventMouseMotion and _pressed:
		_update_vector(event.position)
		accept_event()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(0.06, 0.08, 0.1, 0.28))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.42), 4.0)
	draw_circle(center + _vector * radius, knob_radius, Color(1.0, 1.0, 1.0, 0.62))
	draw_arc(center + _vector * radius, knob_radius, 0.0, TAU, 32, Color(0.06, 0.08, 0.1, 0.2), 3.0)


func _update_vector(local_position: Vector2) -> void:
	var center := size * 0.5
	_vector = (local_position - center) / radius
	if _vector.length() > 1.0:
		_vector = _vector.normalized()
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	_pressed = false
	_vector = Vector2.ZERO
	queue_redraw()
