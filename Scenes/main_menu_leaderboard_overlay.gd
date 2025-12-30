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

# Leaderboard data from API
var leaderboard_data: Array = []
var is_loading_more: bool = false
var has_more_data: bool = true

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

	# Populate high scores with placeholder
	populate_highscores()

	# Hide high scores container initially (show global by default)
	if highscores_container:
		highscores_container.visible = false

func _get_javascript_singleton():
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

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
				# Check if near bottom for infinite scroll
				check_and_load_more()
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

	# Get cached leaderboard data (top 10 initially)
	leaderboard_data = await LeaderboardCache.get_leaderboard(10)
	has_more_data = true  # Reset for infinite scroll
	populate_leaderboard()

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

# Check if user scrolled near bottom and load more entries
func check_and_load_more():
	if not showing_global or not scroll_container or is_loading_more or not has_more_data:
		return

	# Calculate if we're near the bottom (within 200px)
	var max_scroll = scroll_container.get_v_scroll_bar().max_value
	var current_scroll = scroll_container.scroll_vertical
	var threshold = 200

	if max_scroll - current_scroll < threshold:
		load_more_entries()

# Load more leaderboard entries
func load_more_entries():
	if is_loading_more or not has_more_data:
		return

	is_loading_more = true
	print("[MainMenuLeaderboard] Loading more entries... (current: ", leaderboard_data.size(), ")")

	var current_count = leaderboard_data.size()
	var more_data = await LeaderboardCache.fetch_more_entries(current_count, 10)

	if more_data.size() > 0:
		# Append new entries to existing data
		leaderboard_data.append_array(more_data)
		print("[MainMenuLeaderboard] Loaded ", more_data.size(), " more entries (total: ", leaderboard_data.size(), ")")

		# Append new entries to UI
		append_leaderboard_entries(more_data, current_count)
	else:
		print("[MainMenuLeaderboard] No more entries to load")
		has_more_data = false

	is_loading_more = false

# Append new entries to the existing leaderboard UI
func append_leaderboard_entries(new_entries: Array, start_index: int):
	for i in range(new_entries.size()):
		var player_data = new_entries[i]
		var entry_rank = start_index + i + 1

		# Add spacing
		if leaderboard_container.get_child_count() > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 20)
			leaderboard_container.add_child(spacer)

		create_leaderboard_entry(player_data, entry_rank)

# Create a single leaderboard entry
func create_leaderboard_entry(player_data: Dictionary, entry_rank: int):
	# Format the score with commas for readability
	var score = player_data.get("score", 0)
	var formatted_score = format_score(score)

	# Create horizontal container for left/right alignment
	var entry_container = HBoxContainer.new()
	entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_container.custom_minimum_size = Vector2(0, 120)
	entry_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Create left side container for rank/icon, profile pic, and name
	var left_container = HBoxContainer.new()
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# For ranks 1-4, use graphics instead of numbers
	if entry_rank <= 4:
		var rank_icon = TextureRect.new()
		rank_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rank_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# First place is larger than the others
		if entry_rank == 1:
			rank_icon.custom_minimum_size = Vector2(120, 120)
		else:
			rank_icon.custom_minimum_size = Vector2(80, 80)

		# Load the appropriate rank graphic
		var icon_path = ""
		match entry_rank:
			1: icon_path = "res://Assets/UI/first_place.png"
			2: icon_path = "res://Assets/UI/second_place.png"
			3: icon_path = "res://Assets/UI/third_place.png"
			4: icon_path = "res://Assets/UI/fourth_place.png"

		rank_icon.texture = load(icon_path)
		left_container.add_child(rank_icon)

		# Add spacer between icon and profile pic
		var icon_spacer = Control.new()
		icon_spacer.custom_minimum_size = Vector2(10, 0)
		left_container.add_child(icon_spacer)

	# Create profile picture
	var profile_pic = TextureRect.new()
	profile_pic.custom_minimum_size = Vector2(60, 60)
	profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Apply circular shader
	var shader = load("res://Assets/shaders/circular_profile.gdshader")
	if shader:
		var material = ShaderMaterial.new()
		material.shader = shader
		profile_pic.material = material

	left_container.add_child(profile_pic)

	# Add spacer between profile pic and name
	var pfp_spacer = Control.new()
	pfp_spacer.custom_minimum_size = Vector2(10, 0)
	left_container.add_child(pfp_spacer)

	# Create name label
	var name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var display_name = player_data.get("display_name", player_data.get("username", "Player"))
	# For ranks 1-4, only show name. For ranks 5+, show rank number and name
	if entry_rank <= 4:
		name_label.text = display_name
	else:
		name_label.text = "%d.  %s" % [entry_rank, display_name]

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

	leaderboard_container.add_child(entry_container)

	# Load profile picture asynchronously
	var pfp_url = player_data.get("pfp_url", "")
	if pfp_url != "" and pfp_url != null:
		load_profile_picture_async(profile_pic, pfp_url)

