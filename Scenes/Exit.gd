extends Area2D

# Resource references
var ball_scene_path = "res://Scenes/ball.tscn"
var ball_scene_resource: PackedScene
var plunger_scene_path = "res://Scenes/plunger.tscn"
var plunger_scene_resource: PackedScene

# Tracking original ball position
var spawn_position: Vector2 = Vector2(839, 1500)  # Position ball just below the plunger
var plunger_position: Vector2 = Vector2(840, 1440)  # Default plunger position

# Flag to prevent multiple respawns in a single physics frame
var is_respawning = false

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Exit area initialized!")
	
	# Make sure monitoring is enabled for the Area2D
	monitoring = true
	monitorable = true
	
	# Connect both entry and exit signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Connected body_entered signal")
	
	# Preload the ball scene for instantiation
	ball_scene_resource = load(ball_scene_path)
	if ball_scene_resource:
		print("Successfully loaded ball scene resource")
	else:
		push_error("Failed to load ball scene resource")
		return
	
	# Preload the plunger scene for reinstantiation if needed
	plunger_scene_resource = load(plunger_scene_path)
	if plunger_scene_resource:
		print("Successfully loaded plunger scene resource")
	else:
		push_error("Failed to load plunger scene resource")
	
	# Find existing plunger for position reference
	var plunger_node = get_node_or_null("../plunger")
	if plunger_node:
		plunger_position = plunger_node.global_position
		print("Found existing plunger at position: ", plunger_position)
	
	# We'll use a fixed spawn position to ensure consistency
	print("Using fixed ball spawn position: ", spawn_position)

# Called every frame - use this to ensure we detect balls that fall through
func _physics_process(_delta):
	# Skip if already respawning
	if is_respawning:
		return
	
	# Check for balls that have gone past the bottom of the screen
	var ball_nodes = get_tree().get_nodes_in_group("balls")
	for ball_node in ball_nodes:
		if ball_node is RigidBody2D:
			# If the ball is beyond the bottom of the screen, respawn it
			if ball_node.global_position.y > 1600:
				print("Ball detected below screen - respawning!")
				
				# Deactivate the guard when the ball goes off-screen
				reset_table()
				
				is_respawning = true
				# Since the ball is now the RigidBody2D itself rather than its parent
				call_deferred("replace_ball_and_plunger", ball_node)
				return

# Called when a physics body enters this area
func _on_body_entered(body):
	print("Body entered exit area: ", body.name, " at position ", body.global_position)
	
	# Avoid multiple respawns
	if is_respawning:
		return
	
	# Check if the entering body is a RigidBody2D (ball)
	if body is RigidBody2D and (body.is_in_group("balls") or body.name == "Ball"):
		print("Ball detected entering exit area!")
		
		# Deactivate the guard
		reset_table()
		
		is_respawning = true
		# Since the ball is now the RigidBody2D itself rather than its parent
		call_deferred("replace_ball_and_plunger", body)

