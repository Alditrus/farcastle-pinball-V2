extends Node2D

# Set of collision types to track for missions
enum CollisionType {
	BUMPER,
	ALCOVE_BUMPER,
	SLINGSHOT,
	TARGET,
	TARGET_SET,
	CANDLE,
	CANDLE_SET,
	RAIL_EXIT,
	SPINNER,
	SINKHOLE,
	JACKPOT,
	MINIGAME
}

# Dictionary mapping element_type strings to CollisionType enum
const TYPE_MAP = {
	"bumper": CollisionType.BUMPER,
	"alcove_bumper": CollisionType.ALCOVE_BUMPER,
	"slingshot": CollisionType.SLINGSHOT,
	"target": CollisionType.TARGET,
	"target_set_complete": CollisionType.TARGET_SET,
	"candle": CollisionType.CANDLE,
	"candle_set_complete": CollisionType.CANDLE_SET,
	"rail_exit": CollisionType.RAIL_EXIT,
	"spinner": CollisionType.SPINNER,
	"sinkhole": CollisionType.SINKHOLE,
	"jackpot": CollisionType.JACKPOT,
	"minigame_win": CollisionType.MINIGAME
}

# Mission tracking data
var collision_counts = {
	CollisionType.BUMPER: 0,
	CollisionType.ALCOVE_BUMPER: 0,
	CollisionType.SLINGSHOT: 0,
	CollisionType.TARGET: 0,
	CollisionType.TARGET_SET: 0,
	CollisionType.CANDLE: 0,
	CollisionType.CANDLE_SET: 0,
	CollisionType.RAIL_EXIT: 0,
	CollisionType.SPINNER: 0,
	CollisionType.SINKHOLE: 0,
	CollisionType.JACKPOT: 0,
	CollisionType.MINIGAME: 0
}

# Signal emitted when a mission object is hit
signal object_hit(collision_type, count)
# Signal emitted when a mission is completed
signal mission_completed(mission_id)
# Signal for minigame jaw movement
signal jaw_progress(progress_percent)

# Active missions dictionary
var active_missions = {}
var completed_missions = []
var available_missions = []

# Minigame Jaw Movement Variables
var jaw_target_type: int = -1  # Will be set randomly at start
var jaw_hits_required: int = 10 # How many hits needed to fully open
var jaw_current_hits: int = 0   # Current hit count for jaw movement
var jaw_object_names = [        # Human-readable names of objects
	"bumpers",
	"alcove bumpers",
	"slingshots",
	"targets",
	"target sets",
	"candles",
	"candle sets",
	"rail exits",
	"spinners",
	"sinkholes",
	"jackpots",
	"minigame wins"
]

# Mission definitions
var mission_defs = [
	{
		"id": "bumper_master",
		"name": "Bumper Master",
		"description": "Hit 10 bumpers",
		"required_type": CollisionType.BUMPER,
		"required_count": 10,
		"reward": 50000
	},
	{
		"id": "target_practice",
		"name": "Target Practice",
		"description": "Complete 3 target sets",
		"required_type": CollisionType.TARGET_SET,
		"required_count": 3,
		"reward": 100000
	},
	{
		"id": "spinner_king",
		"name": "Spinner King",
		"description": "Hit the spinner 5 times",
		"required_type": CollisionType.SPINNER,
		"required_count": 5,
		"reward": 25000
	},
	{
		"id": "sinkhole_explorer",
		"name": "Sinkhole Explorer",
		"description": "Enter the sinkhole 3 times",
		"required_type": CollisionType.SINKHOLE,
		"required_count": 3,
		"reward": 75000
	},
	{
		"id": "candle_lighter",
		"name": "Candle Lighter",
		"description": "Hit 8 candles",
		"required_type": CollisionType.CANDLE,
		"required_count": 8,
		"reward": 30000
	},
	{
		"id": "rail_racer",
		"name": "Rail Racer",
		"description": "Exit the rail 5 times",
		"required_type": CollisionType.RAIL_EXIT,
		"required_count": 5,
		"reward": 20000
	}
]

# Called when the node enters the scene tree for the first time
func _ready():
	# Initialize available missions from definitions
	for mission in mission_defs:
		available_missions.append(mission["id"])
	
	# Activate initial set of missions (could be random or predefined)
	activate_mission("bumper_master")
	activate_mission("target_practice")
	activate_mission("spinner_king")
	
	# Set a random collision type to open the jaw
	select_random_jaw_target()

# Called when a ball exits and a new one is spawned
func reset_for_new_ball():
	# Reset collision counts for the new ball
	for key in collision_counts.keys():
		collision_counts[key] = 0
	
	# Reset jaw progress, but keep the same target type
	jaw_current_hits = 0
	emit_signal("jaw_progress", 0.0)

