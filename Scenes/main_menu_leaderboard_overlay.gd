extends Control

# References to UI elements
@onready var back_arrow = $BackButton
@onready var leaderboard_parent = $CenterContainer
@onready var leaderboard_container = $CenterContainer/LeaderboardContainer
@onready var highscores_container = $CenterContainer/HighScoresContainer
@onready var global_button = $CenterContainer3/HBoxContainer/Global
@onready var high_scores_button = $"CenterContainer3/HBoxContainer/High Scores"
var scroll_container: ScrollContainer = null
var highscores_scroll_container: ScrollContainer = null
var active_button: Button = null  # Track currently active button
var showing_global: bool = true  # Track which leaderboard is shown

# Placeholder leaderboard data
var placeholder_scores = [
	{"rank": 1, "name": "Wizard", "score": 15000000},
	{"rank": 2, "name": "Knight", "score": 12500000},
	{"rank": 3, "name": "Sorcerer", "score": 10000000},
	{"rank": 4, "name": "Dragon", "score": 8500000},
	{"rank": 5, "name": "Paladin", "score": 7000000},
	{"rank": 6, "name": "Rogue", "score": 5500000},
	{"rank": 7, "name": "Warrior", "score": 4000000},
	{"rank": 8, "name": "Mark", "score": 3000000},
	{"rank": 9, "name": "Bob", "score": 2000000},
]

# Placeholder high scores (individual player scores)
var placeholder_highscores = [5000000, 3500000, 2800000, 2100000, 1750000, 1200000, 1100000, 1000000, 900000, 800000]

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Enable input processing
	set_process_input(true)

	# Style the buttons
	style_buttons()

	# Connect button signals
	if global_button:
		global_button.pressed.connect(_on_global_pressed)
	if high_scores_button:
		high_scores_button.pressed.connect(_on_high_scores_pressed)

	# Set initial active button (global by default)
	set_active_button(global_button)

	# Populate both leaderboards with placeholder scores
	populate_leaderboard()
	populate_highscores()

	# Hide high scores container initially (show global by default)
	if highscores_container:
		highscores_container.visible = false

# Style the global and high score buttons
func style_buttons():
	# Initial setup - both buttons start inactive
	if global_button:
		set_button_inactive(global_button)
	if high_scores_button:
		set_button_inactive(high_scores_button)

# Set a button to inactive style
func set_button_inactive(button: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.305882, 0, 0.345098, 1)  # 4E0058
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)

# Set a button to active style
func set_button_active(button: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.564706, 0.286275, 0.807843, 1)  # 9049CE
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)

# Set which button is currently active
func set_active_button(button: Button):
	# Deactivate previously active button
	if active_button and active_button != button:
		set_button_inactive(active_button)

	# Activate the new button
	set_button_active(button)
	active_button = button

# Global button handler
func _on_global_pressed():
	set_active_button(global_button)
	showing_global = true
	# Show global leaderboard, hide high scores
	if leaderboard_container:
		leaderboard_container.visible = true
	if highscores_container:
		highscores_container.visible = false

# High Scores button handler
func _on_high_scores_pressed():
	set_active_button(high_scores_button)
	showing_global = false
	# Show high scores, hide global leaderboard
	if leaderboard_container:
		leaderboard_container.visible = false
	if highscores_container:
		highscores_container.visible = true

# Handle input events
func _input(event):
	if not visible:
		return

	# Handle mouse wheel scrolling
	if event is InputEventMouseButton:
		var scroll_speed = 50  # Adjust this value to change scroll speed

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if showing_global and scroll_container:
				scroll_container.scroll_vertical -= scroll_speed
			elif not showing_global and highscores_scroll_container:
				highscores_scroll_container.scroll_vertical -= scroll_speed
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if showing_global and scroll_container:
				scroll_container.scroll_vertical += scroll_speed
			elif not showing_global and highscores_scroll_container:
				highscores_scroll_container.scroll_vertical += scroll_speed
			get_viewport().set_input_as_handled()
			return

	# Check for mouse click or touch
	var click_pos = Vector2.ZERO
	var is_click = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pos = event.position
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
		is_click = true

	if is_click and back_arrow:
		# Check if click is within back arrow bounds
		var arrow_rect = get_arrow_rect()
		if arrow_rect.has_point(click_pos):
			hide_leaderboard()

# Get the back arrow's clickable rectangle
func get_arrow_rect() -> Rect2:
	if not back_arrow or not back_arrow.texture:
		return Rect2()

	var texture_size = back_arrow.texture.get_size() * back_arrow.scale
	var arrow_pos = back_arrow.global_position - texture_size / 2
	return Rect2(arrow_pos, texture_size)

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

