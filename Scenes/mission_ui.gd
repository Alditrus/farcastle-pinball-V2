extends Control

@onready var mission_title = $VBoxContainer/MissionTitle
@onready var phase_label = $VBoxContainer/PhaseLabel
@onready var objective_label = $VBoxContainer/ObjectiveLabel
@onready var progress_label = $VBoxContainer/ProgressLabel

var missions_node: Node2D
var current_mission = null

func _ready():
	missions_node = get_node("../missions")
	if missions_node:
		missions_node.mission_started.connect(_on_mission_started)
		missions_node.mission_progress_updated.connect(_on_mission_progress_updated)
		missions_node.mission_completed.connect(_on_mission_completed)
	
	update_display()

func update_display():
	if not missions_node:
		return
		
	var active_missions = missions_node.get_active_missions()
	
	if active_missions.is_empty():
		mission_title.text = "No Active Mission"
		phase_label.text = "Phase: -"
		objective_label.text = "Objective: -"
		progress_label.text = "Progress: -"
		current_mission = null
		return
	
	# Get the first active mission (assuming one mission at a time)
	current_mission = active_missions.values()[0]
	
	mission_title.text = current_mission.name
	phase_label.text = "Phase: %d/%d" % [current_mission.current_phase + 1, current_mission.phases.size()]
	
	# Get current phase requirements
	var current_phase_reqs = current_mission.phases[current_mission.current_phase]
	var objective_text = get_objective_text(current_phase_reqs)
	objective_label.text = "Objective: " + objective_text
	
	# Get progress text
	var progress_text = get_progress_text(current_mission, current_phase_reqs)
	progress_label.text = "Progress: " + progress_text

func get_objective_text(phase_requirements: Dictionary) -> String:
	var objectives = []
	
	for collision_type in phase_requirements:
		var count = phase_requirements[collision_type]
		var type_name = get_collision_type_name(collision_type)
		
		if count == 1:
			objectives.append(type_name)
		else:
			objectives.append("%s (%dx)" % [type_name, count])
	
	var result = ""
	for i in range(objectives.size()):
		if i > 0:
			result += ", "
		result += objectives[i]
	return result

func get_progress_text(mission, phase_requirements: Dictionary) -> String:
	var progress_parts = []
	
	for collision_type in phase_requirements:
		var current = mission.progress.get(collision_type, 0)
		var required = phase_requirements[collision_type]
		var type_name = get_collision_type_name(collision_type)
		
		progress_parts.append("%s: %d/%d" % [type_name, current, required])
	
	var result = ""
	for i in range(progress_parts.size()):
		if i > 0:
			result += ", "
		result += progress_parts[i]
	return result

func get_collision_type_name(collision_type) -> String:
	match collision_type:
		missions_node.CollisionType.BUMPER:
			return "Bumpers"
		missions_node.CollisionType.TARGET:
			return "Targets"
		missions_node.CollisionType.RAMP:
			return "Ramp"
		missions_node.CollisionType.SINKHOLE_LEFT:
			return "Left Sinkhole"
		missions_node.CollisionType.SINKHOLE_RIGHT:
			return "Right Sinkhole"
		missions_node.CollisionType.ROLLOVER1:
			return "Rollover 1"
		missions_node.CollisionType.ROLLOVER2:
			return "Rollover 2"
		missions_node.CollisionType.SPINNER:
			return "Spinner"
		missions_node.CollisionType.CANDLE:
			return "Candle"
		missions_node.CollisionType.CANDLESET:
			return "Candle Set"
		missions_node.CollisionType.TARGET_SET1:
			return "Target Set 1"
		missions_node.CollisionType.TARGET_SET2:
			return "Target Set 2"
		_:
			return "Unknown"

func _on_mission_started(mission):
	current_mission = mission
	update_display()

func _on_mission_progress_updated(mission, _collision_type, _current_count, _required_count):
	if mission == current_mission:
		update_display()

func _on_mission_completed(mission):
	if mission == current_mission:
		current_mission = null
		update_display()
