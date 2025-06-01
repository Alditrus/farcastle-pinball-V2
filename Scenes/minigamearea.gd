extends Area2D

# Current ball being pulled to the center
var captured_ball = null
var capture_center = Vector2.ZERO
var suction_complete = false
var suction_strength = 5000.0  # Much stronger suction force
var counter_gravity = 1000.0   # Force to counter gravity
var max_velocity = 500.0       # Maximum velocity cap

# Animation parameters
var fade_duration = 1.0        # Duration of fade/shrink animation
var is_fading = false          # Whether we're currently fading
var original_scale = Vector2.ONE # Original scale of the ball sprite
var original_modulate = Color.WHITE # Original modulate of the ball sprite
var fade_progress = 0.0        # Current animation progress

# Fade timer
var fade_timer = null

# Cooling down period after a ball has been ejected
var cooldown_active = false
var cooldown_duration = 3.0  # seconds
var cooldown_timer = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Add to a group for easy reference
	add_to_group("minigame_areas")
	
	# Connect the body_entered signal to our handler function
	body_entered.connect(_on_body_entered)
	
	# Store the center position of this area for suction effect
	capture_center = global_position
	
	# Create a timer for the fade animation
	fade_timer = Timer.new()
	fade_timer.one_shot = false
	fade_timer.wait_time = 0.03  # Update approximately 30 times per second
	fade_timer.timeout.connect(_on_fade_timer_timeout)
	add_child(fade_timer)
	
	# Create a cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = cooldown_duration
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	
	# Disable physics process until needed
	set_physics_process(false)

# Called when a physics body enters this area
func _on_body_entered(body):
	# Check if the body that entered is a ball
	if body.is_in_group("balls") and not captured_ball and not suction_complete and not cooldown_active:
		# Capture the ball reference
		captured_ball = body
		
		# Find the ball sprite and verify we can access it
		var ball_sprite = captured_ball.get_node_or_null("BallSprite")
		if ball_sprite:
			# Store original appearance
			original_scale = ball_sprite.scale
			original_modulate = ball_sprite.modulate
			
			# Force full opacity to start
			ball_sprite.modulate = Color(1, 1, 1, 1)
			
			# Store these for restoration later
			captured_ball.set_meta("original_scale", original_scale)
			captured_ball.set_meta("original_modulate", original_modulate)
		
		# Hide the trail particles
		var particles = captured_ball.get_node_or_null("CPUParticles2D")
		if particles:
			# Store the original visibility state
			captured_ball.set_meta("original_particles_visible", particles.visible)
			# Hide the particles
			particles.visible = false
		
		# Immediately counter current movement
		captured_ball.linear_velocity *= 0.3
		
		# Start the suction physics process
		set_physics_process(true)

# Called when the cooldown timer expires
func _on_cooldown_timeout():
	cooldown_active = false
	print("Minigame area cooldown finished - ready for next ball")

# Called every physics frame while a ball is being sucked in
func _physics_process(delta):
	if captured_ball and not suction_complete:
		# Calculate direction vector from ball to center
		var direction = capture_center - captured_ball.global_position
		var distance = direction.length()
		
		if distance < 5 and not is_fading:  # Ball reached center, start fade animation
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
			
			# Reset fade progress
			fade_progress = 0.0
			
			# Make sure ball is visible before fading
			var ball_sprite = captured_ball.get_node_or_null("BallSprite")
			if ball_sprite:
				ball_sprite.visible = true
				ball_sprite.modulate = Color(1, 1, 1, 1)  # Full opacity
			
			# Start the fade animation with timer instead of physics process
			is_fading = true
			fade_timer.start()
			
			# Stop physics processing
			set_physics_process(false)
		
		else:
			# Still moving toward center
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

# Called when the fade timer fires
func _on_fade_timer_timeout():
	if not is_fading or not captured_ball:
		fade_timer.stop()
		return
		
	# Update fade progress
	fade_progress += fade_timer.wait_time / fade_duration
	fade_progress = min(fade_progress, 1.0)
	
	# Get the sprite
	var ball_sprite = captured_ball.get_node_or_null("BallSprite")
	if ball_sprite:
		# Fade out (reduce opacity)
		var new_alpha = 1.0 - fade_progress
		ball_sprite.modulate = Color(1, 1, 1, new_alpha)  # Set full color with fading alpha
		
		# Shrink slightly (to 80% of original size)
		var target_scale = original_scale * (1.0 - (0.2 * fade_progress))
		ball_sprite.scale = target_scale
		
		# If the fade is complete, activate the minigame
		if fade_progress >= 1.0:
			# Stop the fade timer
			fade_timer.stop()
			
			# Reset fade state for next time
			is_fading = false
			
			# Proceed to minigame activation with a short delay
			var minigame_timer = get_tree().create_timer(0.2)
			minigame_timer.timeout.connect(_activate_minigame)

