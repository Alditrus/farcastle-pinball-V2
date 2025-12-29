extends Control

# References to UI elements
@onready var play_button = $Play
@onready var settings_button = $CenterContainer/VBoxContainer/ButtonsContainer/SettingsButton
@onready var leaderboard_button = $CenterContainer/VBoxContainer/ButtonsContainer/LeaderboardButton
@onready var quests_button = $CenterContainer/VBoxContainer/ButtonsContainer/QuestsButton
@onready var token_button = $CenterContainer/VBoxContainer/ButtonsContainer/TokenButton
@onready var credits_button = $CenterContainer/VBoxContainer/ButtonsContainer/CreditsButton

# Reference to settings overlay
@onready var settings_overlay = $SettingsOverlay

# Reference to leaderboard overlay
@onready var leaderboard_overlay = $LeaderboardOverlay

# Reference to leaderboard overlay
@onready var quests_overlay = $QuestsOverlay

# Reference to leaderboard overlay
@onready var token_overlay = $TokenOverlay

# Reference to credits overlay
@onready var credits_overlay = $CreditsOverlay

var coinslot = preload("res://Assets/sounds/coinslot.ogg")

func _ready():
	# Load and play main menu music
	var menu_music = load("res://Assets/music/darkened_shores.ogg")
	if menu_music:
		AudioCollection.play_music(menu_music, true)

	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	quests_button.pressed.connect(_on_quests_pressed)
	token_button.pressed.connect(_on_token_pressed)
	credits_button.pressed.connect(_on_credits_pressed)

	# Hide overlays initially
	settings_overlay.visible = false
	leaderboard_overlay.visible = false
	quests_overlay.visible = false
	token_overlay.visible = false
	credits_overlay.visible = false

# Play button handler - loads the table scene
func _on_play_pressed():
	AudioCollection.play_sfx(coinslot)

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
		
		# Leaderboard button handler - shows leaderboard overlay
func _on_quests_pressed():
	if quests_overlay:
		quests_overlay.show_credits()
		
# Leaderboard button handler - shows leaderboard overlay
func _on_token_pressed():
	if token_overlay:
		token_overlay.show_credits()

# Credits button handler - shows credits overlay
func _on_credits_pressed():
	if credits_overlay:
		credits_overlay.show_credits()
