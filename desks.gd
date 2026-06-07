extends Node2D

const DESK_TEXTURE := preload("res://assets/desk.png")


func _ready() -> void:
	for desk in get_children():
		if not desk is Node2D:
			continue

		var old_visual := desk.get_node_or_null("ColorRect")
		if old_visual is CanvasItem:
			old_visual.visible = false

		if desk.get_node_or_null("Sprite2D") != null:
			continue

		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = DESK_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		desk.add_child(sprite)