# Function to activate the minigame
func _activate_minigame():
	# Reset the capture state for next time
	suction_complete = false
	
	# Hide the ball completely
	if captured_ball and captured_ball.get_node("BallSprite"):
		captured_ball.get_node("BallSprite").visible = false
	
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

# Animation parameters for appearance restoration
var restore_duration = 0.5  # Duration for fade-in animation

# Function to restore a ball's appearance - called from jackpot.gd and floormultipliers.gd
func _restore_ball_appearance_impl(ball):
	if ball:
		# IMPORTANT: First check if this is the captured ball
		var was_captured = ball.has_meta("original_position")
		
		# Restore visual appearance
		var ball_sprite = ball.get_node_or_null("BallSprite")
		if ball_sprite:
			# Make the sprite visible again
			ball_sprite.visible = true
			
			# Restore original scale if stored
			if ball.has_meta("original_scale"):
				ball_sprite.scale = ball.get_meta("original_scale")
				ball.remove_meta("original_scale")

			# Restore original modulate if stored
			if ball.has_meta("original_modulate"):
				ball_sprite.modulate = ball.get_meta("original_modulate")
				ball.remove_meta("original_modulate")
			else:
				# Default to fully opaque white if no original stored
				ball_sprite.modulate = Color(1, 1, 1, 1)

		# Restore trail particles visibility if they exist
		var particles = ball.get_node_or_null("CPUParticles2D")
		if particles:
			if ball.has_meta("original_particles_visible"):
				particles.visible = ball.get_meta("original_particles_visible")
				ball.remove_meta("original_particles_visible")
			else:
				# Default to visible if no original state stored
				particles.visible = true
				
		# Return a special callback for the captured ball
		if was_captured:
			return func():
				print("Preparing to eject captured ball")
				
				# The callback needs to immediately unfreeze the ball to allow physics to work
				ball.freeze = false
				
				# Position the ball at its original position
				if ball.has_meta("original_position"):
					print("Repositioning ball to:", ball.get_meta("original_position"))
					ball.global_position = ball.get_meta("original_position")
					ball.remove_meta("original_position")
				
				# Reset the ball's properties to ensure clean state
				ball.gravity_scale = 1.0
				
				# Calculate random angle in the upward hemisphere (between -60 and -120 degrees)
				var angle = randf_range(-PI/3, -2*PI/3)
				var launch_direction = Vector2(cos(angle), sin(angle))
				
				# Apply strong launch force
				var launch_force = 500.0  # Increased for more dramatic effect
				print("Applying velocity:", launch_direction * launch_force)
				
				# We need to use this approach because linear_velocity might be ignored if the ball is frozen
				ball.linear_velocity = Vector2.ZERO  # Reset first
				ball.apply_central_impulse(launch_direction * launch_force)
				
				# Apply spin (higher value for more noticeable spin)
				var spin = randf_range(8.0, 15.0) * (1 if randf() > 0.5 else -1)
				print("Applying spin:", spin)
				ball.angular_velocity = spin
				
				# Use apply_torque_impulse for more reliable spin
				ball.apply_torque_impulse(spin * 1000)
				
				# Activate cooldown to prevent immediate re-capture
				cooldown_active = true
				if cooldown_timer:
					cooldown_timer.start(cooldown_duration)
					print("Starting minigame area cooldown for " + str(cooldown_duration) + " seconds")
				
				# Reset state variables
				suction_complete = false
				captured_ball = null
				
				# Pause briefly to let physics system process this
				await ball.get_tree().create_timer(0.05).timeout
				return true
		
		# For balls that were not captured, return a simple callback
		return func():
			return true
			
# Static wrapper for the instance method to maintain compatibility with existing code
static func restore_ball_appearance(ball):
	# Find all minigamearea instances in the scene
	var areas = ball.get_tree().get_nodes_in_group("minigame_areas")
	if areas.size() > 0:
		# Use the first one found
		var area = areas[0]
		return area._restore_ball_appearance_impl(ball)
	else:
		# Fallback to a simple callback if no areas found
		return func():
			return true
