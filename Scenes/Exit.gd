extends Area2D

# Resource references
var ball_scene_path = "res://Scenes/ball.tscn"
var ball_scene_resource: PackedScene
var plunger_scene_path = "res://Scenes/plunger.tscn"
var plunger_scene_resource: PackedScene

var respawn_sound = preload("res://Assets/sounds/respawn.wav")

# Tracking original ball position
var spawn_position: Vector2 = Vector2(839, 1500)  # Position ball just below the plunger
var plunger_position: Vector2 = Vector2(840, 1440)  # Default plunger position

# Flag to prevent multiple respawns in a single physics frame
var is_respawning = false

# Ball save system variables
var ball_launch_count = 0
var ball_save_timer: Timer
var ball_save_active = false
var ball_save_duration = 20.0  # 20 seconds

# Signal for ball respawn events
signal ball_respawned

func _ready():
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
	
	# Initialize ball save timer
	ball_save_timer = Timer.new()
	ball_save_timer.wait_time = ball_save_duration
	ball_save_timer.one_shot = true
	ball_save_timer.timeout.connect(_on_ball_save_timer_timeout)
	add_child(ball_save_timer)

func _physics_process(_delta):
	if not is_respawning:
		var overlapping_balls = 0
		
		# Count how many balls are in the exit area
		var overlapping_bodies = get_overlapping_bodies()
		for body in overlapping_bodies:
			if body is RigidBody2D and body.is_in_group("balls") and not body.is_in_group("testballs"):
				overlapping_balls += 1
		
		# Get all balls in the game
		var ball_nodes = get_tree().get_nodes_in_group("balls")
		var filtered_ball_nodes = []
		for ball in ball_nodes:
			if not ball.is_in_group("testballs"):
				filtered_ball_nodes.append(ball)
		ball_nodes = filtered_ball_nodes
		
		# Only reset if there are no balls in the exit area and balls exist elsewhere
		if overlapping_balls == 0 and ball_nodes.size() > 0:
			# Check ball save conditions first
			if check_ball_save_conditions():
				# Ball save triggered - spawn new ball without reducing ball count
				print("BALL SAVE ACTIVATED!")

				# Trigger the ball saved animation
				var ball_saved_label = get_node_or_null("../Ball-Saved")
				if ball_saved_label and ball_saved_label.has_method("play_ball_saved_animation"):
					ball_saved_label.play_ball_saved_animation()

				spawn_ball_save()
				return
			
			# Normal ball loss - reduce ball count first and check game state
			var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
			if score_label and score_label.has_method("get") and "ball_count" in score_label:
				score_label.ball_count -= 1
				# Update the ball count display
				if score_label.has_method("update_ball_count_text"):
					score_label.update_ball_count_text()
				# Check for game over condition
				if score_label.has_method("check_game_over"):
					score_label.check_game_over()
				
				# If ball_count > -1, continue with normal table reset and respawn
				if score_label.ball_count > -1:
					reset_table()
					is_respawning = true
					call_deferred("replace_ball_and_plunger", ball_nodes[0])
				# If ball_count = -1, game over is triggered, don't reset table or respawn

# Function to replace both the ball and plunger
func replace_ball_and_plunger(old_ball: RigidBody2D):
	# Get reference to the table node to add our new objects
	var table = get_node_or_null("..")
	if not table:
		push_error("Could not find parent table node")
		is_respawning = false
		return

	AudioCollection.play_sfx(respawn_sound)

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

# Function to reset the table
func reset_table():
	# Reset the gutterarea1 state
	var gutter_area1 = get_node_or_null("../gutterarea1")
	if gutter_area1 and gutter_area1.has_method("deactivate_guard"):
		gutter_area1.deactivate_guard()
	
	# Reset guardarea lights flag for new ball
	var guard_area = get_node_or_null("../guardarea_1")
	if guard_area and guard_area.has_method("reset_lights_flag"):
		guard_area.reset_lights_flag()
	
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
	
	# Reset ALL target lights to inactive when ball exits
	var lights_parent = get_node_or_null("../Lights")
	if lights_parent:
		for light in lights_parent.get_children():
			if light.has_method("set_mode") and "LightMode" in light:
				light.set_mode(light.LightMode.INACTIVE)
	
	# Reset minigame entrance when ball respawns (with delay to ensure proper initialization)
	var minigame_entrance = get_node_or_null("../minigameentrance")
	if minigame_entrance and minigame_entrance.has_method("reset_entrance"):
		await get_tree().create_timer(0.1).timeout
		minigame_entrance.reset_entrance()
				
	# Reset tilt state if table is tilted
	var nudge_nodes = get_tree().get_nodes_in_group("nudge_system")
	for nudge in nudge_nodes:
		if nudge.has_method("reset_tilt"):
			nudge.reset_tilt()
	
	# Pause missions when ball respawns
	var missions_node = get_node_or_null("../missions")
	if missions_node and missions_node.has_method("pause_missions"):
		missions_node.pause_missions()
	
	# Note: Multiball state is now reset by timer, not when balls are lost
	
	# Reset ball save conditions when table resets
	reset_ball_save_conditions()

# Ball save system functions
func start_ball_save_timer():
	if not ball_save_active:
		ball_save_active = true
		ball_save_timer.start()

func check_ball_save_conditions() -> bool:
	# Check all three conditions:
	# 1) Ball has been launched no more than once
	# 2) It's been less than 20 seconds since first launch
	# 3) There are 0 balls on the table (already checked in calling function)
	return ball_launch_count <= 1 and ball_save_active

func spawn_ball_save():
	# Use the same spawning logic as multiball but simpler
	if not ball_scene_resource:
		push_error("Ball scene resource not loaded for ball save")
		return
	
	# Get table reference
	var table = get_parent()
	if not table:
		push_error("Could not find table node for ball save")
		return
	
	# Create new ball
	var new_ball = ball_scene_resource.instantiate()
	if not new_ball:
		push_error("Failed to instantiate ball save ball")
		return
	
	# Set position and properties (same as multiball)
	var launch_position = Vector2(840, 1240)  # Same position as multiball
	var launch_velocity = Vector2(0, -2000)   # Same velocity as multiball
	
	new_ball.global_position = launch_position
	new_ball.add_to_group("balls")
	
	# Set collision properties
	new_ball.collision_layer = 1
	new_ball.collision_mask = 1
	new_ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	new_ball.sleeping = false
	
	# Use call_deferred to avoid physics query flushing error
	table.call_deferred("add_child", new_ball)
	new_ball.call_deferred("set", "name", "ball_save_ball")
	
	# Launch the ball upward after a brief delay
	await get_tree().create_timer(0.1).timeout
	new_ball.linear_velocity = launch_velocity
	
	# Disable ball save after use
	ball_save_active = false
	ball_save_timer.stop()
	
	is_respawning = false

func reset_ball_save_conditions():
	ball_launch_count = 0
	ball_save_active = false
	if ball_save_timer:
		ball_save_timer.stop()

func _on_ball_save_timer_timeout():
	ball_save_active = false

# Function to be called when ball is launched (from plunger)
func on_ball_launched():
	ball_launch_count += 1
	
	# Start timer on first launch
	if ball_launch_count == 1:
		start_ball_save_timer()
