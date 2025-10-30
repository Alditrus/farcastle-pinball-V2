extends Control

# References to UI elements
@onready var desktop_button = $CenterContainer/VBoxContainer/ButtonsContainer/Desktop
@onready var mobile_button = $CenterContainer/VBoxContainer/ButtonsContainer/Mobile
@onready var back_button = $CenterContainer/VBoxContainer/ButtonsContainer2/BackButton

# References to control display containers
@onready var desktop_ctrls = $CenterContainer/Desktop_ctrls
@onready var mobile_ctrls = $CenterContainer/Mobile_ctrls

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	desktop_button.pressed.connect(_on_desktop_pressed)
	mobile_button.pressed.connect(_on_mobile_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Show mobile controls by default
	show_mobile_controls()

# Show the control overlay
func show_control_overlay():
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

# Hide the control overlay
func hide_control_overlay():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	visible = false

# Desktop button handler - show desktop controls
func _on_desktop_pressed():
	show_desktop_controls()

# Mobile button handler - show mobile controls
func _on_mobile_pressed():
	show_mobile_controls()

# Show desktop controls and hide mobile controls
func show_desktop_controls():
	desktop_ctrls.visible = true
	mobile_ctrls.visible = false

# Show mobile controls and hide desktop controls
func show_mobile_controls():
	desktop_ctrls.visible = false
	mobile_ctrls.visible = true

# Back button handler - hide control overlay and return to pause menu
func _on_back_pressed():
	hide_control_overlay()
