extends Area2D

# Flag to track if mission has been started this ball
var mission_started_this_ball: bool = false

# Reference to missions node
var missions_node: Node2D

func _ready():
	# Find the missions node
	missions_node = get_node_or_null("../missions")
	
	if not missions_node:
		push_error("Could not find missions node")
	
	# Connect the body entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Monitor ball destruction to reset flag
	get_tree().connect("node_removed", _on_node_removed)

func _on_body_entered(body):
	# Check if the entering body is a ball and we haven't started mission yet this ball
	if not mission_started_this_ball and body is RigidBody2D and (body.is_in_group("balls") or body.name == "Ball"):
		if missions_node:
			# Start mission (will resume last mission or start first mission)
			missions_node.start_mission()
			# Unpause missions so progress can continue
			missions_node.unpause_missions()
			mission_started_this_ball = true

func _on_node_removed(node):
	# Check if the removed node is a ball
	if node is RigidBody2D and (node.is_in_group("balls") or node.name == "Ball"):
		# Reset flag when ball is removed (for next ball)
		mission_started_this_ball = false
