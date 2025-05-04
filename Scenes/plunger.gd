extends Node2D

var plunger_body: RigidBody2D
var original_position: Vector2
var is_dragging: bool = false
var max_pull_distance: float = 100.0 
var spring_force: float = 10.0
var launch_force: float = 27.0  # Force multiplier for ball launch
var min_force_multiplier: float = 0.5  # Minimum force multiplier to prevent excessive force at max pull
var resetting_position: bool = false  # Flag to track when we're resetting position
var reset_timer: Timer  # Timer for handling position reset safely
var return_tween: Tween  # Tween for smoothly animating plunger return

# Called when the node enters the scene tree for the first time.
func _ready():
	plunger_body = $RigidBody2D
	original_position = plunger_body.position
	
	# Configure the plunger physics body
	plunger_body.mass = 5.0  # Heavier plunger
	plunger_body.collision_layer = 1  # Set collision layer
	plunger_body.collision_mask = 1  # Set collision mask
	
	# Strictly constrain movement to Y-axis only (prevents left/right drift)
	plunger_body.lock_rotation = true  # Prevent rotation
	# Set the freeze mode to better handle transitions between frozen/unfrozen
	plunger_body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	
	# Create a timer for reset sequence
	reset_timer = Timer.new()
	reset_timer.one_shot = true
	add_child(reset_timer)
	reset_timer.timeout.connect(_on_reset_timer_timeout)
	
	# Make sure the plunger sprite is always visible
	var sprite = $RigidBody2D/Sprite2D
	if sprite:
		sprite.visible = true
		print("Ensuring plunger sprite is visible")
	
	# Make plunger interactable
	set_process_input(true)
	
	# Debug plunger position
	print("Plunger initialized at position: ", global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_dragging:
		var mouse_pos = get_global_mouse_position()
		var local_mouse_pos = to_local(mouse_pos)
		var pull_vector = Vector2(0, local_mouse_pos.y - original_position.y)
		
		# Only allow vertical downward movement
		if pull_vector.y < 0:
			pull_vector.y = 0
		
		# Limit maximum pull distance
		if pull_vector.y > max_pull_distance:
			pull_vector.y = max_pull_distance
		
		plunger_body.position = original_position + pull_vector
	else:
		# Spring back to original position when not dragging and not frozen
		if not plunger_body.freeze and not return_tween:
			plunger_body.position = plunger_body.position.move_toward(original_position, spring_force)

# Added physics process to constrain X position and prevent lateral movement
func _physics_process(_delta):
	# Always enforce X position constraint to prevent lateral movement
	if not is_dragging and not plunger_body.freeze:
		# Force X position to stay at original X
		plunger_body.position.x = original_position.x

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if mouse is over plunger
				var mouse_pos = get_global_mouse_position()
				var plunger_rect = get_plunger_rect()
				
				if plunger_rect.has_point(to_local(mouse_pos)):
					is_dragging = true
					# Keep the physics from interfering while dragging
					plunger_body.freeze = true
					
					# Cancel any existing tween
					if return_tween:
						return_tween.kill()
						return_tween = null
			else:
				# Release plunger and apply force to the ball based on pull distance
				if is_dragging:
					is_dragging = false
					var pull_distance = plunger_body.position.y - original_position.y
					
					# Find the ball in the scene - try different methods
					launch_ball(pull_distance)
					
					# Ensure we cancel any previous reset sequence
					if reset_timer.is_stopped() == false:
						reset_timer.stop()
					
					# For strong pulls, use direct animation instead of physics
					if pull_distance > max_pull_distance * 0.1:
						# Disable physics and use tweening for smoother return
						plunger_body.freeze = true
						
						# Create a new tween for smooth animation
						return_tween = create_tween()
						return_tween.tween_property(plunger_body, "position", original_position, 0.1)
						return_tween.tween_callback(reset_plunger)
					else:
						# For gentler pulls, use a mild physics-based return
						var adjusted_pull = min(pull_distance, max_pull_distance * 0.5)
						var force_percent = adjusted_pull / max_pull_distance
						var force_multiplier = lerp(0.3, 0.5, force_percent)  # Reduced force multiplier
						var plunger_force = Vector2(0, -adjusted_pull * launch_force * 0.15 * force_multiplier)
						
						# Apply very gentle physics return for lower pulls
						resetting_position = true
						plunger_body.freeze = false
						plunger_body.linear_velocity = Vector2.ZERO
						plunger_body.apply_central_impulse(plunger_force)
						
						# Start a short timer for the reset sequence
						reset_timer.start(0.3)

# Timer callback to safely reset plunger position
func _on_reset_timer_timeout():
	reset_plunger()

# Public method to reset plunger state - called externally when ball respawns
func reset_plunger():
	# Force position back to original
	plunger_body.freeze = true
	plunger_body.linear_velocity = Vector2.ZERO
	plunger_body.position = original_position
	
	# Clear flags
	resetting_position = false
	is_dragging = false
	
	# Clear tween reference if it exists
	if return_tween:
		return_tween = null
	
	# Ensure collision is working by explicitly setting collision layers
	plunger_body.collision_layer = 1
	plunger_body.collision_mask = 1
	
	# Print debug info
	print("Plunger reset to original position: ", original_position)

# Function to launch the ball with force relative to plunger pull distance
func launch_ball(pull_distance: float):
	print("Attempting to launch ball with pull distance: ", pull_distance)
	
	# Find the ball to launch - look for ball in the plunger lane specifically
	var ball_to_launch = null
	var closest_distance = INF
	var max_horizontal_distance = 20.0  # Narrow horizontal tolerance
	var max_vertical_distance = 200.0  # Vertical distance above plunger
	var min_vertical_distance = -30.0   # Small tolerance below plunger
	
	# Get all balls in the game
	var all_balls = get_tree().get_nodes_in_group("balls")
	
	# Check each ball to find the one closest to the plunger in the correct lane
	for ball in all_balls:
		# Calculate distances
		var ball_position = ball.global_position
		var plunger_position = global_position
		var horizontal_distance = abs(ball_position.x - plunger_position.x)
		var vertical_distance = ball_position.y - plunger_position.y
		
		# Only consider balls in the plunger lane
		if horizontal_distance <= max_horizontal_distance and vertical_distance <= max_vertical_distance and vertical_distance >= min_vertical_distance:
			# Calculate total distance (prioritize balls directly above plunger)
			var total_distance = horizontal_distance + abs(vertical_distance)
			
			# Pick the closest ball
			if total_distance < closest_distance:
				closest_distance = total_distance
				ball_to_launch = ball
				print("Found ball in plunger lane: ", ball.name, " distance: ", total_distance)
	
	# Launch the selected ball if one was found
	if ball_to_launch != null:
		print("Launching ball from plunger lane!")
		
		# Apply a non-linear curve to the force to prevent excessive force at max pull
		var force_percent = pull_distance / max_pull_distance
		
		# Cap the force if it's at maximum pull distance (prevents physics glitches)
		if force_percent > 0.85:
			# Apply a diminishing returns curve to prevent extreme forces
			force_percent = 0.85 + (0.15 * (force_percent - 0.85) / 0.15)
		
		# Calculate launch force based on adjusted pull distance
		var adjusted_force = min(pull_distance * launch_force, max_pull_distance * launch_force * 0.9)
		var force = Vector2(0, -adjusted_force)
		
		# Apply impulse to the ball - use central_impulse for better physics
		ball_to_launch.apply_central_impulse(force)
		print("Applied vertical impulse: ", force)
		
		# Ensure the ball is not sleeping
		ball_to_launch.sleeping = false
	else:
		print("No ball found in plunger lane to launch")

# Helper function to get the plunger's rectangle for hit detection
func get_plunger_rect() -> Rect2:
	var sprite = $RigidBody2D/Sprite2D
	if sprite:
		var size = Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale
		var global_pos = plunger_body.global_position
		var local_pos = to_local(global_pos)
		
		return Rect2(
			local_pos - size/2,
			size
		)
	
	# Fallback rectangle if sprite can't be found
	return Rect2(plunger_body.position - Vector2(20, 80), Vector2(40, 160))
