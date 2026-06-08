extends Node2D

@export var cell_obstacles_path: NodePath = NodePath("CellObstacles")
@export var player_path: NodePath = NodePath("Player")
@export var door_prompt_distance := 78.0
@export var max_supervisor_found_count := 3
@export var return_to_spawn_delay := 0.6
@export var restart_scene_path := "res://main.tscn"

const ROOM_BODY := Color(0.72, 0.68, 0.58, 1.0)
const ROOM_TOP := Color(0.86, 0.82, 0.7, 1.0)
const ROOM_SIDE := Color(0.55, 0.51, 0.44, 1.0)
const ROOM_SHADOW := Color(0.18, 0.17, 0.15, 0.55)
const ROOM_OUTLINE := Color(0.22, 0.18, 0.14, 1.0)
const DOOR_FRONT := Color(0.3, 0.18, 0.1, 1.0)
const DOOR_HIGHLIGHT := Color(0.55, 0.34, 0.18, 1.0)
const WINDOW_BLUE := Color(0.48, 0.72, 0.82, 1.0)

var _door_spots: Array[Dictionary] = []
var _player: Node2D = null
var _door_prompt: Node2D = null
var _nearest_door_spot := -1
var _entered_door_spot := -1
var _is_inside_dorm := false
var _was_f_pressed := false
var _supervisor_found_count := 0
var _is_game_over := false
var _game_over_popup: Node2D = null
var _victory_popup: Node2D = null

static var _saved_supervisor_found_count := 0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_supervisor_found_count = _saved_supervisor_found_count
	_build_door_prompt()
	_build_game_over_popup()
	_build_victory_popup()
	_door_spots.clear()
	_build_top_dorm_doors()

	var cell_obstacles := get_node_or_null(cell_obstacles_path)
	if cell_obstacles == null:
		return

	for room in cell_obstacles.get_children():
		if room is StaticBody2D:
			_build_pixel_dorm_room(room)


func _process(_delta: float) -> void:
	_update_door_prompt()
	_process_dorm_enter_exit()


func handle_dorm_supervisor_found_player(finding_supervisor: Node = null) -> void:
	if _is_game_over or _is_inside_dorm:
		return
	if _player != null and _player.has_method("is_forced_returning") and _player.call("is_forced_returning") == true:
		return

	_supervisor_found_count += 1
	_saved_supervisor_found_count = _supervisor_found_count
	var return_delay := return_to_spawn_delay
	if finding_supervisor != null and finding_supervisor.has_method("show_caught_bubble"):
		finding_supervisor.call("show_caught_bubble")
		return_delay = float(finding_supervisor.get("caught_pause_time"))

	if _supervisor_found_count >= max_supervisor_found_count:
		_trigger_supervisor_game_over()
		return

	_reload_current_level_after_delay(return_delay)


func _trigger_supervisor_game_over() -> void:
	_is_game_over = true
	if _player != null and _player.has_method("lock_control"):
		_player.call("lock_control")
	if _game_over_popup != null:
		_game_over_popup.visible = true


func _reload_current_level_after_delay(delay: float) -> void:
	if _player != null and _player.has_method("lock_control"):
		_player.call("lock_control")
	await get_tree().create_timer(delay).timeout
	if not _is_game_over:
		get_tree().reload_current_scene()


