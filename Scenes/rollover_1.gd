extends Node2D

func _ready():
	# Make sure the Area2D is configured for monitoring
	var area = $Area2D
	if area:
		area.monitoring = true
		area.monitorable = true
		
		# Connect signals
		area.body_entered.connect(_on_area_body_entered)

# Called when a body enters the Area2D
func _on_area_body_entered(body):
	if body is RigidBody2D and body.is_in_group("balls"):
		
		# Increase score
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.increase_score("rollover")
			
		var missions_node = get_node("../missions")
		if missions_node:
			missions_node.record_collision(missions_node.CollisionType.ROLLOVER1)
		
		# Deactivate the individual rollover light
		deactivate_individual_rollover_light()

# Deactivate individual rollover light
func deactivate_individual_rollover_light():
	# Get the mission lights controller
	var mission_lights_node = get_node("../mission_lights")
	if mission_lights_node and mission_lights_node.has_method("deactivate_individual_rollover_light"):
		mission_lights_node.deactivate_individual_rollover_light(1)
