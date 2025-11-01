extends Control

# References to UI elements
@onready var back_button = $CenterContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var leaderboard_container = $CenterContainer/VBoxContainer/LeaderboardContainer

# Placeholder leaderboard data
var placeholder_scores = [
	{"rank": 1, "name": "Wizard", "score": 15000000},
	{"rank": 2, "name": "Knight", "score": 12500000},
	{"rank": 3, "name": "Sorcerer", "score": 10000000},
	{"rank": 4, "name": "Dragon", "score": 8500000},
	{"rank": 5, "name": "Paladin", "score": 7000000},
	{"rank": 6, "name": "Rogue", "score": 5500000},
	{"rank": 7, "name": "Warrior", "score": 4000000}
]

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)

	# Populate leaderboard with placeholder scores
	populate_leaderboard()

# Show the leaderboard overlay
func show_leaderboard():
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

# Hide the leaderboard overlay
func hide_leaderboard():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	visible = false

# Back button handler
func _on_back_pressed():
	hide_leaderboard()

# Populate the leaderboard with placeholder scores
func populate_leaderboard():
	# Clear existing entries (if any)
	for child in leaderboard_container.get_children():
		child.queue_free()

	# Create a label for each score entry
	for entry in placeholder_scores:
		var entry_label = Label.new()
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Format the score with commas for readability
		var formatted_score = format_score(entry["score"])

		# Create the entry text with rank, name, and score
		entry_label.text = "%d.  %s  -  %s" % [entry["rank"], entry["name"], formatted_score]

		# Set font properties
		entry_label.add_theme_color_override("font_color", Color(0.564706, 0.192157, 0.807843, 1))

		# Create and set Almendra SC font
		var font = SystemFont.new()
		font.font_names = ["Almendra SC"]
		entry_label.add_theme_font_override("font", font)
		entry_label.add_theme_font_size_override("font_size", 40)

		# Add spacing between entries
		if entry["rank"] > 1:
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
