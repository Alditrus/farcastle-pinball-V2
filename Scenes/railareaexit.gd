extends Area2D

# Reference to the rail node
var rail_node: Node2D
var rail1: RigidBody2D
var rail2: RigidBody2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Find the rail node in the scene
	rail_node = get_node_or_null("../rail")
	
	if rail_node:
		# Get references to rail1 and rail2
		rail1 = rail_node.get_node_or_null("rail1")
		rail2 = rail_node.get_node_or_null("rail2")
		
		if rail1 and rail2:
			# Enable rail1, disable rail2 by default
			enable_rail1()
			print("Initial setup: rail1 enabled, rail2 disabled")
		else:
			push_error("Could not find rail1 or rail2 nodes in rail")
	else:
		push_error("Could not find rail node")
	
	# Set proper collision mask to detect balls with layer 4
	collision_mask = 4  # Must match ball's layer after railareaentrance1
	
	# Keep monitoring enabled
	monitoring = true
	
	# Connect signal
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if body.is_in_group("balls"):
		# Reset the ball's collision back to default
		body.collision_layer = 1
		body.collision_mask = 1
		
		# Switch from rail1 to rail2
		if rail1 and rail2:
			enable_rail2()
			print("Switched to rail2")
		
		# Also make rail half opaque by setting alpha to 125 (half opacity)
		if rail_node:
			var sprite = rail_node.get_node_or_null("Sprite2D")
			if sprite:
				# Keep the same RGB values but change alpha to 0.49 (125/255)
				var current_color = sprite.modulate
				sprite.modulate = Color(current_color.r, current_color.g, current_color.b, 0.49)
				print("Set rail sprite to half opacity (125/255)")
			else:
				print("Could not find Sprite2D in rail node")
		else:
			print("Rail node not found")


# Enable rail1 and disable rail2
func enable_rail1():
	# Enable rail1
	rail1.collision_layer = 2
	rail1.collision_mask = 1
	
	# Disable rail2
	rail2.collision_layer = 0
	rail2.collision_mask = 0


# Enable rail2 and disable rail1
func enable_rail2():
	# Disable rail1
	rail1.collision_layer = 0
	rail1.collision_mask = 0
	
	# Enable rail2
	rail2.collision_layer = 2
	rail2.collision_mask = 1
