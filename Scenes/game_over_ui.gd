extends Control

# References to UI elements
@onready var game_over_label = $CenterContainer/VBoxContainer/GameOverLabel
@onready var final_score_label = $CenterContainer/VBoxContainer/HBoxContainer/FinalScoreLabel
@onready var high_score_title = $CenterContainer/VBoxContainer/HighScoreContainer/HighScoreTitle
@onready var score_entries = [
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score1,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score2,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score3,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score4,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score5,
	$CenterContainer/VBoxContainer/HighScoreContainer/ScoresList/Score6
]
@onready var play_again_button = $CenterContainer/VBoxContainer/ButtonsContainer/PlayAgainButton
@onready var exit_button = $CenterContainer/VBoxContainer/ButtonsContainer/ExitButton

# High scores array (will be loaded from API)
var high_scores: Array[int] = [0, 0, 0, 0, 0, 0]
var leaderboard_data: Array = []

var verified_score: int = 0
var is_waiting_for_verification: bool = false

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide the UI initially
	visible = false

	# Connect button signals (functionality will be added later)
	play_again_button.pressed.connect(_on_play_again_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Apply circular shader to all profile pictures
	setup_circular_profile_pics()

# Show the game over UI
func show_game_over(final_score: int = 0):
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	update_final_score_display(final_score)

	# Wait for server verification if web build
	if OS.has_feature("web"):
		is_waiting_for_verification = true
		# Show a small indicator that we're verifying
		if final_score_label:
			final_score_label.text = format_score_with_commas(final_score) + " (verifying...)"
		
		# Wait for server to verify score
		await wait_for_server_verification()
		
		# Update with verified score
		if verified_score > 0:
			print("Displaying verified score: ", verified_score)
			update_final_score_display(verified_score)
			# Use verified score for high score check
			check_and_update_high_score(verified_score)
		else:
			# If verification failed, use client score but mark it
			print("Using client score (verification failed)")
			if final_score_label:
				final_score_label.text = format_score_with_commas(final_score) + " (unverified)"
			check_and_update_high_score(final_score)
	else:
		# Not a web build, use client score directly
		check_and_update_high_score(final_score)
	
	# Fetch leaderboard from API
	await fetch_leaderboard_data()
	update_high_scores_display()

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue even when paused
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.0)

	# Pause the game
	get_tree().paused = true

func _get_javascript_singleton():
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

func wait_for_server_verification():
	var js = _get_javascript_singleton()
	if not js:
		print("❌ No JavaScript singleton available")
		return
	
	print("⏳ Waiting for server to verify score...")
	
	var max_attempts = 30
	var attempts = 0
	
	while attempts < max_attempts:
		var score_result = js.eval("window.verifiedScore || 0", true)
		print("Attempt ", attempts + 1, ": verifiedScore = ", score_result)
		
		if score_result is int or score_result is float:
			if score_result > 0:
				verified_score = int(score_result)
				is_waiting_for_verification = false
				print("✅ Server verified score: ", verified_score)
				return
		
		await get_tree().create_timer(0.1).timeout
		attempts += 1
	
	is_waiting_for_verification = false
	push_warning("⚠️ Score verification timed out")

# Hide the game over UI
func hide_game_over():
	visible = false

	# Reset verification state
	verified_score = 0
	is_waiting_for_verification = false
	
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

# Fetch leaderboard data from API
func fetch_leaderboard_data():
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
					const result = await window.getLeaderboard(6);
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
					const result = await window.getLeaderboard(6);
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

	# Try different image formats
	if url.to_lower().ends_with(".png") or url.to_lower().contains(".png"):
		image_error = image.load_png_from_buffer(body)
	elif url.to_lower().ends_with(".jpg") or url.to_lower().ends_with(".jpeg") or url.to_lower().contains(".jpg"):
		image_error = image.load_jpg_from_buffer(body)
	elif url.to_lower().ends_with(".webp") or url.to_lower().contains(".webp"):
		image_error = image.load_webp_from_buffer(body)
	else:
		# Try PNG first, then JPG
		image_error = image.load_png_from_buffer(body)
		if image_error != OK:
			image_error = image.load_jpg_from_buffer(body)
		if image_error != OK:
			image_error = image.load_webp_from_buffer(body)

	if image_error != OK:
		print("❌ Failed to load image from buffer")
		return null

	return image

# Update the high scores display
func update_high_scores_display():
	for i in range(score_entries.size()):
		var entry = score_entries[i]
		var profile_pic = entry.get_node("ProfilePic")
		var username_label = entry.get_node("Username")
		var score_label = entry.get_node("ScoreValue")

		if i < leaderboard_data.size():
			var player_data = leaderboard_data[i]

			# Update username
			var display_name = player_data.get("display_name", player_data.get("username", "Player"))
			username_label.text = display_name

			# Update score
			var score = player_data.get("score", 0)
			score_label.text = format_score_with_commas(score)

			# Update profile picture asynchronously
			var pfp_url = player_data.get("pfp_url", "")
			if pfp_url != "" and pfp_url != null:
				# Start downloading profile picture in background
				load_profile_picture_async(profile_pic, pfp_url)
			else:
				profile_pic.texture = null
		else:
			# No data for this position
			username_label.text = "---"
			score_label.text = "---"
			profile_pic.texture = null

# Setup circular shader material for all profile pictures
func setup_circular_profile_pics():
	var shader = load("res://Assets/shaders/circular_profile.gdshader")
	if shader:
		for entry in score_entries:
			var profile_pic = entry.get_node("ProfilePic")
			if profile_pic:
				var material = ShaderMaterial.new()
				material.shader = shader
				profile_pic.material = material

# Load profile picture asynchronously without blocking
func load_profile_picture_async(texture_rect: TextureRect, url: String):
	var image = await download_profile_picture(url)
	if image and texture_rect:
		var texture = ImageTexture.create_from_image(image)
		texture_rect.texture = texture

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
	# Reset game over flag in score label
	var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
	if score_label and score_label.has_method("reset_game_over_flag"):
		score_label.reset_game_over_flag()

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
