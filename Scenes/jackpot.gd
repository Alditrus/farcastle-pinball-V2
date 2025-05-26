extends StaticBody2D

# Movement parameters
var start_x = 200  # Left position bound
var end_x = 400    # Right position bound
@export var pot_range = 200
@export var move_speed = 100  # Pixels per second
var direction = 1   # 1 for right, -1 for left
var initial_position

# Ball detection
var jackpot_area: Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Store initial position
	initial_position = position
	
	# Set start and end positions relative to the initial position
	start_x = initial_position.x - pot_range
	end_x = initial_position.x + pot_range
	
	# Get reference to the jackpot area
	jackpot_area = $jackpot_area
	
	# Connect signal for ball collision
	if jackpot_area:
		jackpot_area.body_entered.connect(_on_jackpot_area_body_entered)

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

# Function called when a body enters the jackpot area
func _on_jackpot_area_body_entered(body):
	# Check if the body is the minigameball
	if body.name == "minigameball" or body.name == "ball":
		# Ball has entered the jackpot area
		on_jackpot_hit(body)

# Function to handle jackpot hit - customize this for your game logic
func on_jackpot_hit(ball):
	# Increase score
	var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
	if score_label:
		score_label.increase_score("jackpot")
		
		# If this is the minigameball, deactivate minigame and return to main game after a short delay
		if ball.name == "minigameball":
			await get_tree().create_timer(1.0).timeout  # Longer delay for jackpot celebration
			
			# Find the minigame window and deactivate it
			var minigame_window = get_node_or_null("/root/Table/minigamewindow")
			if minigame_window and minigame_window.has_method("deactivate"):
				minigame_window.deactivate()
				print("Jackpot! Minigame closed, returning to main table")
				
				# Unfreeze all main table balls
				unfreeze_main_table_balls()
				
				# Reset the minigame entrance
				var minigame_entrance = get_node_or_null("/root/Table/minigameentrance")
				if minigame_entrance and minigame_entrance.has_method("reset_entrance"):
					minigame_entrance.reset_entrance()

# Unfreeze all balls in the main table to resume their movement
func unfreeze_main_table_balls():
	# Find all balls in the "balls" group
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		# Skip any minigameball - only unfreeze main table balls
		if ball.name != "minigameball":
			# Unfreeze the ball
			ball.freeze = false
			
			# Restore velocities if they were stored
			if ball.has_meta("stored_linear_velocity"):
				ball.linear_velocity = ball.get_meta("stored_linear_velocity")
				ball.angular_velocity = ball.get_meta("stored_angular_velocity")
				
				# Clear the stored values
				ball.remove_meta("stored_linear_velocity")
				ball.remove_meta("stored_angular_velocity")
