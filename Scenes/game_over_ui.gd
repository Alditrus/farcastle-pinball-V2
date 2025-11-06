extends Control

# References to UI elements
@onready var game_over_label = $CenterContainer/VBoxContainer/GameOverLabel
@onready var final_score_label = $CenterContainer/VBoxContainer/HBoxContainer/FinalScoreLabel
@onready var high_score_title = $CenterContainer/VBoxContainer/HighScoreContainer/HighScoreTitle
@onready var score_labels = [
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score1,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score2,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score3,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score4,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score5,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score6
]
@onready var play_again_button = $CenterContainer/VBoxContainer/ButtonsContainer/PlayAgainButton
@onready var exit_button = $CenterContainer/VBoxContainer/ButtonsContainer/ExitButton

# High scores array (will be loaded from file later)
var high_scores: Array[int] = [0, 0, 0, 0, 0, 0]



func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide the UI initially
	visible = false

	# Connect button signals (functionality will be added later)
	play_again_button.pressed.connect(_on_play_again_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

# Show the game over UI
func show_game_over(final_score: int = 0):
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	update_final_score_display(final_score)
	update_high_scores_display()

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue even when paused
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.0)

	# Pause the game
	get_tree().paused = true

# Hide the game over UI
func hide_game_over():
	visible = false
	
	# Unpause the game
	get_tree().paused = false

# Update the final score display
func update_final_score_display(final_score: int):
	if final_score_label:
		final_score_label.text = format_score_with_commas(final_score)

# Format score with commas for every thousandth digit (same as score_label.gd)
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

# Update the high scores display
func update_high_scores_display():
	for i in range(score_labels.size()):
		if i < high_scores.size():
			score_labels[i].text = format_score_with_commas(high_scores[i])
		else:
			score_labels[i].text = "0"

# Check if current score is a high score and update the list
func check_and_update_high_score(current_score: int) -> bool:
	var is_high_score = false
	
	# Check if current score should be in high scores
	for i in range(high_scores.size()):
		if current_score > high_scores[i]:
			# Insert the score at this position
			high_scores.insert(i, current_score)
			# Remove the last element to keep only top 5
			if high_scores.size() > 5:
				high_scores.resize(5)
			is_high_score = true
			break
	
	return is_high_score

# Button signal handlers
func _on_play_again_pressed():
	# Unpause the game before reloading
	get_tree().paused = false
	# Restart the music
	AudioCollection.select_random_track()
	AudioCollection.play_current_track()
	# Reload the current scene to restart the game
	get_tree().reload_current_scene()

func _on_exit_pressed():
	# Unpause the game before changing scenes
	get_tree().paused = false
	# Return to main menu
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

# Load high scores from file (to be implemented later)
func load_high_scores():
	# TODO: Implement loading from file
	pass

# Save high scores to file (to be implemented later)
func save_high_scores():
	# TODO: Implement saving to file
	pass