func _build_door_prompt() -> void:
	var old_prompt := get_node_or_null("DoorPromptBubble")
	if old_prompt != null:
		old_prompt.queue_free()

	_door_prompt = Node2D.new()
	_door_prompt.name = "DoorPromptBubble"
	_door_prompt.z_index = 1000
	_door_prompt.visible = false
	add_child(_door_prompt)

	_add_rect(_door_prompt, "BubbleBack", -70, -22, 70, 22, Color(1.0, 0.96, 0.82, 0.94))
	_add_rect(_door_prompt, "BubbleBorderTop", -72, -24, 72, -20, Color(0.28, 0.18, 0.1, 1.0))
	_add_rect(_door_prompt, "BubbleBorderBottom", -72, 20, 72, 24, Color(0.28, 0.18, 0.1, 1.0))
	_add_rect(_door_prompt, "BubbleBorderLeft", -72, -24, -68, 24, Color(0.28, 0.18, 0.1, 1.0))
	_add_rect(_door_prompt, "BubbleBorderRight", 68, -24, 72, 24, Color(0.28, 0.18, 0.1, 1.0))

	var label := Label.new()
	label.name = "BubbleText"
	label.offset_left = -64.0
	label.offset_top = -14.0
	label.offset_right = 64.0
	label.offset_bottom = 14.0
	label.add_theme_color_override("font_color", Color(0.12, 0.09, 0.06, 1.0))
	label.add_theme_font_size_override("font_size", 18)
	label.text = "按F进入宿舍"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_door_prompt.add_child(label)


func _build_game_over_popup() -> void:
	var old_popup := get_node_or_null("SupervisorGameOverPopup")
	if old_popup != null:
		old_popup.queue_free()

	_game_over_popup = Node2D.new()
	_game_over_popup.name = "SupervisorGameOverPopup"
	_game_over_popup.visible = false
	_game_over_popup.z_index = 2000
	add_child(_game_over_popup)

	_add_rect(_game_over_popup, "Dim", 0, 0, 1050, 620, Color(0, 0, 0, 0.42))
	_add_rect(_game_over_popup, "Panel", 220, 204, 830, 432, Color(1, 0.95, 0.82, 1))
	_add_rect(_game_over_popup, "PanelBorderTop", 212, 196, 838, 204, Color(0.2, 0.11, 0.07, 1))
	_add_rect(_game_over_popup, "PanelBorderBottom", 212, 432, 838, 440, Color(0.2, 0.11, 0.07, 1))
	_add_rect(_game_over_popup, "PanelBorderLeft", 212, 204, 220, 432, Color(0.2, 0.11, 0.07, 1))
	_add_rect(_game_over_popup, "PanelBorderRight", 830, 204, 838, 432, Color(0.2, 0.11, 0.07, 1))

	var title := Label.new()
	title.name = "Title"
	title.offset_left = 242.0
	title.offset_top = 232.0
	title.offset_right = 808.0
	title.offset_bottom = 288.0
	title.add_theme_color_override("font_color", Color(0.23, 0.06, 0.03, 1))
	title.add_theme_font_size_override("font_size", 34)
	title.text = "你被宿管记住了"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_popup.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.offset_left = 242.0
	hint.offset_top = 292.0
	hint.offset_right = 808.0
	hint.offset_bottom = 326.0
	hint.add_theme_color_override("font_color", Color(0.33, 0.18, 0.1, 1))
	hint.add_theme_font_size_override("font_size", 20)
	hint.text = "游戏结束"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_popup.add_child(hint)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.offset_left = 280.0
	restart_button.offset_top = 354.0
	restart_button.offset_right = 470.0
	restart_button.offset_bottom = 396.0
	restart_button.add_theme_font_size_override("font_size", 20)
	restart_button.text = "重新开始"
	restart_button.pressed.connect(_on_restart_button_pressed)
	_game_over_popup.add_child(restart_button)

	var restart_current_button := Button.new()
	restart_current_button.name = "RestartCurrentLevelButton"
	restart_current_button.offset_left = 520.0
	restart_current_button.offset_top = 354.0
	restart_current_button.offset_right = 750.0
	restart_current_button.offset_bottom = 396.0
	restart_current_button.add_theme_font_size_override("font_size", 20)
	restart_current_button.text = "从此关重新开始"
	restart_current_button.pressed.connect(_on_restart_current_level_button_pressed)
	_game_over_popup.add_child(restart_current_button)


func _on_restart_button_pressed() -> void:
	_reset_supervisor_found_count()
	get_tree().change_scene_to_file(restart_scene_path)


func _on_restart_current_level_button_pressed() -> void:
	_reset_supervisor_found_count()
	get_tree().reload_current_scene()


