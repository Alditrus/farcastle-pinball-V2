extends Control

# References to UI elements
@onready var music_slider = $CenterContainer/VBoxContainer/SettingsContainer/MusicContainer/MusicSlider
@onready var sound_slider = $CenterContainer/VBoxContainer/SettingsContainer/SoundContainer/SoundSlider
@onready var nudge_toggle = $CenterContainer/VBoxContainer/SettingsContainer/NudgeContainer/NudgeToggle
@onready var back_button = $CenterContainer/VBoxContainer/ButtonsContainer/BackButton

# Reference to nudge system
var nudge_system = null

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)

	# Connect slider signals
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_slider.value_changed.connect(_on_sound_volume_changed)

	# Connect toggle signal
	nudge_toggle.toggled.connect(_on_nudge_toggled)

	# Wait a frame to ensure nudge system is ready
	await get_tree().process_frame

	# Get reference to nudge system - look in the parent scene
	nudge_system = get_tree().get_first_node_in_group("nudge_system")

	if nudge_system:
		print("Nudge system found! Current state: ", nudge_system.nudge_enabled)
	else:
		print("WARNING: Nudge system not found!")

	# Initialize slider values from current audio settings
	if AudioCollection:
		music_slider.value = AudioCollection.get_music_volume_linear()
		sound_slider.value = AudioCollection.get_sfx_volume_linear()

	# Initialize nudge toggle from current nudge system state
	if nudge_system:
		nudge_toggle.button_pressed = nudge_system.nudge_enabled
		print("Checkbox initialized to: ", nudge_toggle.button_pressed)
	else:
		nudge_toggle.button_pressed = true  # Default to enabled if system not found

# Show the settings menu
func show_settings_menu():
	visible = true

	# Update settings to reflect current state
	if AudioCollection:
		music_slider.value = AudioCollection.get_music_volume_linear()
		sound_slider.value = AudioCollection.get_sfx_volume_linear()

	if nudge_system:
		nudge_toggle.button_pressed = nudge_system.nudge_enabled

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

# Hide the settings menu
func hide_settings_menu():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	visible = false

# Back button handler
func _on_back_pressed():
	hide_settings_menu()

# Music volume slider handler
func _on_music_volume_changed(value: float):
	if AudioCollection:
		AudioCollection.set_music_volume_linear(value)

# Sound volume slider handler
func _on_sound_volume_changed(value: float):
	if AudioCollection:
		AudioCollection.set_sfx_volume_linear(value)

# Nudge toggle handler
func _on_nudge_toggled(toggled_on: bool):
	print("Toggle changed! New value: ", toggled_on)

	# Re-get the nudge system reference if we don't have it
	if not nudge_system:
		nudge_system = get_tree().get_first_node_in_group("nudge_system")

	if nudge_system:
		# Update the nudge system's enabled state
		nudge_system.nudge_enabled = toggled_on
		print("Nudge system updated - enabled: ", nudge_system.nudge_enabled)
	else:
		print("ERROR: Nudge system not found, cannot update!")
