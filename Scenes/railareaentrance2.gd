extends Area2D

# Reference to the rail node
var rail_node: Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Find the rail node in the scene
	rail_node = get_node_or_null("../rail")
	
	if not rail_node:
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
		
		# Also make rail half opaque by setting alpha to 125 (half opacity)
		if rail_node:
			var sprite = rail_node.get_node_or_null("Sprite2D")
			if sprite:
				# Keep the same RGB values but change alpha to 0.49 (125/255)
				var current_color = sprite.modulate
				sprite.modulate = Color(current_color.r, current_color.g, current_color.b, 0.49)
