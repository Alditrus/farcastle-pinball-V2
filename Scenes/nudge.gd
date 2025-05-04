extends Node2D

# Configuration for nudge effect
var nudge_force = 400.0  # Horizontal force to apply to balls
var nudge_vertical_force = 200.0  # Small vertical force to combine with horizontal
var camera_offset = 15.0  # Distance to shift camera
var camera_shift_time = 0.1  # Time to shift camera
var camera_return_time = 0.2  # Time to return camera
var cooldown_duration = 0.5  # Time before allowing another nudge
var tilt_threshold = 5  # Number of nudges before tilt warning
var tilt_limit = 8  # Number of nudges before tilt (game over)
var tilt_decay_time = 10.0  # Time for tilt count to decrease by 1

# State tracking
var is_nudging = false
var nudge_cooldown = 0.0
var tilt_count = 0
var tilt_decay_timer = 0.0
var is_tilted = false

# References
@onready var camera = get_viewport().get_camera_2d()

# Signal to notify when tilt state changes
signal tilt_state_changed(is_tilted)

func _ready():
	# Add to group so flippers can find it
	add_to_group("nudge_system")
	print("Nudge system initialized - use LEFT ARROW for left nudge, RIGHT ARROW for right nudge")

func _process(delta):
	# Update cooldown timer
	if nudge_cooldown > 0:
		nudge_cooldown -= delta
	
	# Decay tilt count over time (if not already tilted)
	if !is_tilted and tilt_count > 0:
		tilt_decay_timer += delta
		if tilt_decay_timer >= tilt_decay_time:
			tilt_decay_timer = 0
			tilt_count -= 1
			print("Tilt count reduced to: ", tilt_count)
	
	# Handle input if not currently nudging, not tilted, and cooldown has expired
	if !is_nudging and !is_tilted and nudge_cooldown <= 0:
		# Check left arrow key for left nudge
		if Input.is_physical_key_pressed(KEY_LEFT):
			apply_nudge(-1.0)  # Nudge left
		# Check right arrow key for right nudge
		elif Input.is_physical_key_pressed(KEY_RIGHT): 
			apply_nudge(1.0)   # Nudge right

# Apply physics nudge to all balls
func apply_nudge(direction):
	if is_nudging:
		return
	
	is_nudging = true
	nudge_cooldown = cooldown_duration
	
	# Increment tilt counter
	tilt_count += 1
	tilt_decay_timer = 0
	
	# Check for tilt warnings/game over
	if tilt_count >= tilt_limit:
		handle_tilt()
		return
	elif tilt_count >= tilt_threshold:
		print("TILT WARNING! Count: ", tilt_count, "/", tilt_limit)
	
	# Get all balls in the game
	var balls = get_tree().get_nodes_in_group("balls")
	
	# Apply force to each ball
	for ball in balls:
		if is_instance_valid(ball) and ball is RigidBody2D:
			# Apply an impulse in the specified direction
			var impulse = Vector2(nudge_force * direction, -nudge_vertical_force)
			ball.apply_impulse(impulse)
	
	# Visual feedback - shift the camera to give illusion of table movement
	shift_camera(direction)
	
	# Print debug info
	if direction < 0:
		print("Table nudged left - applied force to balls")
	else:
		print("Table nudged right - applied force to balls")
	
	# Reset nudging flag after a short delay
	await get_tree().create_timer(0.2).timeout
	is_nudging = false

# Shift camera to create illusion of table movement
func shift_camera(direction):
	# Make sure we have a camera
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			print("Cannot find camera for nudge effect")
			return
	
	# Create a tween for smooth camera movement
	var tween = create_tween()
	
	# Store current position
	var start_pos = camera.position
	
	# Camera moves opposite to nudge direction to create table movement illusion
	var target_pos = start_pos + Vector2(-camera_offset * direction, 0)
	
	# Apply the camera movement
	tween.tween_property(camera, "position", target_pos, camera_shift_time)
	tween.tween_property(camera, "position", start_pos, camera_return_time)

# Handle tilt - now just disables controls until reset
func handle_tilt():
	is_tilted = true
	print("TILT! Controls disabled until ball respawns")
	
	# Emit signal to notify other components (flippers, etc.) of tilt state
	emit_signal("tilt_state_changed", true)
	
	# Reset nudging flag
	is_nudging = false

# Reset tilt state - to be called when the ball is respawned
func reset_tilt():
	if is_tilted:
		is_tilted = false
		tilt_count = 0
		tilt_decay_timer = 0
		print("Tilt reset - controls re-enabled")
		
		# Emit signal to notify other components of tilt state change
		emit_signal("tilt_state_changed", false)

# This function should be connected to the ball respawn event
func on_ball_respawned():
	reset_tilt()
