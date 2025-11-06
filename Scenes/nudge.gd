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
var nudge_enabled = true:  # Can be toggled from settings
	set(value):
		nudge_enabled = value
		print("Nudge.gd: nudge_enabled changed to ", value)

# Touch gesture tracking for two-finger drags
var active_touches: Dictionary = {}  # Maps touch index to position
var gesture_start_positions: Dictionary = {}  # Starting positions of the gesture
var gesture_active: bool = false
var gesture_applied: bool = false  # Prevent multiple nudges per gesture
var min_drag_distance: float = 50.0  # Minimum drag distance to trigger nudge

var TILT_sound = preload("res://Assets/sounds/TILT.wav")

# References
@onready var camera = get_viewport().get_camera_2d()
@onready var hamburger_menu_button = get_node("ScoreboardUI/HamburgerMenuButton")
@onready var pause_menu_ui = get_node("PauseMenuUI")

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

	# Initialize nudge_enabled from global settings
	nudge_enabled = GameSettings.nudge_enabled
	print("Nudge system initialized - nudge enabled: ", nudge_enabled)

	# Play table music when scene starts
	AudioCollection.select_random_track()
	AudioCollection.play_current_track()

	# Connect hamburger menu button
	if hamburger_menu_button:
		hamburger_menu_button.pressed.connect(_on_hamburger_menu_pressed)

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

	# Process two-finger gesture if active
	if gesture_active and active_touches.size() == 2 and not gesture_applied:
		check_gesture_direction()

	# Handle input if not currently nudging, not tilted, nudge is enabled, and cooldown has expired
	if !is_nudging and !is_tilted and nudge_cooldown <= 0:
		# Check if nudge is enabled before processing input
		if not nudge_enabled:
			return  # Exit early if nudge is disabled

		# Check left arrow key for left nudge
		if Input.is_physical_key_pressed(KEY_LEFT):
			apply_nudge(NudgeDirection.LEFT)  # Nudge left
		# Check right arrow key for right nudge
		elif Input.is_physical_key_pressed(KEY_RIGHT):
			apply_nudge(NudgeDirection.RIGHT)  # Nudge right
		# Check up arrow key for up nudge
		elif Input.is_physical_key_pressed(KEY_UP):
			apply_nudge(NudgeDirection.UP)  # Nudge up

# Handle touch input for two-finger gestures
func _input(event):
	if not nudge_enabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# Touch started
			active_touches[event.index] = event.position

			# If exactly 2 touches are active, start gesture tracking
			if active_touches.size() == 2:
				gesture_start_positions = active_touches.duplicate()
				gesture_active = true
				gesture_applied = false
		else:
			# Touch ended
			active_touches.erase(event.index)

			# If we no longer have 2 touches, end gesture
			if active_touches.size() != 2:
				gesture_active = false
				gesture_applied = false
				gesture_start_positions.clear()

	elif event is InputEventScreenDrag:
		# Update touch position during drag
		if event.index in active_touches:
			active_touches[event.index] = event.position

# Check if the two-finger gesture has moved far enough in a direction
func check_gesture_direction():
	if not gesture_active or gesture_applied or is_nudging or is_tilted or nudge_cooldown > 0:
		return

	# Calculate average movement from start positions
	var total_movement = Vector2.ZERO
	var touch_count = 0

	for index in active_touches.keys():
		if index in gesture_start_positions:
			var start_pos = gesture_start_positions[index]
			var current_pos = active_touches[index]
			total_movement += current_pos - start_pos
			touch_count += 1

	if touch_count == 0:
		return

	var avg_movement = total_movement / touch_count

	# Check if movement exceeds minimum threshold
	if avg_movement.length() < min_drag_distance:
		return

	# Determine direction based on the dominant axis
	var abs_x = abs(avg_movement.x)
	var abs_y = abs(avg_movement.y)

	# Check for horizontal drag (left or right)
	if abs_x > abs_y:
		if avg_movement.x < 0:
			# Drag left
			apply_nudge(NudgeDirection.LEFT)
			gesture_applied = true
		else:
			# Drag right
			apply_nudge(NudgeDirection.RIGHT)
			gesture_applied = true
	else:
		# Vertical drag - only trigger on upward drag
		if avg_movement.y < 0:
			# Drag up
			apply_nudge(NudgeDirection.UP)
			gesture_applied = true

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
	
	# Reset nudging flag after a short delay
	await get_tree().create_timer(0.2).timeout
	is_nudging = false

# Shift camera to create illusion of table movement
func shift_camera(direction):
	# Make sure we have a camera
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
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

	AudioCollection.play_sfx(TILT_sound)
	
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
		
		# Emit signal to notify other components of tilt state change
		emit_signal("tilt_state_changed", false)

# This function should be connected to the ball respawn event
func on_ball_respawned():
	reset_tilt()

# Handle hamburger menu button press
func _on_hamburger_menu_pressed():
	if pause_menu_ui and not get_tree().paused:
		pause_menu_ui.show_pause_menu()
