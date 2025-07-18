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
	# Find the mission_lights controller node
	var mission_lights_node = get_node_or_null("../mission_lights")
	if not mission_lights_node:
		push_error("Could not find mission_lights node")
		return
	
	# Find the missions node to get the active mission
	var missions_node = get_node_or_null("../missions")
	if not missions_node:
		push_error("Could not find missions node")
		return
	
	# Get active missions and update lights for current phase
	var active_missions = missions_node.get_active_missions()
	if not active_missions.is_empty():
		# There's an active mission, update lights for current phase
		var current_mission = active_missions.values()[0]
		var current_phase_requirements = current_mission.phases[current_mission.current_phase]
		mission_lights_node.update_lights_for_mission_progress(current_mission, current_phase_requirements)
	else:
		# No active missions - don't interfere with the mission start flow
		# The mission system will handle right sinkhole light activation
		pass