func _reset_supervisor_found_count() -> void:
	_supervisor_found_count = 0
	_saved_supervisor_found_count = 0


func _update_door_prompt() -> void:
	if _door_prompt == null or _player == null:
		return
	if _is_game_over:
		_door_prompt.visible = false
		return

	_nearest_door_spot = -1
	var nearest_spot := {}
	var nearest_distance := INF
	for i in _door_spots.size():
		var spot := _door_spots[i]
		var distance := _player.global_position.distance_to(to_global(spot["prompt_position"]))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_spot = spot
			_nearest_door_spot = i

	if _is_inside_dorm and _entered_door_spot >= 0:
		_nearest_door_spot = _entered_door_spot
		nearest_spot = _door_spots[_entered_door_spot]
		_set_prompt_text("按F离开宿舍")
		_door_prompt.position = nearest_spot["prompt_position"] + nearest_spot["prompt_offset"]
		_door_prompt.visible = true
	elif nearest_distance <= door_prompt_distance:
		_set_prompt_text("按F进入宿舍")
		_door_prompt.position = nearest_spot["prompt_position"] + nearest_spot["prompt_offset"]
		_door_prompt.visible = true
	else:
		_door_prompt.visible = false


func _process_dorm_enter_exit() -> void:
	if _is_game_over:
		return
	if _victory_popup != null and _victory_popup.visible:
		return
	var is_f_pressed := Input.is_key_pressed(KEY_F)
	var just_pressed_f := is_f_pressed and not _was_f_pressed
	_was_f_pressed = is_f_pressed

	if _player == null or _nearest_door_spot < 0:
		return

	if not just_pressed_f:
		return

	if _is_inside_dorm:
		_exit_dorm()
	else:
		_enter_dorm(_nearest_door_spot)


func _enter_dorm(door_spot_index: int) -> void:
	_is_inside_dorm = true
	_entered_door_spot = door_spot_index
	_player.visible = false
	_player.set_physics_process(false)
	var spot := _door_spots[door_spot_index]
	if bool(spot.get("is_goal", false)):
		_trigger_victory()


func _exit_dorm() -> void:
	var spot := _door_spots[_entered_door_spot]
	_player.global_position = to_global(spot["exit_position"])
	_player.visible = true
	_player.set_physics_process(true)
	_is_inside_dorm = false
	_entered_door_spot = -1


func _set_prompt_text(text: String) -> void:
	if _door_prompt == null:
		return
	var label := _door_prompt.get_node_or_null("BubbleText")
	if label is Label:
		label.text = text


func _build_victory_popup() -> void:
	var old_popup := get_node_or_null("VictoryPopup")
	if old_popup != null:
		old_popup.queue_free()

	_victory_popup = Node2D.new()
	_victory_popup.name = "VictoryPopup"
	_victory_popup.visible = false
	_victory_popup.z_index = 2000
	add_child(_victory_popup)

	_add_rect(_victory_popup, "Dim", 0, 0, 1050, 620, Color(0, 0, 0, 0.36))
	_add_rect(_victory_popup, "Panel", 240, 204, 810, 432, Color(0.96, 1.0, 0.86, 1))
	_add_rect(_victory_popup, "PanelBorderTop", 232, 196, 818, 204, Color(0.12, 0.28, 0.1, 1))
	_add_rect(_victory_popup, "PanelBorderBottom", 232, 432, 818, 440, Color(0.12, 0.28, 0.1, 1))
	_add_rect(_victory_popup, "PanelBorderLeft", 232, 204, 240, 432, Color(0.12, 0.28, 0.1, 1))
	_add_rect(_victory_popup, "PanelBorderRight", 810, 204, 818, 432, Color(0.12, 0.28, 0.1, 1))

	var title := Label.new()
	title.name = "Title"
	title.offset_left = 262.0
	title.offset_top = 232.0
	title.offset_right = 788.0
	title.offset_bottom = 288.0
	title.add_theme_color_override("font_color", Color(0.08, 0.24, 0.08, 1))
	title.add_theme_font_size_override("font_size", 36)
	title.text = "成功回到宿舍"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_victory_popup.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.offset_left = 262.0
	hint.offset_top = 292.0
	hint.offset_right = 788.0
	hint.offset_bottom = 326.0
	hint.add_theme_color_override("font_color", Color(0.14, 0.28, 0.12, 1))
	hint.add_theme_font_size_override("font_size", 20)
	hint.text = "通关成功"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_victory_popup.add_child(hint)

	var quit_button := Button.new()
	quit_button.name = "QuitButton"
	quit_button.offset_left = 310.0
	quit_button.offset_top = 354.0
	quit_button.offset_right = 470.0
	quit_button.offset_bottom = 396.0
	quit_button.add_theme_font_size_override("font_size", 20)
	quit_button.text = "退出游戏"
	quit_button.pressed.connect(_on_quit_button_pressed)
	_victory_popup.add_child(quit_button)

	var play_again_button := Button.new()
	play_again_button.name = "PlayAgainButton"
	play_again_button.offset_left = 550.0
	play_again_button.offset_top = 354.0
	play_again_button.offset_right = 710.0
	play_again_button.offset_bottom = 396.0
	play_again_button.add_theme_font_size_override("font_size", 20)
	play_again_button.text = "再来一次"
	play_again_button.pressed.connect(_on_play_again_button_pressed)
	_victory_popup.add_child(play_again_button)


