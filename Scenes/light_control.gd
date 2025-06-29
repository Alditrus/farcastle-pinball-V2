extends Area2D

# Flag to track if lights have been controlled this ball
var lights_controlled_this_ball: bool = false

func _ready():
	# Connect the body entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Monitor ball destruction to reset flag
	get_tree().connect("node_removed", _on_node_removed)

func _on_body_entered(body):
	# Check if the entering body is a ball and we haven't controlled lights yet this ball
	if not lights_controlled_this_ball and body is RigidBody2D and (body.is_in_group("balls") or body.name == "Ball"):
		control_mission_lights()
		lights_controlled_this_ball = true

func _on_node_removed(node):
	# Check if the removed node is a ball
	if node is RigidBody2D and (node.is_in_group("balls") or node.name == "Ball"):
		# Reset flag when ball is removed (for next ball)
		lights_controlled_this_ball = false

func control_mission_lights():
	# Find the mission_lights node
	var mission_lights_node = get_node_or_null("../mission_lights")
	if not mission_lights_node:
		push_error("Could not find mission_lights node")
		return
	
	# Set all mission lights to inactive, except left_sinkhole_light
	for light in mission_lights_node.get_children():
		if light.has_method("set_mode") and "LightMode" in light:
			if light.name == "left_sinkhole_light":
				# Set left sinkhole light to active
				light.set_mode(light.LightMode.ACTIVE)
			else:
				# Set all other lights to inactive
				light.set_mode(light.LightMode.INACTIVE)
	
	print("Mission lights controlled: all inactive except left_sinkhole_light")
