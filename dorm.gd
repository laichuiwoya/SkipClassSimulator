extends Area2D

@export var next_scene_path := "res://building_downstairs.tscn"
@export var transition_scene_path := "res://level_transition.tscn"

const LevelTransition := preload("res://level_transition.gd")


func _on_body_entered(body):
	if body.name == "Player":
		LevelTransition.configure(next_scene_path, "教学楼楼下")
		get_tree().change_scene_to_file(transition_scene_path)