func _trigger_victory() -> void:
	_reset_supervisor_found_count()
	if _door_prompt != null:
		_door_prompt.visible = false
	if _victory_popup != null:
		_victory_popup.visible = true


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_play_again_button_pressed() -> void:
	_reset_supervisor_found_count()
	get_tree().change_scene_to_file(restart_scene_path)


func _build_top_dorm_doors() -> void:
	var old_visual := get_node_or_null("TopDormDoors")
	if old_visual != null:
		old_visual.queue_free()

	var visual_root := Node2D.new()
	visual_root.name = "TopDormDoors"
	visual_root.z_index = 2
	add_child(visual_root)

	var door_centers := [120.0, 300.0, 480.0, 660.0, 840.0, 990.0]
	for i in door_centers.size():
		var x := float(door_centers[i])
		_add_top_door(visual_root, "TopDoor%d" % (i + 1), x)
		_add_door_spot(Vector2(x, 22), Vector2(x, 70), Vector2(0, 44), false)


func _add_top_door(parent: Node, door_name: String, center_x: float) -> void:
	var door_root := Node2D.new()
	door_root.name = door_name
	door_root.position = Vector2(center_x, 0)
	parent.add_child(door_root)

	_add_rect(door_root, "TopDepth", -48, 0, 48, 10, Color(0.66, 0.6, 0.5, 0.32))
	_add_rect(door_root, "WoodHeader", -36, 12, 36, 22, Color(DOOR_HIGHLIGHT.r, DOOR_HIGHLIGHT.g, DOOR_HIGHLIGHT.b, 0.68))


