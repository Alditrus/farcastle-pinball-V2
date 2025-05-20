extends Node2D

var bumper_body: RigidBody2D
var original_position: Vector2
@export var bumper_force: float = 25.0
var active_timer: float = 0.0
var is_active: bool = false
var normal_sprite: Sprite2D
var active_sprite: Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	bumper_body = $RigidBody2D
	original_position = bumper_body.position
	
	# Get references to both sprites
	normal_sprite = $RigidBody2D/Sprite2D
	active_sprite = $RigidBody2D/Sprite2D2
	
	# Make sure active sprite is hidden initially
	active_sprite.visible = false
	
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

# Process function to handle the active sprite timer
func _process(delta):
	# If the bumper is active, count down the timer
	if is_active:
		active_timer -= delta
		
		# If the timer has expired, deactivate the bumper
		if active_timer <= 0:
			deactivate_bumper()

# Called when a body enters the detection area
func _on_body_entered(body):
	# Check if the colliding body is a ball
	if body.is_in_group("balls"):
		bump_ball(body)
		activate_bumper()
		
		# Increase score
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.increase_score("bumper")

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

# Activate the bumper (show active sprite, hide normal sprite)
func activate_bumper():
	normal_sprite.visible = false
	active_sprite.visible = true
	is_active = true
	active_timer = 0.1  # Set timer for half a second

# Deactivate the bumper (show normal sprite, hide active sprite)
func deactivate_bumper():
	normal_sprite.visible = true
	active_sprite.visible = false
	is_active = false
