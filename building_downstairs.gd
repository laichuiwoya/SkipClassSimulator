extends Node2D

@export var max_counselor_found_count := 3
@export var return_to_spawn_delay := 0.6
@export var classroom_scene_path := "res://main.tscn"
@export var dorm_building_scene_path := "res://dorm_building.tscn"
@export var transition_scene_path := "res://level_transition.tscn"

const LevelTransition := preload("res://level_transition.gd")

@onready var player: Node = $Player
@onready var counselor_game_over_popup: CanvasItem = $CounselorGameOverPopup

var _counselor_found_count := 0
var _is_game_over := false


func _ready() -> void:
	counselor_game_over_popup.visible = false


func _on_dorm_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		LevelTransition.configure(dorm_building_scene_path, "宿舍楼")
		get_tree().change_scene_to_file(transition_scene_path)


func handle_counselor_found_player(finding_counselor: Node = null) -> void:
	if _is_game_over:
		return
	if player != null and player.has_method("is_forced_returning") and player.call("is_forced_returning") == true:
		return

	_counselor_found_count += 1
	var return_delay := return_to_spawn_delay
	if finding_counselor != null and finding_counselor.has_method("show_caught_bubble"):
		finding_counselor.call("show_caught_bubble")
		return_delay = float(finding_counselor.get("caught_pause_time"))

	if _counselor_found_count >= max_counselor_found_count:
		_trigger_counselor_game_over()
		return

	if player != null and player.has_method("force_return_to_spawn"):
		player.set("forced_return_delay", return_delay)
		player.call("force_return_to_spawn")


func _trigger_counselor_game_over() -> void:
	_is_game_over = true
	if player != null and player.has_method("lock_control"):
		player.call("lock_control")
	counselor_game_over_popup.visible = true


func _on_restart_from_classroom_button_pressed() -> void:
	get_tree().change_scene_to_file(classroom_scene_path)


func _on_restart_current_level_button_pressed() -> void:
	get_tree().reload_current_scene()
