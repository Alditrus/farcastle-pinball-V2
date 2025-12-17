extends RichTextLabel

# Store the original position
var original_position: Vector2
var is_animating: bool = false

func _ready():
	# Store the original position
	original_position = position

	# Make sure we start invisible
	modulate.a = 0
	visible = true  # Keep visible but transparent

# Function to play the ball saved animation
func play_ball_saved_animation():
	if is_animating:
		return

	is_animating = true

	# Reset to original position and invisible
	position = original_position
	modulate.a = 0

	# Create the tween for the animation sequence
	var tween = create_tween()

	# Set the tween to run in parallel for opacity and position
	tween.set_parallel(true)

	# 1. Fade in (0% -> 100% opacity over 0.3 seconds)
	tween.tween_property(self, "modulate:a", 1.0, 1)

	# 2. Pan upward (move up by 50 pixels over 0.3 seconds)
	var hold_position = original_position.y - 50
	tween.tween_property(self, "position:y", hold_position, 1)

	# After fade in and pan up complete, hold for a moment
	tween.chain()

	# 3. Hold at full opacity and position for 2 seconds
	tween.tween_interval(2.0)

	tween.chain()

	# 4. Fade out (100% -> 0% opacity over 0.4 seconds) and continue panning up
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 1)
	tween.tween_property(self, "position:y", original_position.y - 100, 1)

	# 5. Reset to original state after animation completes
	tween.chain()
	tween.tween_callback(reset_to_original)

# Reset the label to its original state
func reset_to_original():
	position = original_position
	modulate.a = 0
	is_animating = false
