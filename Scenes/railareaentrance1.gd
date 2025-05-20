extends Area2D

# Reference to the rail node
var rail_node: Node2D

# Rail velocity settings
var rail_speed = 1500.0  # Speed of the ball in the rail
var rail_angle_degrees = 245.0  # Northwest angle (measured clockwise from right/east)

# Called when the node enters the scene tree for the first time.
func _ready():
	# Find the rail node in the scene
	rail_node = get_node_or_null("../rail")
	
	if not rail_node:
		push_error("Could not find rail node")
	
	body_entered.connect(_on_body_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_body_entered(body):
	if body.is_in_group("balls") and body is RigidBody2D:
		# Change ball collision properties
		body.collision_layer = 4
		body.collision_mask = 2
		
		# Force the ball to a specific velocity
		set_ball_rail_velocity(body)
		
		# Make rail fully opaque by setting alpha to 255 (full opacity)
		if rail_node:
			var sprite = rail_node.get_node_or_null("Sprite2D")
			if sprite:
				# Keep the same RGB values but change alpha to 1.0 (255)
				var current_color = sprite.modulate
				sprite.modulate = Color(current_color.r, current_color.g, current_color.b, 1.0)

# Set the ball's velocity based on angle
func set_ball_rail_velocity(ball: RigidBody2D):
	# Convert angle to radians
	var angle_rad = deg_to_rad(rail_angle_degrees)
	
	# Calculate direction vector from angle (cos for x, sin for y)
	var direction = Vector2(cos(angle_rad), sin(angle_rad))
	
	# Reset velocity completely and set it to our calculated direction and speed
	ball.linear_velocity = direction * rail_speed
	
	# Ensure the ball is not sleeping
	ball.sleeping = false
