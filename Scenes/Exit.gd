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

# Signal for ball respawn events
signal ball_respawned

func _ready():
	print("Exit area initialized!")
	
	# Make sure monitoring is enabled for the Area2D
	monitoring = true
	monitorable = true
	
	# Set Area2D to be on all collision layers (32 layers, each bit represents a layer)
	collision_layer = 0xFFFFFFFF  # All 32 bits set to 1
	collision_mask = 0xFFFFFFFF   # Detect collisions on all layers
	
	# Preload the ball scene for instantiation
	ball_scene_resource = load(ball_scene_path)
	if not ball_scene_resource:
		push_error("Failed to load ball scene resource")
		return
	
	# Preload the plunger scene for reinstantiation if needed
	plunger_scene_resource = load(plunger_scene_path)
	if not plunger_scene_resource:
		push_error("Failed to load plunger scene resource")
	
	# Find existing plunger for position reference
	var plunger_node = get_node_or_null("../plunger")
	if plunger_node:
		plunger_position = plunger_node.global_position

func _physics_process(_delta):
	if not is_respawning:
		var overlapping_balls = 0
		
		# Count how many balls are in the exit area
		var overlapping_bodies = get_overlapping_bodies()
		for body in overlapping_bodies:
			if body is RigidBody2D and body.is_in_group("balls"):
				overlapping_balls += 1
		
		# Get all balls in the game
		var ball_nodes = get_tree().get_nodes_in_group("balls")
		
		# Only reset if there are no balls in the exit area and balls exist elsewhere
		if overlapping_balls == 0 and ball_nodes.size() > 0:
			reset_table()
			is_respawning = true
			call_deferred("replace_ball_and_plunger", ball_nodes[0])

# Function to replace both the ball and plunger
func replace_ball_and_plunger(old_ball: RigidBody2D):
	# Get reference to the table node to add our new objects
	var table = get_node_or_null("..")
	if not table:
		push_error("Could not find parent table node")
		is_respawning = false
		return
	
	# 1. Remove the old ball
	old_ball.queue_free()
	
	# 2. Remove the old plunger
	var old_plunger = get_node_or_null("../plunger")
	if old_plunger:
		plunger_position = old_plunger.global_position  # Save position before removing
		old_plunger.queue_free()
	
	# Wait for a physics frame to ensure clean removal
	await get_tree().physics_frame
	
	# 3. Create a new plunger instance
	if plunger_scene_resource:
		var new_plunger = plunger_scene_resource.instantiate()
		if new_plunger:
			new_plunger.global_position = plunger_position
			table.add_child(new_plunger)
			new_plunger.name = "plunger"
	
	# 4. Create the new ball instance
	var new_ball = ball_scene_resource.instantiate()
	if not new_ball:
		push_error("Failed to instantiate new ball")
		is_respawning = false
		return
	
	# Position the ball just below the plunger
	spawn_position = Vector2(plunger_position.x, plunger_position.y - 200)
	
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
	
	# Add the new ball to the scene after the plunger is ready
	table.add_child(new_ball)
	new_ball.name = "ball"
	
	# Notify any systems that need to know about ball respawn
	notify_ball_respawn()
	
	# Reset the flag after a short delay to prevent multiple respawns
	await get_tree().create_timer(0.5).timeout
	is_respawning = false

# Function to notify all systems about ball respawn
func notify_ball_respawn():
	# Emit our own signal
	emit_signal("ball_respawned")
	
	# Directly notify nudge systems
	var nudge_nodes = get_tree().get_nodes_in_group("nudge_system")
	for nudge in nudge_nodes:
		if nudge.has_method("on_ball_respawned"):
			nudge.on_ball_respawned()
			print("Notified nudge system of ball respawn")

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
	
	# Reset the Guardarea state if it has the activated flag
	var guard_area = get_node_or_null("../Guardarea")
	if guard_area and guard_area.has_method("deactivate_guard"):
		guard_area.deactivate_guard()
	
	# Reset the gutterarea1 state
	var gutter_area1 = get_node_or_null("../gutterarea1")
	if gutter_area1 and gutter_area1.has_method("deactivate_guard"):
		gutter_area1.deactivate_guard()
	
	# Reset the gutterarea2 state
	var gutter_area2 = get_node_or_null("../gutterarea2")
	if gutter_area2 and gutter_area2.has_method("deactivate_guard"):
		gutter_area2.deactivate_guard()
	
	# Reset railareaentrance1, railareaentrance2, and railareaexit
	# Reset rail to its original state (half opacity, rail1 active and rail2 inactive)
	var rail_node = get_node_or_null("../rail")
	if rail_node:
		var sprite = rail_node.get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, 0.49)
		
		var rail_exit = get_node_or_null("../railareaexit")
		if rail_exit and rail_exit.has_method("enable_rail1"):
			rail_exit.enable_rail1()
	
	# Reset all target sets in the game
	var target_nodes = []
	target_nodes.append(get_node_or_null("../targets"))  # First instance is named "targets" (without a number)
	target_nodes.append(get_node_or_null("../targets2"))

	for targets_node in target_nodes:
		if targets_node:
			# Check if the targets node has the reset method
			if targets_node.has_method("reset_all_targets"):
				targets_node.reset_all_targets()
				
	# Reset tilt state if table is tilted
	var nudge_nodes = get_tree().get_nodes_in_group("nudge_system")
	for nudge in nudge_nodes:
		if nudge.has_method("reset_tilt"):
			nudge.reset_tilt()
			print("Tilt state has been reset from Exit.gd")
