extends Area2D

# Reference to the guard node
var guard_node: Node2D

# Flag to track if the guard has been activated
var guard_activated: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# Add the guard area to a group for easier management
	add_to_group("guardareas")
	
	# Find the guard node in the scene
	guard_node = get_node_or_null("../Guard")
	
	if guard_node:
		# Deactivate the guard by default
		deactivate_guard()
		print("Guard deactivated by default")
	else:
		push_error("Could not find Guard node")
	
	# Connect the body entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Connected body_entered signal to Guardarea")
	
	# Monitor ball destruction to deactivate guard
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))
	
	# Connect to tree exiting to clean up signals
	tree_exiting.connect(Callable(self, "_on_tree_exiting"))

# Called when a body enters the guard area
func _on_body_entered(body):
	# Check if the entering body is a ball
	if not guard_activated and body is RigidBody2D and (body.is_in_group("balls") or body.name == "Ball"):
		print("Ball detected entering guard area, activating guard")
		activate_guard()

# Called when a node is removed from the scene
func _on_node_removed(node):
	# Check if the removed node is a ball
	if guard_activated and node is RigidBody2D and (node.is_in_group("balls") or node.name == "Ball"):
		# Check if we still have a valid scene tree
		var tree = get_tree()
		if tree == null:
			print("Scene tree no longer valid, skipping node_removed handling")
			return
		
		# Use call_deferred to handle this after physics processing
		call_deferred("_check_ball_count")

# Check if any balls remain in the scene
func _check_ball_count():
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	var tree = get_tree()
	if tree == null:
		return
		
	var remaining_balls = tree.get_nodes_in_group("balls")
	if remaining_balls.size() == 0:
		print("No balls remaining, deactivating guard")
		deactivate_guard()

# Called when this node is about to exit the scene tree
func _on_tree_exiting():
	print("Guard area exiting tree, disconnecting signals")
	
	# Disconnect node_removed signal to prevent errors during scene changes
	var tree = get_tree()
	if tree != null:
		tree.disconnect("node_removed", Callable(self, "_on_node_removed"))
		
	# Additional cleanup if needed
	guard_activated = false

# Method that can be called externally to disconnect signals
func disconnect_signals():
	_on_tree_exiting()

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
		print("Guard deactivated")
