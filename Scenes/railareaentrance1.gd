extends Area2D

# Reference to the rail node
var rail_node: Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Find the rail node in the scene
	rail_node = get_node_or_null("../rail")
	
	if not rail_node:
		push_error("Could not find rail node")
	
	body_entered.connect(_on_body_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_body_entered(body):
	if body.is_in_group("balls"):
		# Change ball collision properties
		body.collision_layer = 4
		body.collision_mask = 2
		
		# Make rail fully opaque by setting alpha to 255 (full opacity)
		if rail_node:
			var sprite = rail_node.get_node_or_null("Sprite2D")
			if sprite:
				# Keep the same RGB values but change alpha to 1.0 (255)
				var current_color = sprite.modulate
				sprite.modulate = Color(current_color.r, current_color.g, current_color.b, 1.0)
				print("Set rail sprite to full opacity")
			else:
				print("Could not find Sprite2D in rail node")
		else:
			print("Rail node not found")