# NOTE: fetch_leaderboard_data() removed - now using LeaderboardCache singleton
func old_fetch_leaderboard_data():
	var js = _get_javascript_singleton()
	if not js:
		print("❌ No JavaScript singleton available for leaderboard fetch")
		return

	print("🔄 Fetching leaderboard from API...")

	# Call the JavaScript function to get leaderboard
	var leaderboard_promise = js.eval("""
		(async () => {
			try {
				if (typeof window.getLeaderboard === 'function') {
					const result = await window.getLeaderboard(10);
					return JSON.stringify(result);
				}
				return JSON.stringify({ leaderboard: [] });
			} catch (error) {
				console.error('Leaderboard fetch error:', error);
				return JSON.stringify({ leaderboard: [] });
			}
		})()
	""", true)

	# Wait a bit for the promise to resolve
	await get_tree().create_timer(1.0).timeout

	# Try to get the result
	var result_json = js.eval("""
		(window.lastLeaderboardResult || JSON.stringify({ leaderboard: [] }))
	""", true)

	# Store result for next retrieval
	js.eval("""
		(async () => {
			try {
				if (typeof window.getLeaderboard === 'function') {
					const result = await window.getLeaderboard(10);
					window.lastLeaderboardResult = JSON.stringify(result);
				}
			} catch (error) {
				console.error('Error:', error);
			}
		})()
	""", true)

	# Wait for result to be stored
	await get_tree().create_timer(0.5).timeout

	result_json = js.eval("(window.lastLeaderboardResult || JSON.stringify({ leaderboard: [] }))", true)

	if result_json is String and result_json != "":
		var json = JSON.new()
		var parse_result = json.parse(result_json)

		if parse_result == OK:
			var data = json.data
			if data and data.has("leaderboard"):
				leaderboard_data = data.leaderboard
				print("✅ Leaderboard fetched: ", leaderboard_data.size(), " entries")
			else:
				print("⚠️ No leaderboard data in response")
		else:
			print("⚠️ Failed to parse leaderboard JSON")
	else:
		print("⚠️ No leaderboard result received")

# Download profile picture from URL
func download_profile_picture(url: String) -> Image:
	if url == null or url == "":
		return null

	var http_request = HTTPRequest.new()
	add_child(http_request)

	var error = http_request.request(url)
	if error != OK:
		print("❌ Failed to request profile picture: ", url)
		http_request.queue_free()
		return null

	var response = await http_request.request_completed
	http_request.queue_free()

	var result = response[0]
	var response_code = response[1]
	var body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("❌ Failed to download profile picture: ", response_code)
		return null

	var image = Image.new()
	var image_error

	# Try formats in order of likelihood for Farcaster profile pics: JPG -> WebP -> PNG
	# This avoids the "Not a PNG file" error spam
	image_error = image.load_jpg_from_buffer(body)
	if image_error != OK:
		image_error = image.load_webp_from_buffer(body)
	if image_error != OK:
		image_error = image.load_png_from_buffer(body)

	if image_error != OK:
		print("❌ Failed to load image from buffer (tried JPG, WebP, PNG)")
		return null

	return image

# Load profile picture asynchronously without blocking
func load_profile_picture_async(texture_rect: TextureRect, url: String):
	var image = await download_profile_picture(url)
	if image and texture_rect:
		var texture = ImageTexture.create_from_image(image)
		texture_rect.texture = texture

# Populate the leaderboard with real data from API
func populate_leaderboard():
	# Check if we need scrolling (more than 7 entries)
	var needs_scrolling = leaderboard_data.size() > 7

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

	if leaderboard_data.size() == 0:
		# Show "No data" message
		var no_data_label = Label.new()
		no_data_label.text = "No leaderboard data available"
		no_data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_data_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		leaderboard_container.add_child(no_data_label)
		return

	# Create entry for each player from API data
	for i in range(leaderboard_data.size()):
		var player_data = leaderboard_data[i]
		var entry_rank = i + 1

		# Add spacing between entries
		if i > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 20)
			leaderboard_container.add_child(spacer)

		create_leaderboard_entry(player_data, entry_rank)

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
