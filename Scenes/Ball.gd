extends RigidBody2D

@onready var ball_sprite = $BallSprite

# Keep track of whether we're still visible in the scene
var is_active = true

func _ready():
	# Add the ball to a group for easier tracking
	add_to_group("balls")
	
	# Set up better physics properties for pinball behavior
	mass = 1.0  # Normal mass for a pinball
	gravity_scale = 1.0  # Normal gravity
	
	# These are the properties causing errors - use proper Godot 4 names
	# For bounce/friction in RigidBody2D - need to create a PhysicsMaterial
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.3  # Lower bounciness for better control
	physics_material.friction = 0.0  # No friction for smoother rolling
	physics_material_override = physics_material
	
	# Collision detection settings
	# In Godot 4, continuous_cd is an enum
	# Use CCD_MODE_CAST_RAY for default continuous collision detection
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	sleeping = false  # Never sleep (always active)
	
	# Make sure we have the correct collision masks
	collision_layer = 1
	collision_mask = 1

func _physics_process(_delta):
	# The BallSprite node is a child of the RigidBody2D, but we don't want it to rotate
	# Reset the rotation of the sprite to keep it upright
	if is_active and ball_sprite:
		ball_sprite.rotation = -rotation  # Counter-rotate to cancel out the parent's rotation