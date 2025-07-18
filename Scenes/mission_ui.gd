extends Control

@onready var mission_title = $VBoxContainer/MissionTitle
@onready var phase_label = $VBoxContainer/PhaseLabel
@onready var objective_label = $VBoxContainer/ObjectiveLabel
@onready var progress_label = $VBoxContainer/ProgressLabel

var timer_label: Label

var missions_node: Node2D
var current_mission = null
var is_timed_mission = false
var mission_time_limit = 0.0

func _ready():
	# Try to get the timer label if it exists
	timer_label = get_node_or_null("VBoxContainer/TimerLabel")
	
	missions_node = get_node("../missions")
	if missions_node:
		missions_node.mission_started.connect(_on_mission_started)
		missions_node.mission_phase_advanced.connect(_on_mission_phase_advanced)
		missions_node.mission_progress_updated.connect(_on_mission_progress_updated)
		missions_node.mission_completed.connect(_on_mission_completed)
	
	update_display()

func _process(_delta):
	# Update timer display for timed missions
	if is_timed_mission and missions_node and missions_node.mission_timer and timer_label:
		var time_left = missions_node.mission_timer.time_left
		if time_left > 0:
			var minutes = int(time_left) / 60
			var seconds = int(time_left) % 60
			timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
		else:
			timer_label.text = "Time: 00:00"

func update_display():
	if not missions_node:
		return
		
	var active_missions = missions_node.get_active_missions()
	
	if active_missions.is_empty():
		mission_title.text = "No Active Mission"
		phase_label.text = "Phase: -"
		objective_label.text = "Objective: -"
		progress_label.text = "Progress: -"
		if timer_label:
			timer_label.text = ""
		current_mission = null
		is_timed_mission = false
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
	
	# Check if this is a timed mission
	var mission_data = missions_node.all_missions[current_mission.id]
	if mission_data.has("time_limit"):
		is_timed_mission = true
		mission_time_limit = mission_data.time_limit
		if timer_label:
			timer_label.visible = true
	else:
		is_timed_mission = false
		if timer_label:
			timer_label.visible = false
			timer_label.text = ""

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

func _on_mission_phase_advanced(mission):
	if mission == current_mission:
		update_display()

func _on_mission_progress_updated(mission, _collision_type, _current_count, _required_count):
	if mission == current_mission:
		update_display()

func _on_mission_completed(mission):
	if mission == current_mission:
		current_mission = null
		update_display()
