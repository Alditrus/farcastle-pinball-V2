extends Node2D

# Track how many targets are currently down
var targets_down_count = 0
var total_targets = 3
# Dictionary to track which targets have been hit
var hit_targets = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Targets script initialized")
	call_deferred("reset_all_targets")

# Reset all targets to their original state
func reset_all_targets():
	targets_down_count = 0
	hit_targets.clear()  # Reset the hit targets tracking
	print("Resetting all targets")
	
	for i in range(1, 4):
		var target_path = "target" + str(i)
		var target = get_node_or_null(target_path)
		if target:
			# Enable the "up" sprite
			var up_sprite = target.get_node_or_null("up")
			if up_sprite:
				up_sprite.visible = true
			
			# Enable the collision - using set_deferred to avoid errors
			var collision = target.get_node_or_null("CollisionShape2D")
			if collision:
				collision.set_deferred("disabled", false)
			
			# Queue free any existing detection area
			var existing_area = target.get_node_or_null("DetectionArea")
			if existing_area:
				existing_area.queue_free()
		else:
			print("ERROR: Could not find " + target_path)
	
	# Setup collision areas after reset - using call_deferred to avoid errors
	call_deferred("setup_target_areas")

# Set up area2D nodes to detect ball collisions for each target
func setup_target_areas():
	for i in range(1, 4):
		var target_path = "target" + str(i)
		print("Setting up collision area for " + target_path)
		
		var target = get_node_or_null(target_path)
		if target:
			# First check if an Area2D already exists and remove it
			var existing_area = target.get_node_or_null("DetectionArea")
			if existing_area:
				existing_area.queue_free()
				# Wait until freed before continuing
				await get_tree().process_frame
				
			# Create an Area2D for each target to detect collisions
			var area = Area2D.new()
			area.name = "DetectionArea"
			target.add_child(area)
			
			# Copy the collision shape from the target
			var target_collision = target.get_node_or_null("CollisionShape2D")
			if target_collision:
				var area_collision = CollisionShape2D.new()
				area_collision.shape = target_collision.shape.duplicate()
				# Position must match the original collision
				area_collision.position = target_collision.position
				area.add_child(area_collision)
				
				# Use set_deferred to enable monitoring and monitorable
				area.set_deferred("monitoring", true)
				area.set_deferred("monitorable", true)
				
				# Connect the body entered signal
				print("Connecting body_entered signal for " + target_path)
				
				# Use a lambda function to ensure we only process the specific target
				area.body_entered.connect(
					func(body): 
						_on_specific_area_entered(body, target)
				)
			else:
				print("ERROR: Could not find CollisionShape2D for " + target_path)
		else:
			print("ERROR: Could not find " + target_path)

# Called when a body enters a specific target's area
func _on_specific_area_entered(body, target):
	print("Target area entered - Body: " + body.name + ", Target: " + target.name)
	
	# Check if the colliding body is a ball and the target hasn't been hit already
	if (body.is_in_group("balls") or body.name == "Ball") and not hit_targets.has(target.get_path()):
		print("Ball confirmed hit on target: " + target.name)
		call_deferred("target_down", target)

# Function to turn up sprite invisible
func target_down(target_node):
	if target_node != null:
		print("Processing target_down for: " + target_node.name)
		
		# Mark this target as hit
		hit_targets[target_node.get_path()] = true
		
		# Get the "up" sprite and make it invisible
		var up_sprite = target_node.get_node_or_null("up")
		if up_sprite:
			up_sprite.visible = false
			print("Hidden up sprite for " + target_node.name)
		else:
			print("ERROR: Could not find 'up' sprite for " + target_node.name)
		
		# Disable the collision for this target - using set_deferred to avoid errors
		var collision = target_node.get_node_or_null("CollisionShape2D")
		if collision:
			# Use set_deferred to change collision state safely during signal processing
			collision.set_deferred("disabled", true)
			print("Disabled collision for " + target_node.name)
		
		# Increment targets down counter
		targets_down_count += 1
		print("Targets down: " + str(targets_down_count) + "/" + str(total_targets))
		
		# Check if all targets are down
		call_deferred("check_all_targets_down")

# Check if all targets are down and reset if needed
func check_all_targets_down():
	if targets_down_count >= total_targets:
		print("All targets are down! Resetting in 1 second...")
		
		# Create a timer to delay the reset
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = 1.0
		add_child(timer)
		timer.timeout.connect(func(): 
			call_deferred("reset_all_targets")
			timer.queue_free()
		)
		timer.start()
