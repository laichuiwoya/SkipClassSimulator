extends Control

static var next_scene_path := "res://main.tscn"
static var level_title := "教室"
static var story_text := ""

@export var story_duration := 11.0
@export var title_duration := 1.4

@onready var message_label: Label = $MessageLabel


static func configure(next_path: String, title: String, story := "") -> void:
	next_scene_path = next_path
	level_title = title
	story_text = story


func _ready() -> void:
	if story_text.strip_edges() != "":
		message_label.text = story_text
		await get_tree().create_timer(story_duration).timeout

	message_label.text = level_title
	await get_tree().create_timer(title_duration).timeout
	get_tree().change_scene_to_file(next_scene_path)