# Function to replace both the ball and plunger
func replace_ball_and_plunger(old_ball: RigidBody2D):
	print("Attempting to replace ball and plunger")
	
	# Double-check we have everything we need
	if not ball_scene_resource:
		push_error("No ball scene resource available")
		is_respawning = false
		return
	
	if not old_ball:
		push_error("No old ball to replace")
		is_respawning = false
		return
	
	# Get reference to the table node to add our new objects
	var table = get_node_or_null("..")
	if not table:
		push_error("Could not find parent table node")
		is_respawning = false
		return
	
	# 1. Remove the old ball
	print("Removing old ball: ", old_ball.name)
	old_ball.queue_free()
	
	# 2. Remove the old plunger
	var old_plunger = get_node_or_null("../plunger")
	if old_plunger:
		print("Removing old plunger")
		plunger_position = old_plunger.global_position  # Save position before removing
		old_plunger.queue_free()
	else:
		print("No plunger found to replace")
	
	# Wait for a physics frame to ensure clean removal
	await get_tree().physics_frame
	
	# 3. Create a new plunger instance
	if plunger_scene_resource:
		var new_plunger = plunger_scene_resource.instantiate()
		if new_plunger:
			new_plunger.global_position = plunger_position
			print("Adding new plunger to scene at position: ", plunger_position)
			table.add_child(new_plunger)
			new_plunger.name = "plunger"
	
	# 4. Create the new ball instance
	var new_ball = ball_scene_resource.instantiate()
	if not new_ball:
		push_error("Failed to instantiate new ball")
		is_respawning = false
		return
	
	print("New ball instance created")
	
	# Position the ball just below the plunger
	spawn_position = Vector2(plunger_position.x, plunger_position.y - 200)
	print("Ball spawn position: ", spawn_position)
	
	# Set the position before adding to the scene tree
	new_ball.global_position = spawn_position
	
	# With the new structure, the ball is directly a RigidBody2D
	# Add to group and ensure physics properties are set
	new_ball.add_to_group("balls")
	new_ball.linear_velocity = Vector2.ZERO
	new_ball.angular_velocity = 0.0
	new_ball.sleeping = false
	
	# Explicitly set collision properties
	new_ball.collision_layer = 1
	new_ball.collision_mask = 1
	
	# Ensure continuous collision detection is enabled
	new_ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Get the ball sprite node
	var ball_sprite = new_ball.get_node_or_null("BallSprite")
	if ball_sprite:
		# Ensure sprite doesn't rotate with the physics body
		ball_sprite.rotation = 0
	
	print("Adding new ball to scene")
	# Add the new ball to the scene after the plunger is ready
	table.add_child(new_ball)
	new_ball.name = "ball"
	
	# Reset the flag after a short delay to prevent multiple respawns
	await get_tree().create_timer(0.5).timeout
	is_respawning = false
	
	# Debug output
	print("Ball and plunger replaced successfully")

# Function to deactivate all guards and reset the table
func reset_table():
	# Find and deactivate the main guard
	var guard_node = get_node_or_null("../Guard")
	if guard_node:
		# Disable the guard's collision and hide it
		var static_body = guard_node.get_node_or_null("StaticBody2D")
		if static_body:
			static_body.collision_layer = 0
			static_body.collision_mask = 0
			
			# Make the guard invisible
			var sprite = static_body.get_node_or_null("Sprite2D")
			if sprite:
				sprite.visible = false
				
			print("Main guard deactivated when ball exited")
	
	# Reset the Guardarea state if it has the activated flag
	var guard_area = get_node_or_null("../Guardarea")
	if guard_area and guard_area.has_method("deactivate_guard"):
		guard_area.deactivate_guard()
		print("Notified Guardarea that guard is deactivated")
		
	# Reset the gutterarea1 state
	var gutter_area1 = get_node_or_null("../gutterarea1")
	if gutter_area1 and gutter_area1.has_method("deactivate_guard"):
		gutter_area1.deactivate_guard()
		print("Reset gutterarea1 when ball exited")
	
	# Reset the gutterarea2 state
	var gutter_area2 = get_node_or_null("../gutterarea2")
	if gutter_area2 and gutter_area2.has_method("deactivate_guard"):
		gutter_area2.deactivate_guard()
		print("Reset gutterarea2 when ball exited")
	
	# Reset railareaentrance1, railareaentrance2, and railareaexit
	# Reset rail to its original state (half opacity, rail1 active and rail2 inactive)
	var rail_node = get_node_or_null("../rail")
	if rail_node:
		var sprite = rail_node.get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, 0.49)
			print("Reset rail sprite to half opacity (125/255)")
		
		var rail_exit = get_node_or_null("../railareaexit")
		if rail_exit and rail_exit.has_method("enable_rail1"):
			rail_exit.enable_rail1()
			print("Reset rail to default state (rail1 enabled, rail2 disabled)")
	
	# Reset all target sets in the game
	var target_nodes = []
	target_nodes.append(get_node_or_null("../targets1"))
	target_nodes.append(get_node_or_null("../targets2"))

	for targets_node in target_nodes:
		if targets_node:
			# Check if the targets node has the reset method
			if targets_node.has_method("reset_all_targets"):
				targets_node.reset_all_targets()
				print("Reset targets: " + targets_node.name + " when ball exited")
