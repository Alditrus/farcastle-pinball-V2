extends Node2D

# Multiball system for tracking sinkhole sequence and activating multiball

# Required sequence: Right, Left, Right, Right, Left, Left, Right
var required_sequence = ["RIGHT", "LEFT", "RIGHT", "RIGHT", "LEFT", "LEFT", "RIGHT"]
var current_sequence = []
var multiball_active = false

# Timer for multiball duration
var multiball_timer: Timer
var multiball_duration = 60  # 1 minute duration

# Ball spawning properties
var ball_scene_path = "res://Scenes/ball.tscn"
var ball_scene_resource: PackedScene
var launch_position = Vector2(840, 1240)  # Launch lane position (matches primary ball spawn)
var launch_velocity = Vector2(0, -2000)    # Upward velocity for launch

# Signal for multiball activation
signal multiball_activated
signal sequence_updated(current_sequence: Array, required_sequence: Array)

func _ready():
	# Load ball scene resource
	ball_scene_resource = load(ball_scene_path)
	if not ball_scene_resource:
		push_error("Failed to load ball scene resource for multiball")
	
	# Create and configure timer
	multiball_timer = Timer.new()
	multiball_timer.wait_time = multiball_duration
	multiball_timer.one_shot = true
	multiball_timer.timeout.connect(_on_multiball_timer_timeout)
	add_child(multiball_timer)

# Called when a sinkhole is hit
func record_sinkhole_hit(sinkhole_type: String):
	# Don't record during multiball
	if multiball_active:
		return
	
	# Check if this hit matches the expected next hit in sequence
	var expected_next = get_next_expected_sinkhole()
	
	if expected_next != "" and sinkhole_type == expected_next:
		# Correct hit - add to sequence
		current_sequence.append(sinkhole_type)
	else:
		# Wrong hit - reset sequence and start over with this hit
		current_sequence.clear()
		current_sequence.append(sinkhole_type)
	
	# Keep only the last 7 hits (same size as required sequence)
	if current_sequence.size() > required_sequence.size():
		current_sequence.pop_front()
	
	# Emit signal for sequence update
	emit_signal("sequence_updated", current_sequence, required_sequence)
	
	# Check if sequence matches required pattern
	if check_sequence():
		activate_multiball()

# Check if current sequence matches the required sequence
func check_sequence() -> bool:
	# Only check if we have enough hits
	if current_sequence.size() < required_sequence.size():
		return false
	
	# Compare the sequences
	for i in range(required_sequence.size()):
		if current_sequence[i] != required_sequence[i]:
			return false
	
	return true


# Activate multiball mode
func activate_multiball():
	if multiball_active:
		return
	
	multiball_active = true
	current_sequence.clear()
	
	# Start the 1-minute timer
	multiball_timer.start()
	
	# Spawn secondary ball
	spawn_secondary_ball()

	# Trigger the ball saved animation
	var ball_saved_label = get_node_or_null("../Multi-Ball")
	if ball_saved_label and ball_saved_label.has_method("play_ball_saved_animation"):
		ball_saved_label.play_ball_saved_animation()
	
	# Emit signal
	emit_signal("multiball_activated")

# Spawn the secondary ball in the launch lane
func spawn_secondary_ball():
	if not ball_scene_resource:
		push_error("Ball scene resource not loaded")
		return
	
	# Get table reference
	var table = get_parent()
	if not table:
		push_error("Could not find table node")
		return
	
	# Create new ball
	var new_ball = ball_scene_resource.instantiate()
	if not new_ball:
		push_error("Failed to instantiate secondary ball")
		return
	
	# Set position and properties before adding to scene
	new_ball.global_position = launch_position
	new_ball.add_to_group("balls")
	
	# Set collision properties
	new_ball.collision_layer = 1
	new_ball.collision_mask = 1
	new_ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	new_ball.sleeping = false
	
	# Use call_deferred to add to scene to avoid physics query flushing error
	table.call_deferred("add_child", new_ball)
	new_ball.call_deferred("set", "name", "multiball_ball")
	
	# Launch the ball upward after a brief delay
	await get_tree().create_timer(0.1).timeout
	new_ball.linear_velocity = launch_velocity

# Reset multiball state (called when timer expires or manually)
func reset_multiball():
	multiball_active = false
	current_sequence.clear()
	
	# Stop the timer if it's running
	if multiball_timer and multiball_timer.time_left > 0:
		multiball_timer.stop()

# Called when multiball timer expires
func _on_multiball_timer_timeout():
	print("MULTIBALL ENDED - Timer expired")
	reset_multiball()

# Check if multiball is currently active
func is_multiball_active() -> bool:
	return multiball_active

# Get current sequence progress (for UI display)
func get_sequence_progress() -> String:
	var progress = ""
	for i in range(required_sequence.size()):
		if i < current_sequence.size():
			progress += current_sequence[i]
		else:
			progress += "_"
		if i < required_sequence.size() - 1:
			progress += " -> "
	return progress

# Get required sequence string (for UI display)
func get_required_sequence() -> String:
	return " -> ".join(required_sequence)

# Get the next expected sinkhole in the sequence
func get_next_expected_sinkhole() -> String:
	if current_sequence.size() >= required_sequence.size():
		return ""  # Sequence complete or full
	return required_sequence[current_sequence.size()]

# Check if current sequence is correct so far
func is_sequence_valid() -> bool:
	for i in range(current_sequence.size()):
		if current_sequence[i] != required_sequence[i]:
			return false
	return true
