extends Node2D

# Configuration for nudge effect
var nudge_force = 400.0  # Horizontal force to apply to balls
var nudge_vertical_force = 200.0  # Small vertical force to combine with horizontal
var up_nudge_force = 400.0  # Stronger upward force for up nudge
var tilt_eject_force = 2000.0  # Very strong force to eject the ball from launch lane on tilt
var camera_offset = 15.0  # Distance to shift camera
var camera_shift_time = 0.1  # Time to shift camera
var camera_return_time = 0.2  # Time to return camera
var cooldown_duration = 0.5  # Time before allowing another nudge
var tilt_threshold = 5  # Number of nudges before tilt warning
var tilt_limit = 8  # Number of nudges before tilt (game over)
var tilt_decay_time = 10.0  # Time for tilt count to decrease by 1

# Launch lane approximate boundaries for detection
var launch_lane_x_min = 820.0
var launch_lane_x_max = 860.0
var launch_lane_y_min = 800.0  # Upper part of launch lane
var launch_lane_y_max = 1600.0  # Lower part of launch lane

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

# Nudge directions
enum NudgeDirection {
	LEFT = -1,
	RIGHT = 1,
	UP = 2
}

func _ready():
	# Add to group so flippers can find it
	add_to_group("nudge_system")
	print("Nudge system initialized - use LEFT/RIGHT/UP ARROW keys for nudging")

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
			apply_nudge(NudgeDirection.LEFT)  # Nudge left
		# Check right arrow key for right nudge
		elif Input.is_physical_key_pressed(KEY_RIGHT): 
			apply_nudge(NudgeDirection.RIGHT)  # Nudge right
		# Check up arrow key for up nudge
		elif Input.is_physical_key_pressed(KEY_UP):
			apply_nudge(NudgeDirection.UP)  # Nudge up

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
			var impulse = Vector2.ZERO
			
			# Apply different impulses based on direction
			if direction == NudgeDirection.UP:
				# For upward nudge, apply strong vertical force
				impulse = Vector2(0, -up_nudge_force)
			else:
				# For left/right nudges, apply horizontal force with a small upward component
				impulse = Vector2(nudge_force * direction, -nudge_vertical_force)
				
			ball.apply_impulse(impulse)
	
	# Visual feedback - shift the camera to give illusion of table movement
	shift_camera(direction)
	
	# Print debug info
	match direction:
		NudgeDirection.LEFT:
			print("Table nudged left - applied force to balls")
		NudgeDirection.RIGHT:
			print("Table nudged right - applied force to balls")
		NudgeDirection.UP:
			print("Table nudged up - applied upward force to balls")
	
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
	var target_pos = start_pos
	
	# Calculate target position based on direction
	match direction:
		NudgeDirection.LEFT, NudgeDirection.RIGHT:
			# Left/right nudge - move camera horizontally
			target_pos = start_pos + Vector2(-camera_offset * direction, 0)
		NudgeDirection.UP:
			# Up nudge - move camera vertically
			target_pos = start_pos + Vector2(0, camera_offset)
	
	# Apply the camera movement
	tween.tween_property(camera, "position", target_pos, camera_shift_time)
	tween.tween_property(camera, "position", start_pos, camera_return_time)

# Check if a ball is in the launch lane based on its position
func is_ball_in_launch_lane(ball_position: Vector2) -> bool:
	return (ball_position.x >= launch_lane_x_min and 
			ball_position.x <= launch_lane_x_max and 
			ball_position.y >= launch_lane_y_min and 
			ball_position.y <= launch_lane_y_max)

# Eject balls from the launch lane when the table is tilted
func eject_balls_from_launch_lane():
	var balls = get_tree().get_nodes_in_group("balls")
	var ejected_count = 0
	
	for ball in balls:
		if is_instance_valid(ball) and ball is RigidBody2D:
			# Check if the ball is in the launch lane
			if is_ball_in_launch_lane(ball.global_position):
				# Apply a strong upward force to eject it
				var eject_impulse = Vector2(0, -tilt_eject_force)
				ball.apply_impulse(eject_impulse)
				ejected_count += 1
				print("Ball ejected from launch lane due to tilt!")
	
	if ejected_count > 0:
		# Create a visual shake effect for the ejection
		shake_camera(NudgeDirection.UP, 1.5)  # Stronger shake for ejection

# More dramatic camera shake for ball ejection
func shake_camera(direction, intensity = 1.0):
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
			
	var tween = create_tween()
	var start_pos = camera.position
	var target_pos
	
	# Calculate target position based on direction
	match direction:
		NudgeDirection.LEFT, NudgeDirection.RIGHT:
			target_pos = start_pos + Vector2(-camera_offset * direction * intensity, 0)
		NudgeDirection.UP:
			target_pos = start_pos + Vector2(0, camera_offset * intensity)
	
	# Create a more dramatic shake effect with multiple movements
	tween.tween_property(camera, "position", target_pos, camera_shift_time * 0.5)
	tween.tween_property(camera, "position", start_pos, camera_return_time * 0.5)
	tween.tween_property(camera, "position", target_pos * 0.7, camera_shift_time * 0.3)
	tween.tween_property(camera, "position", start_pos, camera_return_time * 0.3)

# Handle tilt - now just disables controls until reset
func handle_tilt():
	is_tilted = true
	print("TILT! Controls disabled until ball respawns")
	
	# Eject any balls from the launch lane
	eject_balls_from_launch_lane()
	
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
