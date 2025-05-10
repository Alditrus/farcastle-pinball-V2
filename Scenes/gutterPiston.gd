extends Node2D

var piston_body: RigidBody2D
var original_position: Vector2
@export var launch_force: float = 25.0  # Force to launch the ball upwards
@export var consistent_mode: bool = true  # Whether to use consistent launch mode
@export_range(0.01, 0.1, 0.01) var stabilize_time: float = 0.05  # Stabilization time before launch
var reset_timer: Timer  # Timer for handling position reset safely

# Called when the node enters the scene tree for the first time.
func _ready():
	piston_body = $RigidBody2D
	original_position = piston_body.position
	
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

# Function to launch the ball upwards
func launch_ball(ball_node):
	if ball_node != null:
		if consistent_mode:
			# CONSISTENT MODE: Reset velocity and temporarily freeze for predictable physics
			
			# Record the ball's position to restore it exactly
			var original_ball_position = ball_node.global_position
			
			# First, reset the ball's velocity to zero - use call_deferred to avoid physics errors
			ball_node.call_deferred("set_linear_velocity", Vector2.ZERO)
			ball_node.call_deferred("set_angular_velocity", 0.0)
			
			# Briefly pause physics to ensure consistent launch - use call_deferred
			ball_node.call_deferred("set_freeze_enabled", true)
			
			# Small delay before launching to stabilize physics
			await get_tree().create_timer(stabilize_time).timeout
			
			# Restore exact position (in case the engine moved it)
			ball_node.call_deferred("set_global_position", original_ball_position)
			
			# Unfreeze and apply consistent force - use call_deferred
			ball_node.call_deferred("set_freeze_enabled", false)
		
		# Apply upward force to the ball (same in both modes)
		var force = Vector2(0, -launch_force * 100)  # Apply significant upward force
		
		# Add a helper method to apply the force in the next physics frame
		call_deferred("_apply_ball_impulse", ball_node, force)
		
		# Ensure the ball is not sleeping - use call_deferred
		ball_node.call_deferred("set_sleeping", false)

# Helper method to safely apply impulse in a deferred way
func _apply_ball_impulse(ball_node, force):
	if is_instance_valid(ball_node):
		ball_node.apply_central_impulse(force)
			
# Timer callback to reset piston position
func _on_reset_timer_timeout():
	reset_piston()

# Reset piston to original position
func reset_piston():
	piston_body.freeze = true
	piston_body.linear_velocity = Vector2.ZERO
	piston_body.position = original_position