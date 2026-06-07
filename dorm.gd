extends Area2D

@export var next_scene_path := "res://building_downstairs.tscn"


func _on_body_entered(body):
	if body.name == "Player":
		get_tree().change_scene_to_file(next_scene_path)
