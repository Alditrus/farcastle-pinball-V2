extends Control

# References to UI elements
@onready var resume_button = $CenterContainer/VBoxContainer/ButtonsContainer/ResumeButton
@onready var options_button = $CenterContainer/VBoxContainer/ButtonsContainer/OptionsButton
@onready var main_menu_button = $CenterContainer/VBoxContainer/ButtonsContainer/MainMenuButton

func _ready():
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

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

# Options button handler (placeholder)
func _on_options_pressed():
	print("Options button pressed - to be implemented")
	# TODO: Implement options menu with volume controls, etc.

# Main menu button handler (placeholder)
func _on_main_menu_pressed():
	print("Main Menu button pressed - to be implemented")
	# TODO: Implement return to main menu functionality