# Register a collision with a mission object
func register_collision(element_type: String):
	# Convert string type to enum type
	if not TYPE_MAP.has(element_type):
		return
		
	var collision_type = TYPE_MAP[element_type]
	collision_counts[collision_type] += 1
	
	# Check if this hit contributes to jaw opening
	if collision_type == jaw_target_type:
		update_jaw_progress()
	
	# Emit signal for UI updates
	emit_signal("object_hit", collision_type, collision_counts[collision_type])
	
	# Check mission progress
	check_mission_progress(collision_type)

# Select a random object type that will cause the jaw to open
func select_random_jaw_target():
	# Get all available types from the enum by value
	var available_types = []
	for type_value in CollisionType.values():
		available_types.append(type_value)
	
	# Skip some rare types that might be frustrating as targets
	available_types.erase(CollisionType.TARGET_SET)
	available_types.erase(CollisionType.CANDLE_SET)
	available_types.erase(CollisionType.JACKPOT)
	available_types.erase(CollisionType.MINIGAME)
	# Also exclude spinners and alcove bumpers
	available_types.erase(CollisionType.SPINNER)
	available_types.erase(CollisionType.ALCOVE_BUMPER)
	
	# Pick a random type from the available options
	jaw_target_type = available_types[randi() % available_types.size()]
	jaw_current_hits = 0
	
	# Random number of required hits (between 5 and 15)
	jaw_hits_required = 5 + randi() % 11
	
	print("Jaw will open with %s hits on %s" % [jaw_hits_required, jaw_object_names[jaw_target_type]])

# Update the jaw progress based on hit count
func update_jaw_progress():
	jaw_current_hits += 1
	
	# Calculate percentage of progress (0.0 to 1.0)
	var progress_percent = float(jaw_current_hits) / float(jaw_hits_required)
	progress_percent = min(progress_percent, 1.0)  # Cap at 100%
	
	# Emit signal with progress percentage
	emit_signal("jaw_progress", progress_percent)
	
	print("Jaw progress: %d/%d hits (%d%%)" % [
		jaw_current_hits, 
		jaw_hits_required, 
		int(progress_percent * 100)
	])

# Get the current jaw target object name
func get_jaw_target_name():
	if jaw_target_type >= 0 and jaw_target_type < jaw_object_names.size():
		return jaw_object_names[jaw_target_type]
	return "unknown"

# Check if any active missions have progressed
func check_mission_progress(collision_type):
	for mission_id in active_missions.keys():
		var mission = active_missions[mission_id]
		
		if mission["required_type"] == collision_type:
			var current_count = collision_counts[collision_type]
			var required_count = mission["required_count"]
			
			# If mission is completed
			if current_count >= required_count:
				complete_mission(mission_id)

# Activate a mission
func activate_mission(mission_id):
	if mission_id in available_missions:
		# Find the mission definition
		for mission in mission_defs:
			if mission["id"] == mission_id:
				# Add to active missions
				active_missions[mission_id] = mission
				# Remove from available missions
				available_missions.erase(mission_id)
				return true
	
	return false

# Complete a mission
func complete_mission(mission_id):
	if mission_id in active_missions:
		var mission = active_missions[mission_id]
		
		# Award points
		var score_label = get_node_or_null("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			# Add mission reward to score
			score_label.score += mission["reward"]
			score_label.update_score_text()
		
		# Move from active to completed
		completed_missions.append(mission_id)
		active_missions.erase(mission_id)
		
		# Emit completion signal
		emit_signal("mission_completed", mission_id)
		
		# Activate a new mission if available
		if available_missions.size() > 0:
			# Pick a random mission from available ones
			var new_mission_id = available_missions[randi() % available_missions.size()]
			activate_mission(new_mission_id)
		
		return true
	
	return false

# Get active missions with progress
func get_active_missions_with_progress():
	var missions_with_progress = []
	
	for mission_id in active_missions.keys():
		var mission = active_missions[mission_id]
		var type = mission["required_type"]
		var current = collision_counts[type]
		var required = mission["required_count"]
		
		missions_with_progress.append({
			"id": mission_id,
			"name": mission["name"],
			"description": mission["description"],
			"current": current,
			"required": required,
			"progress": float(current) / float(required)
		})
	
	return missions_with_progress

# Get list of completed missions
func get_completed_missions():
	var missions = []
	
	for mission_id in completed_missions:
		for mission in mission_defs:
			if mission["id"] == mission_id:
				missions.append(mission)
	
	return missions
