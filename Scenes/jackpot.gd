extends StaticBody2D

# Movement parameters
var start_x = 200  # Left position bound
var end_x = 400    # Right position bound
@export var pot_range = 200
@export var move_speed = 100  # Pixels per second
var direction = 1   # 1 for right, -1 for left
var initial_position

# Called when the node enters the scene tree for the first time.
func _ready():
	# Store initial position
	initial_position = position
	
	# Set start and end positions relative to the initial position
	start_x = initial_position.x - pot_range
	end_x = initial_position.x + pot_range

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Move in the current direction
	position.x += direction * move_speed * delta
	
	# Check if reached the right bound
	if position.x >= end_x:
		position.x = end_x  # Prevent overshooting
		direction = -1      # Change direction to left
	
	# Check if reached the left bound
	elif position.x <= start_x:
		position.x = start_x  # Prevent overshooting
		direction = 1         # Change direction to right
