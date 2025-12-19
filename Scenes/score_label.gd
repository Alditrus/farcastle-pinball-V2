extends Label

var score = 0

# Reference to ball count label
@onready var ball_count_label = get_node("../BallCountLabel")
# Reference to game over UI
@onready var game_over_ui = get_node("../../UILayer/GameOverUI")

# Spinner variables
var spinner_active = false
var spinner_timer = 0.0
var spinner_timer_at_exit = 0.0
var spinner_ball_exited = false
var spinner_initial_speed = 1.0
var spinner_current_speed = 1.0
var ball_count = 3.0
const SPINNER_SLOWDOWN_RATE = 1.0

# Bumper level system
var current_bumper_level = 1
var bumper_level_points = {
	1: 2000,   # Default
	2: 3500,
	3: 5000,
	4: 6500,
	5: 8000,
	6: 10000
}

# Game over sound effect
var game_over_sound = preload("res://Assets/sounds/game_over.ogg")

# Called when the node enters the scene tree for the first time
func _ready():
	update_score_text()
	update_ball_count_text()

# Spinner accumulation variables
var time_since_last_point = 0.0
var point_interval = 0.1  # Base interval between points

# Called every frame
func _process(delta):
	# Handle spinner points decay
	if spinner_active:
		spinner_timer += delta
		time_since_last_point += delta
		
		if spinner_ball_exited:
			# Calculate decay factor using exponential decay
			var decay_factor = exp(-SPINNER_SLOWDOWN_RATE * (spinner_timer - spinner_timer_at_exit))
			spinner_current_speed = spinner_initial_speed * decay_factor
			
			# Calculate dynamic interval based on current speed
			# As speed decreases, interval between points increases
			var dynamic_interval = point_interval / spinner_current_speed
			
			# Add spinner points based on current speed and time interval
			if spinner_current_speed > 0.05 and time_since_last_point >= dynamic_interval:
				score += 200
				update_score_text()
				time_since_last_point = 0.0  # Reset timer after adding points
			elif spinner_current_speed <= 0.05:
				# Stop awarding points when spinner slows down enough
				spinner_active = false
				spinner_timer = 0.0
				spinner_ball_exited = false
				time_since_last_point = 0.0
		else:
			# While ball is still in contact, add points at regular intervals based on speed
			var contact_interval = point_interval / spinner_current_speed
			if time_since_last_point >= contact_interval:
				score += 200
				update_score_text()
				time_since_last_point = 0.0  # Reset timer after adding points
		
			# If ball hasn't exited but time limit reached
			if spinner_timer >= 5.0:
				spinner_active = false
				spinner_timer = 0.0
				spinner_ball_exited = false
				time_since_last_point = 0.0

# Function to increase score based on element type
func increase_score(element_type: String):
	var points = 0
	var event_data = {}
	
	# Determine points based on element type
	match element_type:
		"bumper":
			points = bumper_level_points[current_bumper_level]
			event_data = {"level": current_bumper_level}
		"alcove_bumper":
			points = 5000
		"slingshot":
			points = 1000
		"target":
			points = 10000
		"target_set_complete":
			points = 50000
		"candle":
			points = 7000
		"candle_set_complete":
			points = 80000
			upgrade_bumper_level()
		"rail_exit":
			points = 200
		"rollover":
			points = 6000
		"spinner":
			start_spinner_points(1.0)
			return
		"sinkhole":
			points = 70000
		"jackpot":
			points = 10000000
		"minigame_win":
			points = 500
		_:
			points = 10
	
	# Add points to score (local display)
	score += points
	
	# Record event for backend
	GameEventTracker.record_event(element_type, event_data)
	
	# Update the displayed score
	update_score_text()

# Function to upgrade bumper level when candle set is completed
func upgrade_bumper_level():
	if current_bumper_level < 6:  # Max level is 6
		current_bumper_level += 1
		update_bumper_sprites()

# Update the bumper sprites to match the current level
func update_bumper_sprites():
	# Find all bumpers in the scene
	var bumpers = get_tree().get_nodes_in_group("bumpers")
	for bumper in bumpers:
		if bumper.has_method("set_level"):
			bumper.set_level(current_bumper_level)

# Function to start spinner points calculation
func start_spinner_points(speed_scale):
	spinner_active = true
	spinner_ball_exited = false
	spinner_timer = 0.0
	spinner_initial_speed = speed_scale
	spinner_current_speed = speed_scale
	time_since_last_point = 0.0  # Reset point timer
	
	# Add initial points
	score += 200
	update_score_text()

# Function to mark spinner ball has exited
func spinner_ball_exit():
	if spinner_active:
		spinner_ball_exited = true
		spinner_timer_at_exit = spinner_timer

# Update the displayed score text
func update_score_text():
	text = format_score_with_commas(score)

# Format score with commas for every thousandth digit
func format_score_with_commas(number: int) -> String:
	var score_string = str(number)
	var formatted_string = ""
	var digit_count = 0
	
	# Loop through digits from right to left
	for i in range(score_string.length() - 1, -1, -1):
		digit_count += 1
		formatted_string = score_string[i] + formatted_string
		
		# Add a comma after every third digit, except for the last group
		if digit_count % 3 == 0 and i > 0:
			formatted_string = "," + formatted_string
	
	return formatted_string

# Function to apply a multiplier to the current score
func apply_multiplier(multiplier: int):
	var _previous_score = score
	score *= multiplier
	
	# Update the displayed score
	update_score_text()

# Function to reset score
func reset_score():
	score = 0
	current_bumper_level = 1  # Reset bumper level as well
	update_score_text()
	update_bumper_sprites()  # Reset bumper sprites

# Get current bumper level (for other scripts to reference)
func get_bumper_level():
	return current_bumper_level

# Update the ball count display text
func update_ball_count_text():
	if ball_count_label:
		# Don't show negative ball count, show 0 instead
		var display_count = max(0, int(ball_count))
		ball_count_label.text = str(display_count) + " Balls"

# Check if game over condition is met and trigger game over
func check_game_over():
	if ball_count <= -1:
		trigger_game_over()

# Trigger game over - freeze game and show game over UI
func trigger_game_over():

	# Stop music and play game over sfx
	AudioCollection.stop_music()
	AudioCollection.play_sfx(game_over_sound)

	# Hide the plunger so it doesn't appear on top of game over UI
	var plunger = get_node_or_null("../../plunger")
	if plunger:
		plunger.visible = false
	
	# Check if current score is a high score and update
	if game_over_ui and game_over_ui.has_method("check_and_update_high_score"):
		game_over_ui.check_and_update_high_score(score)

	# Show the game over UI with the final score (this will also pause the game)
	if game_over_ui and game_over_ui.has_method("show_game_over"):
		game_over_ui.show_game_over(score)
