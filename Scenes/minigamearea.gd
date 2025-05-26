extends Area2D

# Current ball being pulled to the center
var captured_ball = null
var capture_center = Vector2.ZERO
var suction_complete = false
var suction_strength = 5000.0  # Much stronger suction force
var counter_gravity = 1000.0   # Force to counter gravity
var max_velocity = 500.0       # Maximum velocity cap

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the body_entered signal to our handler function
	body_entered.connect(_on_body_entered)
	
	# Store the center position of this area for suction effect
	capture_center = global_position
	
	# Disable physics process until needed
	set_physics_process(false)

# Called when a physics body enters this area
func _on_body_entered(body):
	# Check if the body that entered is a ball
	if body.is_in_group("balls") and not captured_ball and not suction_complete:
		print("Ball detected, capturing...")
		# Capture the ball reference
		captured_ball = body
		
		# Immediately counter current movement
		captured_ball.linear_velocity *= 0.3
		
		# Start the suction physics process
		set_physics_process(true)

# Called every physics frame while a ball is being sucked in
func _physics_process(delta):
	if captured_ball and not suction_complete:
		# Calculate direction vector from ball to center
		var direction = capture_center - captured_ball.global_position
		var distance = direction.length()
		
		print("Ball distance: ", distance, " Position: ", captured_ball.global_position)
		
		if distance < 5:  # Tighter tolerance
			# Ball has reached the center - stop moving and prepare for minigame
			captured_ball.linear_velocity = Vector2.ZERO
			captured_ball.angular_velocity = 0
			
			# Force position to exactly center to prevent drift
			captured_ball.global_position = capture_center
			
			# Mark suction as complete
			suction_complete = true
			
			# Store the final position for restoring later
			if not captured_ball.has_meta("original_position"):
				captured_ball.set_meta("original_position", captured_ball.global_position)
			
			print("Ball captured! Activating minigame...")
			
			# Proceed to minigame activation with a short delay
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(_activate_minigame)
			
			# Stop physics processing until next capture
			set_physics_process(false)
		else:
			# Set gravity scale to zero to prevent it from falling
			captured_ball.gravity_scale = 0
			
			# Apply suction force based on distance (stronger when closer)
			var suction_force = direction.normalized() * suction_strength
			
			# For very close distances, increase force dramatically for the final pull
			if distance < 30:
				suction_force *= 3.0
			
			# Apply upward force to counter gravity if the ball is below the center
			if captured_ball.global_position.y > capture_center.y:
				suction_force.y -= counter_gravity
			
			# Apply the force to pull the ball toward the center
			captured_ball.apply_central_force(suction_force)
			
			# Dampen velocity to prevent overshooting
			captured_ball.linear_velocity *= 0.95
			
			# Cap maximum velocity to prevent chaos
			if captured_ball.linear_velocity.length() > max_velocity:
				captured_ball.linear_velocity = captured_ball.linear_velocity.normalized() * max_velocity
			
			# If the ball somehow gets too far away, teleport it closer
			if distance > 500:
				var new_pos = captured_ball.global_position.move_toward(capture_center, distance - 300)
				captured_ball.global_position = new_pos
				captured_ball.linear_velocity = Vector2.ZERO

# Function to activate the minigame
func _activate_minigame():
	# Reset the capture state for next time
	suction_complete = false
	
	# Get the minigamewindow from the table scene
	var minigame_window = get_node("/root/Table/minigamewindow")
	if minigame_window:
		# Set process mode to ALWAYS
		minigame_window.process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Find and freeze all main table balls
		freeze_main_table_balls()
		
		# Use the activate method to properly set up the minigame
		minigame_window.activate()

# Freeze all balls in the main table to stop their movement
func freeze_main_table_balls():
	# Find all balls in the "balls" group
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		# Skip any minigameball - only freeze main table balls
		if ball.name != "minigameball":
			# Store current velocities before freezing (if not already stored)
			if not ball.has_meta("stored_linear_velocity"):
				ball.set_meta("stored_linear_velocity", ball.linear_velocity)
				ball.set_meta("stored_angular_velocity", ball.angular_velocity)
			
			# Reset gravity scale if it was changed
			ball.gravity_scale = 1.0
			
			# Freeze the ball's movement
			ball.freeze = true
			
	# Clear the captured ball reference now that it's frozen
	captured_ball = null
