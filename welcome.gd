extends Control

@export var start_scene_path := "res://main.tscn"
@export var transition_scene_path := "res://level_transition.tscn"

const LevelTransition := preload("res://level_transition.gd")


func _on_start_button_pressed() -> void:
	var intro_text := "你是一个普通大学生。\n\n昨晚本来只想刷一会儿手机，结果作业、消息和短视频一件接一件，把睡觉时间一路拖到了深夜。\n\n闹钟响起时，天刚亮，早八已经在路上等你。你站在教室里，眼皮打架，脑子里只剩一个念头：回宿舍补觉。\n\n这不是值得模仿的选择，只是一场像素世界里的小小逃课模拟。"
	LevelTransition.configure(start_scene_path, "教室", intro_text)
	get_tree().change_scene_to_file(transition_scene_path)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
