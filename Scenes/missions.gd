extends Node2D

enum CollisionType {
	BUMPER,
	ALCOVE_BUMPER,
	TARGET,
	RAMP,
	SINKHOLE_LEFT,
	SINKHOLE_RIGHT,
	ROLLOVER1,
	ROLLOVER2,
	SPINNER,
	CANDLE,
	CANDLESET,
	TARGET_SET1,
	TARGET_SET2
}

class Mission:
	var id: String
	var name: String
	var description: String
	var reward_points: int
	var phases: Array = []
	var current_phase: int = 0
	var is_active: bool = false
	var is_completed: bool = false
	var progress: Dictionary = {}
	
	func _init(mission_id: String, mission_name: String, mission_desc: String, mission_phases: Array, points: int = 0):
		id = mission_id
		name = mission_name
		description = mission_desc
		phases = mission_phases
		reward_points = points
		if phases.size() > 0:
			for collision_type in phases[0]:
				progress[collision_type] = 0

var all_missions: Dictionary = {
	"raise_the_dead": {
		"name": "Raise the Dead",
		"description": "Raise an army of the undead to fight Moloch",
		"reward_points": 500000,
		"phases": [
			{CollisionType.SINKHOLE_RIGHT: 1},  # Phase 0: Enter right sinkhole lane
			{CollisionType.CANDLESET: 2},       # Phase 1: Complete candleset 2x
			{CollisionType.TARGET_SET1: 1, CollisionType.TARGET_SET2: 1},  # Phase 2: Complete target sets 1 and 2
			{CollisionType.ROLLOVER1: 1, CollisionType.ROLLOVER2: 1},      # Phase 3: Hit rollover1 and rollover2
			{CollisionType.BUMPER: 8}           # Phase 4: Hit main bumpers 8x
		]
	}
}
var active_missions: Dictionary = {}
var completed_missions: Dictionary = {}
var last_active_mission: Dictionary = {} # Stores last mission state for resuming

signal mission_started(mission: Mission)
signal mission_progress_updated(mission: Mission, collision_type: CollisionType, current_count: int, required_count: int)
signal mission_completed(mission: Mission)

func start_mission(mission_id: String = "") -> bool:
	var target_mission_id = mission_id
	
	# If no mission_id provided, check for last active mission or start first mission
	if target_mission_id == "":
		if last_active_mission.has("id"):
			target_mission_id = last_active_mission.id
		else:
			# Start first mission if none have been started
			target_mission_id = "raise_the_dead"
	
	if target_mission_id in all_missions and not target_mission_id in active_missions:
		var mission_data = all_missions[target_mission_id]
		var mission = Mission.new(target_mission_id, mission_data.name, mission_data.description, mission_data.phases, mission_data.reward_points)
		
		# Resume from last active phase if this was the last active mission
		if last_active_mission.has("id") and last_active_mission.id == target_mission_id:
			mission.current_phase = last_active_mission.current_phase
			# Initialize progress for current phase
			mission.progress.clear()
			for collision_type in mission.phases[mission.current_phase]:
				mission.progress[collision_type] = 0
		
		mission.is_active = true
		active_missions[target_mission_id] = mission
		mission_started.emit(mission)
		return true
	return false

func record_collision(collision_type: CollisionType):
	for mission_id in active_missions:
		var mission = active_missions[mission_id]
		var current_phase_requirements = mission.phases[mission.current_phase]
		
		if collision_type in current_phase_requirements:
			mission.progress[collision_type] += 1
			var required = current_phase_requirements[collision_type]
			mission_progress_updated.emit(mission, collision_type, mission.progress[collision_type], required)
			
			if check_phase_complete(mission):
				advance_mission_phase(mission)

func check_phase_complete(mission: Mission) -> bool:
	var current_phase_requirements = mission.phases[mission.current_phase]
	for collision_type in current_phase_requirements:
		if mission.progress[collision_type] < current_phase_requirements[collision_type]:
			return false
	return true

func advance_mission_phase(mission: Mission):
	mission.current_phase += 1
	
	if mission.current_phase >= mission.phases.size():
		complete_mission(mission)
	else:
		mission.progress.clear()
		for collision_type in mission.phases[mission.current_phase]:
			mission.progress[collision_type] = 0

func complete_mission(mission: Mission):
	mission.is_completed = true
	mission.is_active = false
	completed_missions[mission.id] = mission
	active_missions.erase(mission.id)
	
	# Clear last active mission since this one is completed
	if last_active_mission.has("id") and last_active_mission.id == mission.id:
		last_active_mission.clear()
	
	# Add mission reward points to score
	var score_label = get_node("/root/Main/score_label")
	if score_label:
		score_label.score += mission.reward_points
		score_label.update_score_text()
	
	mission_completed.emit(mission)

func get_active_missions() -> Dictionary:
	return active_missions

func get_completed_missions() -> Dictionary:
	return completed_missions

func is_mission_active(mission_id: String) -> bool:
	return mission_id in active_missions

func is_mission_completed(mission_id: String) -> bool:
	return mission_id in completed_missions

func save_mission_state():
	# Save current active mission state for resuming later
	if not active_missions.is_empty():
		var mission = active_missions.values()[0]  # Assuming one mission at a time
		last_active_mission = {
			"id": mission.id,
			"current_phase": mission.current_phase
		}
	# Clear active missions (for game over)
	active_missions.clear()
