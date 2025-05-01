extends StaticBody2D

@export var rotation_speed = 1.0  # Radians per second, positive value for clockwise rotation

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Rotate clockwise by adding positive value to rotation
	rotate(rotation_speed * delta)
