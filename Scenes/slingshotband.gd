extends Node2D

var piston_body: RigidBody2D
var original_position: Vector2
@export var launch_force_vertical: float = 25.0
@export var launch_force_horizontal: float = 25.0   # Force to launch the ball upwards
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
	
	print("Slingshot band initialized at position: ", global_position)

# Called when a body enters the detection area
func _on_body_entered(body):
	# Check if the colliding body is a ball
	if body.is_in_group("balls"):
		print("Ball detected, launching!")
		launch_ball(body)
		
		# Show the active sprite
		if band_active_sprite:
			band_active_sprite.visible = true
			flash_timer.start()
			print("Activated band sprite")

# Function to launch the ball
func launch_ball(ball_node):
	if ball_node != null:
		# Apply force to the ball
		var force = Vector2(launch_force_horizontal * 100, -launch_force_vertical * 100)
		
		# Apply impulse to the ball
		ball_node.apply_central_impulse(force)
		
		# Ensure the ball is not sleeping
		ball_node.sleeping = false

# Timer callback to hide active sprite
func _on_flash_timer_timeout():
	if band_active_sprite:
		band_active_sprite.visible = false
		print("Deactivated band sprite")

# Timer callback to reset piston position
func _on_reset_timer_timeout():
	reset_piston()

# Reset piston to original position
func reset_piston():
	piston_body.freeze = true
	piston_body.linear_velocity = Vector2.ZERO
	piston_body.position = original_position
	
	print("Piston reset to original position")