# Populate the leaderboard with placeholder scores
func populate_leaderboard():
	# Check if we need scrolling (more than 9 entries)
	var needs_scrolling = placeholder_scores.size() > 7

	if needs_scrolling and scroll_container == null:
		# Create scroll container
		scroll_container = ScrollContainer.new()
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(735, 900)  # Set max height

		# Enable vertical scrolling
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		# Enable mouse filter to allow scroll events
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll_container.follow_focus = true

		# Remove leaderboard_container from parent
		leaderboard_parent.remove_child(leaderboard_container)

		# Add scroll container to parent
		leaderboard_parent.add_child(scroll_container)

		# Add leaderboard_container to scroll container
		scroll_container.add_child(leaderboard_container)

	# Set container width and vertical alignment
	leaderboard_container.custom_minimum_size.x = 735
	leaderboard_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	leaderboard_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	leaderboard_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Clear existing entries (if any)
	for child in leaderboard_container.get_children():
		child.queue_free()

	# Create a label for each score entry
	for entry in placeholder_scores:
		# Format the score with commas for readability
		var formatted_score = format_score(entry["score"])

		# Create horizontal container for left/right alignment
		var entry_container = HBoxContainer.new()
		entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Set consistent minimum height for all entries to match first place graphic
		entry_container.custom_minimum_size = Vector2(0, 120)
		entry_container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Create left side container for rank/icon and name
		var left_container = HBoxContainer.new()
		left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_container.alignment = BoxContainer.ALIGNMENT_CENTER

		# For ranks 1-4, use graphics instead of numbers
		if entry["rank"] <= 4:
			var rank_icon = TextureRect.new()
			rank_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			rank_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			# First place is larger than the others
			if entry["rank"] == 1:
				rank_icon.custom_minimum_size = Vector2(120, 120)
			else:
				rank_icon.custom_minimum_size = Vector2(80, 80)

			# Load the appropriate rank graphic
			var icon_path = ""
			match entry["rank"]:
				1: icon_path = "res://Assets/UI/first_place.png"
				2: icon_path = "res://Assets/UI/second_place.png"
				3: icon_path = "res://Assets/UI/third_place.png"
				4: icon_path = "res://Assets/UI/fourth_place.png"

			rank_icon.texture = load(icon_path)
			left_container.add_child(rank_icon)

			# Add spacer between icon and name
			var icon_spacer = Control.new()
			icon_spacer.custom_minimum_size = Vector2(10, 0)
			left_container.add_child(icon_spacer)

		# Create name label
		var name_label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		# For ranks 1-4, only show name. For ranks 5+, show rank number and name
		if entry["rank"] <= 4:
			name_label.text = entry["name"]
		else:
			name_label.text = "%d.  %s" % [entry["rank"], entry["name"]]

		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# Set font properties for name label
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var font1 = SystemFont.new()
		font1.font_names = ["Almendra SC"]
		name_label.add_theme_font_override("font", font1)
		name_label.add_theme_font_size_override("font_size", 40)

		left_container.add_child(name_label)

		# Create score label (right-aligned)
		var score_label = Label.new()
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.text = formatted_score
		score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# Set font properties for score label
		score_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var font2 = SystemFont.new()
		font2.font_names = ["Almendra SC"]
		score_label.add_theme_font_override("font", font2)
		score_label.add_theme_font_size_override("font_size", 40)

		# Add containers to entry container
		entry_container.add_child(left_container)
		entry_container.add_child(score_label)

		# Add spacing between entries
		if entry["rank"] > 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 20)
			leaderboard_container.add_child(spacer)

		leaderboard_container.add_child(entry_container)

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

# Populate the high scores container with player's high scores
func populate_highscores():
	if not highscores_container:
		return

	# Use placeholder scores
	var scores = placeholder_highscores.duplicate()

	# Check if we need scrolling (more than 8 entries)
	var needs_scrolling = scores.size() > 7

	if needs_scrolling and highscores_scroll_container == null:
		# Create scroll container
		highscores_scroll_container = ScrollContainer.new()
		highscores_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		highscores_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		highscores_scroll_container.custom_minimum_size = Vector2(735, 900)  # Set max height

		# Enable vertical scrolling
		highscores_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		highscores_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		# Enable mouse filter to allow scroll events
		highscores_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
		highscores_scroll_container.follow_focus = true

		# Remove highscores_container from parent
		leaderboard_parent.remove_child(highscores_container)

		# Add scroll container to parent
		leaderboard_parent.add_child(highscores_scroll_container)

		# Add highscores_container to scroll container
		highscores_scroll_container.add_child(highscores_container)

	# Set container width and vertical alignment
	highscores_container.custom_minimum_size.x = 735
	highscores_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	highscores_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	highscores_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Clear existing entries (if any)
	for child in highscores_container.get_children():
		child.queue_free()

	# Create a label for each score entry
	for i in range(scores.size()):
		var entry_label = Label.new()
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Format the score with commas for readability
		var formatted_score = format_score(scores[i])

		# Create the entry text with rank and score (no name)
		entry_label.text = "%d.  %s" % [i + 1, formatted_score]

		# Set font properties
		entry_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

		# Create and set Almendra SC font
		var font = SystemFont.new()
		font.font_names = ["Almendra SC"]
		entry_label.add_theme_font_override("font", font)
		entry_label.add_theme_font_size_override("font_size", 40)

		# Add spacing between entries
		if i > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 60)
			highscores_container.add_child(spacer)

		highscores_container.add_child(entry_label)
