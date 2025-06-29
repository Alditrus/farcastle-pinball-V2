extends Node2D

# Reference to the jaw sprite and area
@onready var jaw_sprite = $jaw
@onready var entrance_area = $Area2D
@onready var flame1 = $activeflame1
@onready var flame2 = $activeflame2

# Initial Y position of the jaw
var jaw_initial_y = 0
var jaw_open_offset = 30  # How far the jaw should move (30 pixels down)
var is_entrance_active = false

# Called when the node enters the scene tree for the first time
func _ready():
	# Wait a frame to ensure all nodes are initialized
	await get_tree().process_frame
	
	# Store initial jaw position
	if jaw_sprite:
		jaw_initial_y = jaw_sprite.position.y
	
	# Disable the area initially
	if entrance_area:
		entrance_area.monitoring = false
		entrance_area.monitorable = false
	
	# Disable flames initially
	if flame1:
		flame1.emitting = false
	if flame2:
		flame2.emitting = false
	
	# Open jaw automatically since missions are removed
	_on_jaw_progress(1.0)

# Update the jaw position based on progress (0.0 to 1.0)
func _on_jaw_progress(progress_percent: float):
	if jaw_sprite:
		# Calculate the jaw's new Y position
		var offset = jaw_open_offset * progress_percent
		jaw_sprite.position.y = jaw_initial_y + offset
	
	# If jaw is fully open, activate the minigame entrance
	if progress_percent >= 1.0 and not is_entrance_active:
		activate_minigame_entrance()

# Activate the minigame entrance when jaw is fully open
func activate_minigame_entrance():
	if entrance_area:
		# Enable the collision area using set_deferred to avoid in/out signal errors
		entrance_area.set_deferred("monitoring", true)
		entrance_area.set_deferred("monitorable", true)
		is_entrance_active = true
		
		# Visual feedback
		print("🎮 MINIGAME ENTRANCE ACTIVATED! 🎮")
		
		# Optional: Add visual effects
		add_entrance_effects()

# Add visual effects to indicate the entrance is active
func add_entrance_effects():
	# You could add particles, animation, or other visual effects here
	print("Minigame entrance is now active and ready for the ball!")
	
	# Activate the particle flame effects
	if flame1:
		flame1.emitting = true
	if flame2:
		flame2.emitting = true
	
	# Make the jaw sprite flash
	var tween = create_tween()
	tween.tween_property(jaw_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property(jaw_sprite, "modulate", Color(1, 1, 1), 0.2)
	tween.set_loops(3)

# Reset the entrance (called when resetting the game)
func reset_entrance():
	if entrance_area:
		entrance_area.monitoring = false
		entrance_area.monitorable = false
		is_entrance_active = false
	
	# Start a gradual jaw closing animation
	if jaw_sprite:
		# Create a tween to animate the jaw closing
		var tween = create_tween()
		tween.tween_property(jaw_sprite, "position:y", jaw_initial_y, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# Reset the jaw color
		jaw_sprite.modulate = Color(1, 1, 1)
		
		# When the jaw animation completes, turn off the flame particles and complete the reset
		tween.tween_callback(func():
			# Turn off flame particles after jaw closes
			if flame1:
				# Create a fade-out effect for flames
				var flame1_tween = create_tween()
				flame1_tween.tween_property(flame1, "modulate", Color(1, 1, 1, 0), 0.5)
				flame1_tween.tween_callback(func(): flame1.emitting = false)
				flame1_tween.tween_property(flame1, "modulate", Color(1, 1, 1, 1), 0.1)
				
			if flame2:
				# Create a fade-out effect for flames
				var flame2_tween = create_tween()
				flame2_tween.tween_property(flame2, "modulate", Color(1, 1, 1, 0), 0.5)
				flame2_tween.tween_callback(func(): flame2.emitting = false)
				flame2_tween.tween_property(flame2, "modulate", Color(1, 1, 1, 1), 0.1)
				
			# After the flames fade out, reset the missions system
			_complete_entrance_reset()
		)
		
# Complete the reset by telling the missions system to reset the jaw requirements
func _complete_entrance_reset():
	# Fully reset the entrance state
	is_entrance_active = false
	
	print("Minigame entrance reset complete")
	
	# Find and reset the minigame window
	var minigame_window = get_node_or_null("/root/Table/minigamewindow")
	if minigame_window:
		# Reset the minigame scene entirely
		minigame_window.reset_minigame_scene()
