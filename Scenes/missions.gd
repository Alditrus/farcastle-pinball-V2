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
	TARGET_SET2,
	MULTIBALL
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
	var waiting_for_right_sinkhole: bool = false
	
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
			{CollisionType.CANDLESET: 2},       # Phase 1: Complete candleset 2x
			{CollisionType.TARGET_SET1: 1, CollisionType.TARGET_SET2: 1},  # Phase 2: Complete target sets 1 and 2
			{CollisionType.ROLLOVER1: 1, CollisionType.ROLLOVER2: 1},      # Phase 3: Hit rollover1 and rollover2
			{CollisionType.BUMPER: 8}           # Phase 4: Hit main bumpers 8x
		]
	},
	"communion_with_the_void": {
		"name": "Communion with the Void",
		"description": "Perform a dark ritual to commune with the void",
		"reward_points": 1000000,
		"phases": [
			{CollisionType.TARGET_SET1: 1, CollisionType.TARGET_SET2: 1},  # Phase 0: Complete 1 set of either target set
			{CollisionType.ALCOVE_BUMPER: 10},                            # Phase 1: Hit alcove bumpers 10x
			{CollisionType.SINKHOLE_LEFT: 2},                             # Phase 2: Hit left sinkhole twice
			{CollisionType.SPINNER: 10}  # Phase 3: Spin either spinners 15x
		],
		"phase_logic": {
			0: "OR",  # Phase 0 uses OR logic (complete either target set)
		}
	},
	"wrath_of_baalhorn": {
		"name": "Wrath of Baalhorn",
		"description": "Destroy the heretics",
		"reward_points": 1500000,
		"phases": [
			{CollisionType.CANDLESET: 1},  # Phase 0: Complete candleset once and hit main bumpers 5x
			{CollisionType.BUMPER: 5}
		],
		"phase_logic": {
			0: "AND"  # Phase 0 uses AND logic (complete both requirements)
		},
		"time_limit": 60.0  # 1 minute time limit
	},
	"requiem_of_the_moon": {
		"name": "Requiem of the Moon",
		"description": "Help the Veiled Lady compose and perform her song to rally the Shades",
		"reward_points": 2000000,
		"phases": [
			{CollisionType.TARGET_SET1: 1, CollisionType.TARGET_SET2: 1},
			{CollisionType.ROLLOVER1: 2, CollisionType.ROLLOVER2: 2},
			{CollisionType.RAMP: 2},
			{CollisionType.SINKHOLE_LEFT: 1, CollisionType.SINKHOLE_RIGHT: 1}
		],
		"phase_logic": {
			0: "OR",  # Phase 0 uses OR logic (complete either target set)
		}
	},
	"the_wardens_coffers": {
		"name": "The Warden’s Coffers",
		"description": "Collect penance from the shades of the castle",
		"reward_points": 3500000,
		"phases": [
			{CollisionType.SPINNER: 20},
			{CollisionType.ALCOVE_BUMPER: 10},
			{CollisionType.BUMPER: 8},
			{CollisionType.TARGET: 5}
		]
	},
	"the_stone_blacksmiths_apprentice": {
		"name": "The Stone Blacksmith’s Apprentice",
		"description": "Assist the Blacksmith in forging an enchanted claymore",
		"reward_points": 4000000,
		"phases": [
			{CollisionType.SINKHOLE_RIGHT: 3},
			{CollisionType.TARGET_SET1: 1, CollisionType.TARGET_SET2: 1},
			{CollisionType.RAMP: 2},
			{CollisionType.CANDLESET: 1, CollisionType.BUMPER: 10}
		],
		"phase_logic": {
			0: "OR",  # Phase 0 uses OR logic (complete either target set)
		}
	},
	"lich_mode": {
		"name": "Lich Mode",
		"description": "Slay Moloch",
		"reward_points": 5000000,
		"phases": [
			{CollisionType.SINKHOLE_RIGHT: 1, CollisionType.SINKHOLE_LEFT: 1},
			{CollisionType.CANDLESET: 3, CollisionType.BUMPER: 3},
			{CollisionType.ALCOVE_BUMPER: 20},
			{CollisionType.TARGET_SET1: 3, CollisionType.TARGET_SET2: 3},
			{CollisionType.SPINNER: 6, CollisionType.MULTIBALL: 1}
		],
		"phase_logic": {
			3: "OR"
		},
		"time_limit": 120
	}
}
var active_missions: Dictionary = {}
var completed_missions: Dictionary = {}
var last_active_mission: Dictionary = {} # Stores last mission state for resuming
var missions_paused: bool = false # Pause missions when ball respawns
var waiting_for_right_sinkhole_to_start: bool = false # Flag to indicate we're waiting for right sinkhole to start mission

# Timer variables for timed missions
var mission_timer: Timer
var current_timed_mission: Mission = null

# Reference to mission lights controller
var mission_lights_node: Node2D

signal mission_started(mission: Mission)
signal mission_phase_advanced(mission: Mission)
signal mission_progress_updated(mission: Mission, collision_type: CollisionType, current_count: int, required_count: int)
signal mission_completed(mission: Mission)
signal mission_failed(mission: Mission)

