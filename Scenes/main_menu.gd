extends Control

# References to UI elements
@onready var play_button = $Play
@onready var settings_button = $CenterContainer/VBoxContainer/ButtonsContainer/SettingsButton
@onready var leaderboard_button = $CenterContainer/VBoxContainer/ButtonsContainer/LeaderboardButton

# Reference to settings overlay
@onready var settings_overlay = $SettingsOverlay

# Reference to leaderboard overlay
@onready var leaderboard_overlay = $LeaderboardOverlay

func _ready():
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)

	# Hide overlays initially
	settings_overlay.visible = false
	leaderboard_overlay.visible = false

# Play button handler - loads the table scene
func _on_play_pressed():
	# Load the table scene
	get_tree().change_scene_to_file("res://Scenes/table.tscn")

# Settings button handler - shows settings overlay
func _on_settings_pressed():
	if settings_overlay:
		settings_overlay.show_settings_menu()

# Leaderboard button handler - shows leaderboard overlay
func _on_leaderboard_pressed():
	if leaderboard_overlay:
		leaderboard_overlay.show_leaderboard()
