extends Button

@export var action_name := "interact"

var _is_pressing_action := false


func _ready() -> void:
	text = "F"
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_press_action)
	button_up.connect(_release_action)


func _exit_tree() -> void:
	_release_action()


func _press_action() -> void:
	if _is_pressing_action:
		return
	_is_pressing_action = true
	Input.action_press(action_name)


func _release_action() -> void:
	if not _is_pressing_action:
		return
	_is_pressing_action = false
	Input.action_release(action_name)
