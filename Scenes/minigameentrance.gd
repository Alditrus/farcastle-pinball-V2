extends Node2D

# Reference to the jaw sprite and area
@onready var jaw_sprite = $jaw
@onready var entrance_area = $Area2D
@onready var flame1 = $activeflame1
@onready var flame2 = $activeflame2

# Reference to missions node
var missions_node: Node2D

# Initial Y position of the jaw
var jaw_initial_y = 0
var jaw_open_offset = 30  # How far the jaw should move (30 pixels down)
var is_entrance_active = false

# Animation variables
var current_jaw_progress = 0.0
var jaw_tween: Tween

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
	
	# Connect to missions system
	missions_node = get_node_or_null("../missions")
	if missions_node:
		missions_node.mission_completed.connect(_on_mission_completed)
		missions_node.mission_progress_updated.connect(_on_mission_progress_updated)
		missions_node.mission_started.connect(_on_mission_started)
	else:
		push_error("Could not find missions node")
	
	# Keep jaw closed initially - will open when mission is completed
	_on_jaw_progress(0.0)

# Called when a mission is started
func _on_mission_started(mission):
	print("Mission started: " + mission.name + " - Resetting jaw progress")
	# Reset jaw to closed when mission starts
	_on_jaw_progress(0.0)

# Called when mission progress is updated
func _on_mission_progress_updated(mission, _collision_type, _current_count, _required_count):
	# Calculate overall mission progress
	var progress = calculate_mission_progress(mission)
	_on_jaw_progress(progress)

# Called when a mission is completed
func _on_mission_completed(mission):
	print("Mission completed: " + mission.name + " - Opening minigame entrance!")
	# Open the jaw when mission is completed
	_on_jaw_progress(1.0)

# Calculate overall mission progress (0.0 to 1.0)
func calculate_mission_progress(mission) -> float:
	if not mission:
		return 0.0
	
	# Calculate progress within current phase
	var current_phase_requirements = mission.phases[mission.current_phase]
	var phase_progress = 0.0
	var total_requirements = 0
	var completed_requirements = 0
	
	# Check progress within current phase
	for collision_type in current_phase_requirements:
		var required = current_phase_requirements[collision_type]
		var current = mission.progress.get(collision_type, 0)
		total_requirements += required
		completed_requirements += min(current, required)
	
	# Calculate current phase completion (0.0 to 1.0)
	if total_requirements > 0:
		phase_progress = float(completed_requirements) / float(total_requirements)
	
	# Calculate overall mission progress
	# (completed phases + current phase progress) / total phases
	var overall_progress = (float(mission.current_phase) + phase_progress) / float(mission.phases.size())
	
	return clamp(overall_progress, 0.0, 1.0)

# Update the jaw position based on progress (0.0 to 1.0) with smooth animation
func _on_jaw_progress(progress_percent: float):
	if not jaw_sprite:
		return
	
	# Don't animate if progress hasn't changed significantly
	if abs(progress_percent - current_jaw_progress) < 0.01:
		return
	
	# Stop any existing tween
	if jaw_tween:
		jaw_tween.kill()
	
	# Create new tween for smooth animation
	jaw_tween = create_tween()
	jaw_tween.set_ease(Tween.EASE_OUT)
	jaw_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Calculate target Y position
	var target_offset = jaw_open_offset * progress_percent
	var target_y = jaw_initial_y + target_offset
	
	# Animate jaw to new position over 0.5 seconds
	jaw_tween.tween_property(jaw_sprite, "position:y", target_y, 0.5)
	
	# Update current progress
	current_jaw_progress = progress_percent
	
	# If jaw is fully open, activate the minigame entrance
	if progress_percent >= 1.0 and not is_entrance_active:
		# Wait for animation to complete before activating
		jaw_tween.tween_callback(activate_minigame_entrance)

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