func _ready():
	# Get reference to mission lights controller
	mission_lights_node = get_node("../mission_lights")
	if not mission_lights_node:
		push_error("Could not find mission_lights node")
	
	# Connect to multiball activation signal
	var multiball_node = get_node("../multiball")
	if multiball_node:
		multiball_node.multiball_activated.connect(_on_multiball_activated)
		multiball_node.sequence_updated.connect(_on_multiball_sequence_updated)
	else:
		push_error("Could not find multiball node")
	
	# Initialize mission timer
	mission_timer = Timer.new()
	mission_timer.wait_time = 60.0  # Default 1 minute
	mission_timer.one_shot = true
	mission_timer.timeout.connect(_on_mission_timer_timeout)
	add_child(mission_timer)

func start_mission(mission_id: String = "") -> bool:
	var target_mission_id = mission_id
	
	# If no mission_id provided, check for last active mission or start next available mission
	if target_mission_id == "":
		if last_active_mission.has("id"):
			target_mission_id = last_active_mission.id
		else:
			# Start next available mission in order
			var mission_order = ["raise_the_dead", "communion_with_the_void", "wrath_of_baalhorn", "requiem_of_the_moon", "the_wardens_coffers", "the_stone_blacksmiths_apprentice", "lich_mode"]
			for mission in mission_order:
				if not is_mission_completed(mission):
					target_mission_id = mission
					break
			# If all missions completed, default to first mission
			if target_mission_id == "":
				target_mission_id = "raise_the_dead"
	
	if target_mission_id in all_missions and not target_mission_id in active_missions:
		# First, activate the right sinkhole requirement
		waiting_for_right_sinkhole_to_start = true
		var _mission_data = all_missions[target_mission_id]
		
		# Activate right sinkhole light to indicate where player needs to hit
		if mission_lights_node:
			mission_lights_node.activate_right_sinkhole_light()
		
		# Store mission info for when right sinkhole is hit
		last_active_mission = {
			"id": target_mission_id,
			"current_phase": last_active_mission.get("current_phase", 0) if last_active_mission.has("id") and last_active_mission.id == target_mission_id else 0
		}
		
		return true
	return false

func actually_start_mission(mission_id: String) -> bool:
	if mission_id in all_missions:
		var mission_data = all_missions[mission_id]
		var mission = Mission.new(mission_id, mission_data.name, mission_data.description, mission_data.phases, mission_data.reward_points)
		
		# Resume from last active phase if this was the last active mission
		if last_active_mission.has("id") and last_active_mission.id == mission_id:
			mission.current_phase = last_active_mission.current_phase
			# Initialize progress for current phase
			mission.progress.clear()
			for collision_type in mission.phases[mission.current_phase]:
				mission.progress[collision_type] = 0
		
		mission.is_active = true
		active_missions[mission_id] = mission
		
		# Deactivate minigame entrance if it's open
		var minigame_entrance = get_node_or_null("../minigameentrance")
		if minigame_entrance and minigame_entrance.has_method("reset_entrance"):
			minigame_entrance.reset_entrance()
		
		# Update mission lights for new phase
		update_mission_lights(mission)
		
		# Start timer for timed missions
		if mission_data.has("time_limit"):
			mission_timer.wait_time = mission_data.time_limit
			mission_timer.start()
			current_timed_mission = mission
		
		# Switch track when mission is initiated
		if mission.id == "lich_mode":
			AudioCollection.switch_to_lich_mode_track()
		else:
			AudioCollection.switch_to_random_track()
		
		mission_started.emit(mission)
		return true
	return false

func record_collision(collision_type: CollisionType):
	# Don't record collisions if missions are paused
	if missions_paused:
		return
	
	# Check if we're waiting for right sinkhole to start mission
	if waiting_for_right_sinkhole_to_start and collision_type == CollisionType.SINKHOLE_RIGHT:
		waiting_for_right_sinkhole_to_start = false
		# Deactivate right sinkhole light
		if mission_lights_node:
			mission_lights_node.deactivate_right_sinkhole_light()
		# Actually start the mission now
		if last_active_mission.has("id"):
			actually_start_mission(last_active_mission.id)
		return
		
	for mission_id in active_missions:
		var mission = active_missions[mission_id]
		var current_phase_requirements = mission.phases[mission.current_phase]
		
		if collision_type in current_phase_requirements:
			mission.progress[collision_type] += 1
			var required = current_phase_requirements[collision_type]
			mission_progress_updated.emit(mission, collision_type, mission.progress[collision_type], required)
			
			# Update mission lights to reflect current progress
			update_mission_lights(mission)
			
			if check_phase_complete(mission):
				advance_mission_phase(mission)

