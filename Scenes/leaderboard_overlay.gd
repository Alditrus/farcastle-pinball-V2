extends Control

# References to UI elements
@onready var back_button = $CenterContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var leaderboard_container = $CenterContainer/VBoxContainer/LeaderboardContainer

# Leaderboard data from API
var leaderboard_data: Array = []

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)

func _get_javascript_singleton():
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

# Show the leaderboard overlay
func show_leaderboard():
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Get cached leaderboard data (top 6 for pause menu)
	leaderboard_data = await LeaderboardCache.get_leaderboard(6)
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

# Back button handler
func _on_back_pressed():
	hide_leaderboard()

# NOTE: fetch_leaderboard_data() removed - now using LeaderboardCache singleton

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

# Populate the leaderboard with real data
func populate_leaderboard():
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

	# Create entry for each player
	for i in range(leaderboard_data.size()):
		var player_data = leaderboard_data[i]

		# Create horizontal container for the entry
		var entry_container = HBoxContainer.new()
		entry_container.custom_minimum_size = Vector2(0, 60)
		entry_container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Create profile picture
		var profile_pic = TextureRect.new()
		profile_pic.custom_minimum_size = Vector2(50, 50)
		profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Apply circular shader
		var shader = load("res://Assets/shaders/circular_profile.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			profile_pic.material = material

		entry_container.add_child(profile_pic)

		# Add spacer
		var spacer1 = Control.new()
		spacer1.custom_minimum_size = Vector2(10, 0)
		entry_container.add_child(spacer1)

		# Create username label
		var username_label = Label.new()
		var display_name = player_data.get("display_name", player_data.get("username", "Player"))
		username_label.text = "%d. %s" % [i + 1, display_name]
		username_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		username_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		username_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var font1 = SystemFont.new()
		font1.font_names = ["Almendra SC"]
		username_label.add_theme_font_override("font", font1)
		username_label.add_theme_font_size_override("font_size", 30)
		entry_container.add_child(username_label)

		# Create score label
		var score_label = Label.new()
		var score = player_data.get("score", 0)
		score_label.text = format_score(score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var font2 = SystemFont.new()
		font2.font_names = ["Almendra SC"]
		score_label.add_theme_font_override("font", font2)
		score_label.add_theme_font_size_override("font_size", 30)
		entry_container.add_child(score_label)

		# Add spacing between entries
		if i > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 10)
			leaderboard_container.add_child(spacer)

		leaderboard_container.add_child(entry_container)

		# Load profile picture asynchronously
		var pfp_url = player_data.get("pfp_url", "")
		if pfp_url != "" and pfp_url != null:
			load_profile_picture_async(profile_pic, pfp_url)

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
