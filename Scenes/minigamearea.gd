extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the body_entered signal to our handler function
	body_entered.connect(_on_body_entered)

# Called when a physics body enters this area
func _on_body_entered(body):
	# Check if the body that entered is a ball
	if body.is_in_group("balls"):
		# Create a delay timer
		var timer = get_tree().create_timer(0.01)
		# Connect the timeout signal to scene change
		timer.timeout.connect(func():
			# Defer the scene change to avoid physics callback issues
			get_tree().call_deferred("change_scene_to_file", "res://Scenes/minigame.tscn")
		)
		
		# Optional: freeze the ball position during the delay
		if body.has_method("set_physics_process"):
			body.set_physics_process(false)
