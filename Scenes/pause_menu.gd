extends Control

# References to UI elements
@onready var resume_button = $CenterContainer/VBoxContainer/ButtonsContainer/ResumeButton
@onready var restart_button = $CenterContainer/VBoxContainer/ButtonsContainer/OptionsButton
@onready var main_menu_button = $CenterContainer/VBoxContainer/ButtonsContainer/MainMenuButton

# References to confirmation overlay
@onready var confirmation_overlay = $ConfirmationOverlay
@onready var yes_button = $ConfirmationOverlay/CenterContainer/VBoxContainer/ButtonsContainer/YesButton
@onready var no_button = $ConfirmationOverlay/CenterContainer/VBoxContainer/ButtonsContainer/NoButton

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	# Connect confirmation overlay buttons
	yes_button.pressed.connect(_on_restart_confirmed)
	no_button.pressed.connect(_on_restart_cancelled)

	# Hide confirmation overlay initially
	confirmation_overlay.visible = false

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
	# Restart the music
	AudioCollection.select_random_track()
	AudioCollection.play_current_track()
	# Reload the scene
	get_tree().reload_current_scene()

# Confirmation No button handler
func _on_restart_cancelled():
	# Fade out and hide the confirmation overlay
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirmation_overlay, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	confirmation_overlay.visible = false

# Main menu button handler (placeholder)
func _on_main_menu_pressed():
	print("Main Menu button pressed - to be implemented")
	# TODO: Implement return to main menu functionality