func _build_pixel_dorm_room(room: StaticBody2D) -> void:
	var old_visual := room.get_node_or_null("Visual")
	if old_visual != null:
		old_visual.queue_free()

	room.z_index = int(room.global_position.y)

	var visual_root := Node2D.new()
	visual_root.name = "PixelDormVisual"
	room.add_child(visual_root)

	_add_rect(visual_root, "Shadow", -98, 62, 112, 80, ROOM_SHADOW)
	_add_rect(visual_root, "FrontFace", -96, -44, 96, 64, ROOM_BODY)
	_add_rect(visual_root, "TopFace", -104, -76, 88, -44, ROOM_TOP)
	_add_rect(visual_root, "RightFace", 88, -76, 104, 52, ROOM_SIDE)
	_add_rect(visual_root, "BottomTrim", -100, 58, 100, 66, ROOM_OUTLINE)
	_add_rect(visual_root, "TopTrim", -104, -76, 104, -68, ROOM_OUTLINE)
	_add_rect(visual_root, "LeftTrim", -104, -68, -96, 64, ROOM_OUTLINE)
	_add_rect(visual_root, "RightTrim", 96, -68, 104, 58, ROOM_OUTLINE)

	if room.name.begins_with("Row2"):
		_add_rect(visual_root, "FrontDoor", -18, 8, 18, 64, DOOR_FRONT)
		_add_rect(visual_root, "FrontDoorTop", -22, 0, 22, 10, DOOR_HIGHLIGHT)
		_add_rect(visual_root, "FrontDoorKnob", 10, 34, 16, 40, Color(0.88, 0.72, 0.28, 1.0))
		_add_door_spot(room.position + Vector2(0, 32), room.position + Vector2(0, 98), Vector2(0, -50))
	elif room.name.begins_with("Row4"):
		_add_rect(visual_root, "UpperFrontDoor", -18, -74, 18, -42, Color(DOOR_FRONT.r, DOOR_FRONT.g, DOOR_FRONT.b, 0.62))
		_add_rect(visual_root, "UpperFrontDoorTop", -22, -78, 22, -70, Color(DOOR_HIGHLIGHT.r, DOOR_HIGHLIGHT.g, DOOR_HIGHLIGHT.b, 0.58))
		_add_rect(visual_root, "UpperFrontDoorKnob", -14, -58, -8, -52, Color(0.88, 0.72, 0.28, 0.72))
		if room.name == "Row4Col1":
			_add_my_dorm_marker(visual_root)
		_add_door_spot(room.position + Vector2(0, -58), room.position + Vector2(0, -112), Vector2(0, -50), room.name == "Row4Col1")

	_add_rect(visual_root, "WindowLeft", -74, -24, -46, -4, WINDOW_BLUE)
	_add_rect(visual_root, "WindowRight", 48, -24, 76, -4, WINDOW_BLUE)
	_add_rect(visual_root, "WindowLeftShine", -70, -21, -62, -8, Color(0.78, 0.92, 0.96, 1.0))
	_add_rect(visual_root, "WindowRightShine", 52, -21, 60, -8, Color(0.78, 0.92, 0.96, 1.0))


func _add_my_dorm_marker(parent: Node) -> void:
	_add_rect(parent, "MyDormGlow", -104, -84, 104, -76, Color(0.96, 0.78, 0.26, 1.0))
	_add_rect(parent, "MyDormLeftFlag", -104, -76, -92, 66, Color(0.96, 0.78, 0.26, 0.9))
	_add_rect(parent, "MyDormRightFlag", 92, -76, 104, 66, Color(0.96, 0.78, 0.26, 0.9))
	_add_rect(parent, "MyDormSignBack", -54, -118, 54, -88, Color(1.0, 0.96, 0.82, 1.0))
	_add_rect(parent, "MyDormSignBorderTop", -58, -122, 58, -118, Color(0.28, 0.18, 0.1, 1.0))
	_add_rect(parent, "MyDormSignBorderBottom", -58, -88, 58, -84, Color(0.28, 0.18, 0.1, 1.0))
	_add_rect(parent, "MyDormSignBorderLeft", -58, -118, -54, -88, Color(0.28, 0.18, 0.1, 1.0))
	_add_rect(parent, "MyDormSignBorderRight", 54, -118, 58, -88, Color(0.28, 0.18, 0.1, 1.0))

	var label := Label.new()
	label.name = "MyDormSignText"
	label.offset_left = -50.0
	label.offset_top = -116.0
	label.offset_right = 50.0
	label.offset_bottom = -90.0
	label.add_theme_color_override("font_color", Color(0.23, 0.06, 0.03, 1.0))
	label.add_theme_font_size_override("font_size", 18)
	label.text = "我的宿舍"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _add_door_spot(prompt_position: Vector2, exit_position: Vector2, prompt_offset: Vector2, is_goal := false) -> void:
	_door_spots.append({
		"prompt_position": prompt_position,
		"exit_position": exit_position,
		"prompt_offset": prompt_offset,
		"is_goal": is_goal,
	})


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
