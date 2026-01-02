extends Control

# References to UI elements
@onready var back_button = $CenterContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var leaderboard_container = $CenterContainer/VBoxContainer/LeaderboardContainer

# User's high scores data from API
var user_scores_data: Array = []

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)

	# Fetch and populate high scores from API
	fetch_user_scores()

func _get_javascript_singleton():
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

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

# Fetch user's high scores from API
func fetch_user_scores():
	var js = _get_javascript_singleton()
	if not js:
		print("❌ No JavaScript singleton available for user scores fetch")
		populate_highscores()
		return

	print("🔄 Fetching user scores from API...")

	# Call the JavaScript function to get user scores
	js.eval("""
		(async () => {
			try {
				if (typeof window.getUserScores === 'function') {
					const result = await window.getUserScores(10);
					window.lastUserScoresResult = JSON.stringify(result);
				} else {
					window.lastUserScoresResult = JSON.stringify({ scores: [] });
				}
			} catch (error) {
				console.error('User scores fetch error:', error);
				window.lastUserScoresResult = JSON.stringify({ scores: [] });
			}
		})()
	""", true)

	# Wait for result to be stored
	await get_tree().create_timer(1.0).timeout

	var result_json = js.eval("(window.lastUserScoresResult || JSON.stringify({ scores: [] }))", true)

	if result_json is String and result_json != "":
		var json = JSON.new()
		var parse_result = json.parse(result_json)

		if parse_result == OK:
			var data = json.data
			if data and data.has("scores"):
				user_scores_data = data.scores
				print("✅ User scores fetched: ", user_scores_data.size(), " entries")
			else:
				print("⚠️ No user scores in response")
		else:
			print("⚠️ Failed to parse user scores JSON")
	else:
		print("⚠️ No user scores result received")

	populate_highscores()

# Populate the leaderboard with player's high scores
func populate_highscores():
	# Clear existing entries (if any)
	for child in leaderboard_container.get_children():
		child.queue_free()

	# Extract score values from API data
	var scores = []
	for score_entry in user_scores_data:
		if score_entry.has("score"):
			scores.append(score_entry.score)

	# Show message if no scores yet
	if scores.size() == 0:
		var no_scores_label = Label.new()
		no_scores_label.text = "No scores yet!\nPlay a game to see your high scores"
		no_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_scores_label.add_theme_color_override("font_color", Color(0.564706, 0.192157, 0.807843, 1))
		var font = load("res://Assets/fonts/AlmendraSC-Regular.ttf")
		no_scores_label.add_theme_font_override("font", font)
		no_scores_label.add_theme_font_size_override("font_size", 30)
		leaderboard_container.add_child(no_scores_label)
		return

	# Show top 6 scores only
	var display_count = min(scores.size(), 6)

	# Create a label for each score entry
	for i in range(display_count):
		var entry_label = Label.new()
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Format the score with commas for readability
		var formatted_score = format_score(scores[i])

		# Create the entry text with rank and score
		entry_label.text = "%d.  %s" % [i + 1, formatted_score]

		# Set font properties
		entry_label.add_theme_color_override("font_color", Color(0.564706, 0.192157, 0.807843, 1))

		# Create and set Almendra SC font
		var font = load("res://Assets/fonts/AlmendraSC-Regular.ttf")
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
