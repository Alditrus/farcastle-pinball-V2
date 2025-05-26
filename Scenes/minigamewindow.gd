extends SubViewportContainer

var initialized = false
var main_game_paused = false

func _ready():
	# Start disabled
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	
	# Get the SubViewport
	var viewport = $SubViewport
	if viewport == null:
		viewport = SubViewport.new()
		viewport.name = "SubViewport"
		add_child(viewport)
		
	# Set viewport properties - critical for physics to work
	viewport.size = Vector2(700, 1270)  # Match the minigame size
	viewport.handle_input_locally = true
	viewport.physics_object_picking = true
	viewport.audio_listener_enable_2d = true
	viewport.physics_object_picking_sort = true  # Important for physics interactions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	
	# Load and instance the minigame scene
	var minigame_scene = load("res://Scenes/minigame.tscn")
	var minigame_instance = minigame_scene.instantiate()
	
	# Set the proper name to match the original scene
	minigame_instance.name = "Minigame"
	minigame_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add minigame to the viewport
	viewport.add_child(minigame_instance)
	
	# Check for the ball in the instanced scene
	var ball = minigame_instance.get_node_or_null("minigameball")
	if not ball:
		ball = minigame_instance.get_node_or_null("ball")
		if ball:
			# Rename the node to match what goathead.gd is looking for
			ball.name = "minigameball"
	
	initialized = true

# Override _process to ensure constant updates
func _process(_delta):
	if visible and initialized:
		# Ensure the viewport is constantly updating
		if $SubViewport:
			$SubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			
			# Check if we need to reset the ball
			var minigame = $SubViewport.get_node_or_null("Minigame")
			if minigame:
				var ball = minigame.get_node_or_null("minigameball")
				if ball and ball.position.y > 3500:
					# Ball fell out of bounds, reset it
					# Find the goathead and reset the ball
					var goat_head = minigame.get_node_or_null("GoatHead")
					if goat_head:
						# Reset has_been_dragged flag so the user needs to drag again
						goat_head.has_been_dragged = false
						
						# Hide and freeze the ball until dragged again
						ball.visible = false
						ball.freeze = true
						
						# Position at spawn point
						var spawn_area = goat_head.get_node_or_null("SpawnArea")
						if spawn_area:
							ball.global_position = spawn_area.global_position

# Override _input to ensure input events are properly processed
func _input(event):
	if visible and (process_mode == Node.PROCESS_MODE_INHERIT or process_mode == Node.PROCESS_MODE_ALWAYS):
		# Forward input to the viewport when active
		if event is InputEventMouse:
			# Convert mouse position to local coordinates
			var local_event = event.duplicate()
			local_event.position = get_local_mouse_position()
			$SubViewport.push_input(local_event)
		elif event is InputEventKey:
			# Also forward keyboard events
			$SubViewport.push_input(event)

# Function to activate the minigame
func activate():
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS  # Use ALWAYS to ensure it runs regardless of tree paused state
	
	# Make sure viewport is active and updating
	if $SubViewport:
		$SubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		$SubViewport.process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Ensure the Minigame scene is set to always process
		var minigame = $SubViewport.get_node_or_null("Minigame")
		if minigame:
			minigame.process_mode = Node.PROCESS_MODE_ALWAYS
			
			# Reset the goathead and ball state
			var ball = minigame.get_node_or_null("minigameball")
			var goat_head = minigame.get_node_or_null("GoatHead")
			
			if ball:
				# Initialize ball as hidden and frozen until dragged
				ball.visible = false
				ball.freeze = true
				ball.sleeping = true
				
				# Reset velocity
				ball.linear_velocity = Vector2.ZERO
				
				# Make sure it's at the spawn position
				if goat_head:
					var spawn_area = goat_head.get_node_or_null("SpawnArea")
					if spawn_area:
						ball.global_position = spawn_area.global_position
			
			# Reset the goathead state
			if goat_head:
				goat_head.has_been_dragged = false
				# Reset to initial position
				goat_head.position.x = goat_head.initial_position.x

# Function to deactivate and return to main game
func deactivate():
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
