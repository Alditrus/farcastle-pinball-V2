extends Node2D

@onready var sprite = $Sprite2D

# Reference to track the oldest ball within the Area2D
var tracked_ball = null

func _ready():
	# Find the Exit Area2D
	var exit_area = get_node_or_null("../Exit")
	if exit_area:
		# Connect to body_entered signal
		exit_area.body_entered.connect(_on_exit_area_body_entered)
		exit_area.body_exited.connect(_on_exit_area_body_exited)

func _process(_delta):
	# If we have a tracked ball, look at it
	if is_instance_valid(tracked_ball):
		var direction = tracked_ball.global_position - global_position
		var angle = direction.angle()
		
		# Rotate the Node2D
		rotation = angle
		
		# Keep the sprite stationary by counter-rotating it
		if sprite:
			sprite.rotation = -rotation
	else:
		# If no tracked ball but there are balls in the game, find the oldest one
		var balls = get_tree().get_nodes_in_group("balls")
		if balls.size() > 0:
			# Get the overlapping balls in the exit area
			var exit_area = get_node_or_null("../Exit")
			if exit_area:
				var overlapping_bodies = exit_area.get_overlapping_bodies()
				var overlapping_balls = []
				
				for body in overlapping_bodies:
					if body is RigidBody2D and body.is_in_group("balls"):
						overlapping_balls.append(body)
				
				# If there are balls in the exit area, track the first one (oldest)
				if overlapping_balls.size() > 0:
					tracked_ball = overlapping_balls[0]

# When a ball enters the Exit area
func _on_exit_area_body_entered(body):
	if body is RigidBody2D and body.is_in_group("balls"):
		# If we don't have a tracked ball yet, use this one
		if tracked_ball == null:
			tracked_ball = body

# When a ball exits the Exit area
func _on_exit_area_body_exited(body):
	if body == tracked_ball:
		tracked_ball = null
		
		# Find a new ball to track if any exist in the area
		var exit_area = get_node_or_null("../Exit")
		if exit_area:
			var overlapping_bodies = exit_area.get_overlapping_bodies()
			var overlapping_balls = []
			
			for obj in overlapping_bodies:
				if obj is RigidBody2D and obj.is_in_group("balls"):
					overlapping_balls.append(obj)
			
			# If there are still balls in the area, track the oldest one
			if overlapping_balls.size() > 0:
				tracked_ball = overlapping_balls[0]
