extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the body_entered signal to our handler function
	body_entered.connect(_on_body_entered)

# Called when a physics body enters this area
func _on_body_entered(body):
	# Check if the body that entered is a ball
	if body.is_in_group("balls"):
		# Defer the scene change to avoid physics callback issues
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/minigame.tscn")