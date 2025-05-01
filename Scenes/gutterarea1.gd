extends Area2D

# Reference to the guard node
var guard_node: Node2D

# Flag to track if the guard has been activated
var guard_activated: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# Find the guard node in the scene
	guard_node = get_node_or_null("../gutter_guard1")
	
	if guard_node:
		# Deactivate the guard by default
		deactivate_guard()
		print("Gutter guard deactivated by default")
	else:
		push_error("Could not find gutter guard node")
	
	# Connect the body entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Connected body_entered signal to gutterarea1")
	
	# Monitor ball destruction to deactivate guard
	get_tree().connect("node_removed", _on_node_removed)

# Called when a body enters the guard area
func _on_body_entered(body):
	# Check if the entering body is a ball
	if not guard_activated and body is RigidBody2D and (body.is_in_group("balls") or body.name == "Ball"):
		# Only activate if the ball is moving upward (negative y velocity)
		var ball_velocity = body.linear_velocity
		if ball_velocity.y < 0:
			print("Ball detected moving upward into guard area, activating guard")
			activate_guard()
		else:
			print("Ball detected but moving downward, not activating guard")

# Called when a node is removed from the scene
func _on_node_removed(node):
	# Check if the removed node is a ball
	if guard_activated and node is RigidBody2D and (node.is_in_group("balls") or node.name == "Ball"):
		# Only deactivate if the ball is actually being removed (not just being respawned)
		# Add a small delay to ensure it's not just a respawn situation
		await get_tree().create_timer(0.2).timeout
		
		# Check if there are any remaining balls
		var remaining_balls = get_tree().get_nodes_in_group("balls")
		if remaining_balls.size() == 0:
			print("Ball destroyed, deactivating guard")
			deactivate_guard()

# Function to activate the guard
func activate_guard():
	if guard_node:
		# Enable the guard's collision and make it visible
		var static_body = guard_node.get_node_or_null("StaticBody2D")
		if static_body:
			static_body.collision_layer = 1
			static_body.collision_mask = 1
			
		# Make the guard visible
		var sprite = guard_node.get_node_or_null("StaticBody2D/Sprite2D")
		if sprite:
			sprite.visible = true
		
		guard_activated = true
		print("Guard activated")

# Function to deactivate the guard
func deactivate_guard():
	if guard_node:
		# Disable the guard's collision and hide it
		var static_body = guard_node.get_node_or_null("StaticBody2D")
		if static_body:
			static_body.collision_layer = 0
			static_body.collision_mask = 0
			
		# Make the guard invisible
		var sprite = guard_node.get_node_or_null("StaticBody2D/Sprite2D")
		if sprite:
			sprite.visible = false
		
		guard_activated = false
		print("Gutter guard deactivated")
