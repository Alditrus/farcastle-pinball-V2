extends Node2D

var bumper_body: RigidBody2D
var original_position: Vector2
@export var bumper_force: float = 25.0
var reset_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready():
	bumper_body = $RigidBody2D
	original_position = bumper_body.position
	
	# Configure the bumper physics body
	bumper_body.mass = 5.0
	bumper_body.collision_layer = 1
	bumper_body.collision_mask = 1
	
	# Constrain movement and rotation
	bumper_body.lock_rotation = true
	bumper_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	
	# Set up collision detection
	var area = Area2D.new()
	area.name = "DetectionArea"
	add_child(area)
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = bumper_body.get_node("CollisionShape2D").shape.duplicate()
	# Make the detection area slightly larger than the bumper
	collision_shape.scale = Vector2(1.2, 1.2)
	area.add_child(collision_shape)
	
	# Connect the body entered signal
	area.body_entered.connect(_on_body_entered)

# Called when a body enters the detection area
func _on_body_entered(body):
	# Check if the colliding body is a ball
	if body.is_in_group("balls"):
		bump_ball(body)

# Function to launch the ball
func bump_ball(ball_node):
	if ball_node != null:
		# Calculate direction from bumper to ball
		var direction = (ball_node.global_position - global_position).normalized()
		
		# Apply force in the direction from bumper to ball
		var force = direction * bumper_force * 100
		
		# Apply impulse to the ball
		ball_node.apply_central_impulse(force)
		
		# Ensure the ball is not sleeping
		ball_node.sleeping = false