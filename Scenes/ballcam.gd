extends Camera2D

var ball_node
var game_boundary
var is_following = false  # Start with not following
var initial_x_position
var last_valid_y_position = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	# Get the ball reference
	ball_node = get_parent().get_node("Ball")
	
	# Store the initial X position and Y position
	initial_x_position = position.x
	last_valid_y_position = position.y
	
	# Find the game boundary (Area2D)
	game_boundary = get_parent().get_node("gameboundary")
	
	# Connect to the ball entering and exiting the boundary
	if game_boundary:
		game_boundary.body_entered.connect(_on_game_boundary_body_entered)
		game_boundary.body_exited.connect(_on_game_boundary_body_exited)
	
	# Use physics process to match physics updates
	set_physics_process(true)
	set_process(false)
	
	# Completely disable the RemoteTransform2D by clearing its remote path
	var remote_transform = ball_node.get_node("RemoteTransform2D")
	if remote_transform:
		remote_transform.remote_path = ""

# Use physics process instead of normal process to sync with physics body
func _physics_process(_delta):
	if is_following and ball_node and is_instance_valid(ball_node):
		# Save the last valid Y position
		last_valid_y_position = ball_node.position.y
		
		# Direct following without smoothing, but only vertical movement
		position.y = last_valid_y_position
		position.x = initial_x_position

# Called when a body enters the game boundary
func _on_game_boundary_body_entered(body):
	if body == ball_node:
		# Start following the ball
		is_following = true

# Called when a body exits the game boundary
func _on_game_boundary_body_exited(body):
	if body == ball_node:
		# Stop following the ball
		is_following = false
