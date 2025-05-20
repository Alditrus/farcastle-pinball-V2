extends Node2D

var piston_body: RigidBody2D
var original_position: Vector2

# Launch configuration with angle and speed
@export var launch_speed: float = 1000.0  # Speed for the ball when launched
@export var launch_angle_degrees: float = 45.0  # Angle in degrees (measured clockwise from right/east)
												 # For example: 45° = up-right, 135° = up-left

var reset_timer: Timer  # Timer for handling position reset safely
var flash_timer: Timer  # Timer for handling active sprite visibility
var band_active_sprite: Sprite2D  # Reference to the active sprite on the band

# Called when the node enters the scene tree for the first time.
func _ready():
	piston_body = $RigidBody2D
	original_position = piston_body.position
	
	# Get reference to the active sprite
	band_active_sprite = $RigidBody2D/active
	
	# Make sure the active sprite is hidden initially
	if band_active_sprite:
		band_active_sprite.visible = false
	
	# Configure the piston physics body
	piston_body.mass = 5.0
	piston_body.collision_layer = 1
	piston_body.collision_mask = 1
	
	# Constrain movement and rotation
	piston_body.lock_rotation = true
	piston_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	
	# Create a timer for reset sequence
	reset_timer = Timer.new()
	reset_timer.one_shot = true
	add_child(reset_timer)
	reset_timer.timeout.connect(_on_reset_timer_timeout)
	
	# Create a timer for active sprite visibility
	flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.1  # Show active sprite for 0.1 seconds
	add_child(flash_timer)
	flash_timer.timeout.connect(_on_flash_timer_timeout)
	
	# Set up collision detection
	var area = Area2D.new()
	area.name = "DetectionArea"
	add_child(area)
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = piston_body.get_node("CollisionShape2D").shape.duplicate()
	# Make the detection area slightly larger than the piston
	collision_shape.scale = Vector2(1.2, 1.2)
	area.add_child(collision_shape)
	
	# Connect the body entered signal
	area.body_entered.connect(_on_body_entered)

# Called when a body enters the detection area
func _on_body_entered(body):
	# Check if the colliding body is a ball
	if body.is_in_group("balls"):
		launch_ball(body)

		# Increase score
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.increase_score("slingshot")
		
		# Show the active sprite
		if band_active_sprite:
			band_active_sprite.visible = true
			flash_timer.start()

# Function to launch the ball using angle-based velocity
func launch_ball(ball_node):
	if ball_node != null and ball_node is RigidBody2D:
		# Convert angle to radians
		var angle_rad = deg_to_rad(launch_angle_degrees)
		
		# Calculate direction vector from angle (cos for x, sin for y)
		var direction = Vector2(cos(angle_rad), sin(angle_rad))
		
		# Calculate the impulse to apply
		var impulse = direction * launch_speed
		
		# Apply impulse to the ball
		ball_node.apply_central_impulse(impulse)
		
		# Ensure the ball is not sleeping
		ball_node.sleeping = false

# Timer callback to hide active sprite
func _on_flash_timer_timeout():
	if band_active_sprite:
		band_active_sprite.visible = false

# Timer callback to reset piston position
func _on_reset_timer_timeout():
	reset_piston()

# Reset piston to original position
func reset_piston():
	piston_body.freeze = true
	piston_body.linear_velocity = Vector2.ZERO
	piston_body.position = original_position
