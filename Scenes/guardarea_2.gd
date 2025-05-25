extends Area2D

@export var guard_path: NodePath = "../Guard"
var guard: Node2D

func _ready():
	if guard_path:
		guard = get_node(guard_path)
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("balls"):
		if guard:
			guard.get_node("StaticBody2D").set_collision_layer_value(1, true)
			guard.get_node("StaticBody2D").set_collision_layer_value(2, true)
			guard.get_node("StaticBody2D").set_collision_mask_value(1, true)
			guard.get_node("StaticBody2D").set_collision_mask_value(2, true)
			guard.get_node("StaticBody2D/Sprite2D").visible = true
