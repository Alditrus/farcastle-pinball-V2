extends Control

# Reference to back arrow sprite
@onready var back_arrow = $Sprite2D2

func _ready():
	# Set process mode to always so UI works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Enable input processing
	set_process_input(true)

# Show the credits overlay with fade-in animation
func show_credits():
	visible = true

	# Set initial transparency for fade-in effect
	modulate = Color(1, 1, 1, 0)

	# Create fade-in animation that works when paused
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

# Handle input events
func _input(event):
	if not visible:
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
			hide_credits()

# Get the back arrow's clickable rectangle
func get_arrow_rect() -> Rect2:
	if not back_arrow or not back_arrow.texture:
		return Rect2()

	var texture_size = back_arrow.texture.get_size() * back_arrow.scale
	var arrow_pos = back_arrow.global_position - texture_size / 2
	return Rect2(arrow_pos, texture_size)

# Hide the credits overlay with fade-out animation
func hide_credits():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)

	await tween.finished
	visible = false
