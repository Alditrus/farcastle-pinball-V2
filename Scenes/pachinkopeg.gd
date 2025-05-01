extends Node2D

var bumper_body: StaticBody2D
var original_position: Vector2
var is_active: bool = false
var active_sprite: Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	bumper_body = $peg
	original_position = bumper_body.position
	
	# Get references to both sprites
	active_sprite = $peg/eyepupil
	
	# Make sure active sprite is hidden initially
	active_sprite.visible = false
	
	# Set up collision detection
	var area = Area2D.new()
	area.name = "DetectionArea"
	add_child(area)
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = bumper_body.get_node("CollisionShape2D").shape.duplicate()
	# Make the detection area slightly larger than the bumper
	collision_shape.scale = Vector2(1.2, 1.2)
	area.add_child(collision_shape)
	
	# Connect the body entered and exited signals
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

# Called when a body enters the detection area
func _on_body_entered(body):
	# Check if the colliding body is a ball
	if body.is_in_group("balls"):
		activate_bumper()

# Called when a body exits the detection area
func _on_body_exited(body):
	# Check if the exiting body is a ball
	if body.is_in_group("balls"):
		deactivate_bumper()

# Activate the bumper (show active sprite, hide normal sprite)
func activate_bumper():
	active_sprite.visible = true
	is_active = true

# Deactivate the bumper (show normal sprite, hide active sprite)
func deactivate_bumper():
	active_sprite.visible = false
	is_active = false
