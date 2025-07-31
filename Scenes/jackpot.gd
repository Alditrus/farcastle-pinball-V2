extends StaticBody2D

# Movement parameters
var start_x = 200  # Left position bound
var end_x = 400    # Right position bound
@export var pot_range = 200
@export var move_speed = 100  # Pixels per second
var direction = 1   # 1 for right, -1 for left
var initial_position
var minigame_complete_sound = preload("res://Assets/sounds/minigame_complete.wav")

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
				
				# Unfreeze all main table balls and wait for the process to complete
				await unfreeze_main_table_balls()
				
				# Add a short delay to let the ball be ejected before starting jaw closing animation
				await get_tree().create_timer(0.5).timeout
				
				# Reset the minigame entrance
				var minigame_entrance = get_node_or_null("/root/Table/minigameentrance")
				if minigame_entrance and minigame_entrance.has_method("reset_entrance"):
					minigame_entrance.reset_entrance()
					AudioCollection.play_sfx(minigame_complete_sound)

# Unfreeze all balls in the main table to resume their movement
# Returns when the process is complete (allows awaiting)
func unfreeze_main_table_balls():
	# Find all balls in the "balls" group
	var balls = get_tree().get_nodes_in_group("balls")
	var captured_ball_found = false
	
	for ball in balls:
		# Skip any minigameball - only unfreeze main table balls
		if ball.name != "minigameball":
			# Check if this was the captured ball
			var was_captured = ball.has_meta("original_position")
			if was_captured:
				captured_ball_found = true
			
			# Restore the ball's appearance and get the callback
			var MinigameArea = load("res://Scenes/minigamearea.gd")
			var animation_complete = MinigameArea.restore_ball_appearance(ball)
			
			# For the captured ball, the callback will handle unfreezing
			if was_captured:
				if animation_complete is Callable:
					await animation_complete.call()
				continue
			
			# For non-captured balls, handle unfreezing here
			if animation_complete is Callable:
				await animation_complete.call()
			
			# Unfreeze non-captured balls
			ball.freeze = false
			
			# Restore stored velocities for non-captured balls
			if ball.has_meta("stored_linear_velocity"):
				ball.linear_velocity = ball.get_meta("stored_linear_velocity")
				ball.angular_velocity = ball.get_meta("stored_angular_velocity")
				
				# Clear the stored values
				ball.remove_meta("stored_linear_velocity")
				ball.remove_meta("stored_angular_velocity")
	
	# If we found a captured ball, add a little extra delay to make sure
	# the ball has time to launch properly
	if captured_ball_found:
		await get_tree().create_timer(0.2).timeout
