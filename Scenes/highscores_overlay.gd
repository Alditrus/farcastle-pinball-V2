extends Control

# References to UI elements
@onready var back_button = $CenterContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var leaderboard_container = $CenterContainer/VBoxContainer/LeaderboardContainer

# Placeholder high scores
var placeholder_scores = [5000000, 3500000, 2800000, 2100000, 1750000]

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)

	# Populate leaderboard with player's high scores
	populate_highscores()

# Show the high scores overlay
func show_highscores():
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

# Hide the high scores overlay
func hide_highscores():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	visible = false

# Back button handler
func _on_back_pressed():
	hide_highscores()

# Load player's high scores from save file
func load_highscores() -> Array:
	var config = ConfigFile.new()
	var err = config.load("user://highscores.cfg")

	var scores = []
	if err == OK:
		# Load all scores from the config file
		var score_count = config.get_value("scores", "count", 0)
		for i in range(score_count):
			var score = config.get_value("scores", "score_" + str(i), 0)
			if score > 0:
				scores.append(score)

	# Sort scores from highest to lowest
	scores.sort()
	scores.reverse()

	return scores

# Save a new score to the player's high scores
func save_score(new_score: int):
	var scores = load_highscores()
	scores.append(new_score)

	# Sort from highest to lowest
	scores.sort()
	scores.reverse()

	# Keep only top 10 scores
	if scores.size() > 10:
		scores.resize(10)

	# Save to config file
	var config = ConfigFile.new()
	config.set_value("scores", "count", scores.size())
	for i in range(scores.size()):
		config.set_value("scores", "score_" + str(i), scores[i])

	config.save("user://highscores.cfg")

# Populate the leaderboard with player's high scores
func populate_highscores():
	# Clear existing entries (if any)
	for child in leaderboard_container.get_children():
		child.queue_free()

	# Load player's high scores
	var scores = load_highscores()

	# If no saved scores, use placeholders
	if scores.size() == 0:
		scores = placeholder_scores.duplicate()

	# Create a label for each score entry
	for i in range(scores.size()):
		var entry_label = Label.new()
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Format the score with commas for readability
		var formatted_score = format_score(scores[i])

		# Create the entry text with rank and score
		entry_label.text = "%d.  %s" % [i + 1, formatted_score]

		# Set font properties
		entry_label.add_theme_color_override("font_color", Color(0.564706, 0.192157, 0.807843, 1))

		# Create and set Almendra SC font
		var font = SystemFont.new()
		font.font_names = ["Almendra SC"]
		entry_label.add_theme_font_override("font", font)
		entry_label.add_theme_font_size_override("font_size", 40)

		# Add spacing between entries
		if i > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 10)
			leaderboard_container.add_child(spacer)

		leaderboard_container.add_child(entry_label)

# Format score with commas (e.g., 1000000 -> 1,000,000)
func format_score(score: int) -> String:
	var score_str = str(score)
	var formatted = ""
	var count = 0

	# Iterate from right to left
	for i in range(score_str.length() - 1, -1, -1):
		if count == 3:
			formatted = "," + formatted
			count = 0
		formatted = score_str[i] + formatted
		count += 1

	return formatted