func check_phase_complete(mission: Mission) -> bool:
	var current_phase_requirements = mission.phases[mission.current_phase]
	
	# Check if this phase has special logic defined
	var mission_data = all_missions[mission.id]
	var phase_logic = mission_data.get("phase_logic", {})
	var current_phase_logic = phase_logic.get(mission.current_phase, "AND")
	
	if current_phase_logic == "OR":
		# OR logic: complete when ANY requirement is met
		for collision_type in current_phase_requirements:
			if mission.progress[collision_type] >= current_phase_requirements[collision_type]:
				return true
		return false
	else:
		# Default AND logic: complete when ALL requirements are met
		for collision_type in current_phase_requirements:
			if mission.progress[collision_type] < current_phase_requirements[collision_type]:
				return false
		return true

func advance_mission_phase(mission: Mission):
	mission.current_phase += 1
	
	if mission.current_phase >= mission.phases.size():
		complete_mission(mission)
	else:
		# Add 30 seconds to timer for Lich Mode when completing a phase
		if mission.id == "lich_mode" and current_timed_mission == mission:
			mission_timer.wait_time -= 30.0
		
		mission.progress.clear()
		for collision_type in mission.phases[mission.current_phase]:
			mission.progress[collision_type] = 0
		
		# Update mission lights for new phase
		update_mission_lights(mission)

		# Emit mission_phase_advanced signal to update UI and other systems for the new phase
		mission_phase_advanced.emit(mission)

func complete_mission(mission: Mission):
	mission.is_completed = true
	mission.is_active = false
	completed_missions[mission.id] = mission
	active_missions.erase(mission.id)
	
	# Clear last active mission since this one is completed
	if last_active_mission.has("id") and last_active_mission.id == mission.id:
		last_active_mission.clear()
	
	# Add mission reward points to score
	var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
	if score_label:
		score_label.score += mission.reward_points
		score_label.update_score_text()
	
	mission_completed.emit(mission)
	
	# Switch back to playlist track if lich mode was completed
	if mission.id == "lich_mode":
		AudioCollection.switch_to_random_track()
	
	# Stop timer if this was a timed mission
	if current_timed_mission == mission:
		mission_timer.stop()
		current_timed_mission = null
	
	# Automatically start the next mission in sequence
	var mission_order = ["raise_the_dead", "communion_with_the_void", "wrath_of_baalhorn", "requiem_of_the_moon", "the_wardens_coffers", "the_stone_blacksmiths_apprentice", "lich_mode"]
	var current_mission_index = mission_order.find(mission.id)
	if current_mission_index != -1:
		# Calculate next mission index (loop back to 0 if at end)
		var next_mission_index = (current_mission_index + 1) % mission_order.size()
		var next_mission_id = mission_order[next_mission_index]
		
		# If we're looping back, clear completion status for all missions
		if next_mission_index == 0:
			completed_missions.clear()
		
		start_mission(next_mission_id)

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

func pause_missions():
	# Pause mission progress
	missions_paused = true

func unpause_missions():
	# Resume mission progress
	missions_paused = false

	# If we have an active mission, update the lights to show the current phase requirements
	if not active_missions.is_empty():
		var mission = active_missions.values()[0]  # Get the first (and should be only) active mission
		update_mission_lights(mission)

	# Turn off the left sinkhole light since the left lane requirement has been met
	if mission_lights_node:
		mission_lights_node.set_light_mode("left_sinkhole_light", mission_lights_node.get_light_mode_inactive())

# Update mission lights based on current mission phase
func update_mission_lights(mission: Mission):
	if not mission_lights_node:
		return
	
	# Get current phase requirements
	var current_phase_requirements = mission.phases[mission.current_phase]
	
	# Use the mission lights controller to update lights for current phase
	mission_lights_node.update_lights_for_mission_progress(mission, current_phase_requirements)

# Handle multiball activation
func _on_multiball_activated():
	record_collision(CollisionType.MULTIBALL)

# Handle multiball sequence updates
func _on_multiball_sequence_updated(current_sequence: Array, required_sequence: Array):
	# Only update lights if we have an active lich mode mission in the multiball phase
	if not active_missions.has("lich_mode"):
		return
	
	var lich_mission = active_missions["lich_mode"]
	var current_phase_requirements = lich_mission.phases[lich_mission.current_phase]
	
	# Check if current phase requires multiball and it hasn't been completed yet
	if (CollisionType.MULTIBALL in current_phase_requirements and
		lich_mission.progress.get(CollisionType.MULTIBALL, 0) < current_phase_requirements[CollisionType.MULTIBALL]):
		
		# Update mission lights to reflect sequence progress
		if mission_lights_node:
			mission_lights_node.update_multiball_sequence_lights()

# Handle timed mission timeout
func _on_mission_timer_timeout():
	if current_timed_mission:
		var mission_id = current_timed_mission.id
		
		# Switch back to playlist track if lich mode failed
		if mission_id == "lich_mode":
			AudioCollection.switch_to_random_track()
		
		# Reset the timed mission - remove from active missions but don't mark as completed
		active_missions.erase(mission_id)
		
		# Clear last active mission if it was this mission
		if last_active_mission.has("id") and last_active_mission.id == mission_id:
			last_active_mission.clear()
		
		# Reset current timed mission
		current_timed_mission = null
		
		# Start the same mission again (will require right sinkhole activation)
		start_mission(mission_id)
