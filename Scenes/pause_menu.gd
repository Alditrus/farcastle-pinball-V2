extends Control

# References to UI elements
@onready var resume_button = $CenterContainer/VBoxContainer/ButtonsContainer/Resume
@onready var restart_button = $CenterContainer/VBoxContainer/ButtonsContainer/Restart
@onready var main_menu_button = $CenterContainer/VBoxContainer/ButtonsContainer/Controls
@onready var settings_button = $CenterContainer/VBoxContainer/ButtonsContainer/Settings
@onready var leaderboard_button = $CenterContainer/VBoxContainer/ButtonsContainer/Leaderboard
@onready var highscores_button = $CenterContainer/VBoxContainer/ButtonsContainer/HighScores
@onready var exit_button = $CenterContainer/VBoxContainer/ButtonsContainer/Exit

# References to confirmation overlay
@onready var confirmation_overlay = $ConfirmationOverlay
@onready var yes_button = $ConfirmationOverlay/CenterContainer/VBoxContainer/ButtonsContainer/YesButton
@onready var no_button = $ConfirmationOverlay/CenterContainer/VBoxContainer/ButtonsContainer/NoButton

# Reference to settings overlay
@onready var settings_overlay = $SettingsOverlay

# Reference to control overlay
@onready var control_overlay = $ControlOverlay

# Reference to leaderboard overlay
@onready var leaderboard_overlay = $LeaderboardOverlay

# Reference to highscores overlay
@onready var highscores_overlay = $HighscoresOverlay

# Track what action we're confirming
enum ConfirmAction { RESTART, EXIT }
var current_confirm_action = ConfirmAction.RESTART

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	highscores_button.pressed.connect(_on_highscores_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Connect confirmation overlay buttons
	yes_button.pressed.connect(_on_restart_confirmed)
	no_button.pressed.connect(_on_restart_cancelled)

	# Hide confirmation overlay initially
	confirmation_overlay.visible = false

	# Hide settings overlay initially
	settings_overlay.visible = false

	# Hide control overlay initially
	control_overlay.visible = false

	# Hide leaderboard overlay initially
	leaderboard_overlay.visible = false

	# Hide highscores overlay initially
	highscores_overlay.visible = false

# Show the pause menu
func show_pause_menu():
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue even when paused
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

	# Debug: Check if music is playing before pause
	print("Music playing before pause: ", AudioCollection.is_music_playing())

	# Pause the game (but not the audio)
	get_tree().paused = true

	# Debug: Check if music is still playing after pause
	print("Music playing after pause: ", AudioCollection.is_music_playing())

# Hide the pause menu
func hide_pause_menu():
	# Debug: Check if music is playing before resume
	print("Music playing before resume: ", AudioCollection.is_music_playing())

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue even when paused
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	visible = false

	# Unpause the game
	get_tree().paused = false

	# Debug: Check if music is still playing after resume
	print("Music playing after resume: ", AudioCollection.is_music_playing())

	# Force music to continue if it stopped
	if not AudioCollection.is_music_playing():
		print("Music stopped, restarting...")
		AudioCollection.play_current_track()

# Resume game button handler
func _on_resume_pressed():
	hide_pause_menu()

# Restart button handler - shows confirmation overlay
func _on_restart_pressed():
	current_confirm_action = ConfirmAction.RESTART
	confirmation_overlay.visible = true
	confirmation_overlay.modulate = Color(1, 1, 1, 0)

	# Fade in the confirmation overlay
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirmation_overlay, "modulate", Color(1, 1, 1, 1), 0.3)

# Confirmation Yes button handler
func _on_restart_confirmed():
	# Unpause the game
	get_tree().paused = false

	if current_confirm_action == ConfirmAction.RESTART:
		# Restart the music
		AudioCollection.select_random_track()
		AudioCollection.play_current_track()
		# Reload the scene
		get_tree().reload_current_scene()
	elif current_confirm_action == ConfirmAction.EXIT:
		# Return to main menu
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

# Confirmation No button handler
func _on_restart_cancelled():
	# Fade out and hide the confirmation overlay
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirmation_overlay, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	confirmation_overlay.visible = false

# Controls button handler - shows control overlay
func _on_main_menu_pressed():
	if control_overlay:
		control_overlay.show_control_overlay()

# Settings button handler - shows settings overlay
func _on_settings_pressed():
	if settings_overlay:
		settings_overlay.show_settings_menu()

# Leaderboard button handler - shows leaderboard overlay
func _on_leaderboard_pressed():
	if leaderboard_overlay:
		leaderboard_overlay.show_leaderboard()

# Highscores button handler - shows highscores overlay
func _on_highscores_pressed():
	if highscores_overlay:
		highscores_overlay.show_highscores()

# Exit button handler - shows confirmation overlay
func _on_exit_pressed():
	current_confirm_action = ConfirmAction.EXIT
	confirmation_overlay.visible = true
	confirmation_overlay.modulate = Color(1, 1, 1, 0)

	# Fade in the confirmation overlay
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirmation_overlay, "modulate", Color(1, 1, 1, 1), 0.3)
