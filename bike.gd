extends Area2D

@export var ride_speed := 200.0
@export var prompt_bubble: CanvasItem

var _nearby_player: Node = null
var _is_used := false


func _ready() -> void:
	if prompt_bubble == null:
		var found_prompt: Node = get_node_or_null("PromptBubble")
		if found_prompt is CanvasItem:
			prompt_bubble = found_prompt
	if prompt_bubble != null:
		prompt_bubble.visible = false


func _process(_delta: float) -> void:
	if _is_used or _nearby_player == null:
		return

	if Input.is_action_just_pressed("interact"):
		_nearby_player.set("speed", ride_speed)
		_is_used = true
		visible = false
		monitoring = false
		if prompt_bubble != null:
			prompt_bubble.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_nearby_player = body
		if prompt_bubble != null:
			prompt_bubble.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		if prompt_bubble != null:
			prompt_bubble.visible = false
