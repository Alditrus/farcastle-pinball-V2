extends Node2D

# Central controller for all mission lights distributed throughout the game

# Dictionary to cache light references for performance
var light_cache: Dictionary = {}

# List of light paths to control (relative to table root)
var mission_light_paths = [
	"bumper_light",                    # Direct child of table
	"left_sinkhole_light",            # Direct child of table
	"right_sinkhole_light",           # Direct child of table
	"candleset/target_lights",
	"candleset/target_lights/target_1_light",  # Individual candleset lights
	"candleset/target_lights/target_2_light",
	"candleset/target_lights/target_3_light",
	"targets1/target_lights",
	"targets1/target_lights/target_1_light",   # Individual target set 1 lights
	"targets1/target_lights/target_2_light",
	"targets1/target_lights/target_3_light",
	"targets2/target_lights",
	"targets2/target_lights/target_1_light",   # Individual target set 2 lights
	"targets2/target_lights/target_2_light", 
	"targets2/target_lights/target_3_light",
	"rollover1/rollover_light",       # Light within rollover1 scene
	"rollover2/rollover_light",       # Light within rollover2 scene
	"flaps1/carrot_light",            # Light within flaps1 scene
	"flaps2/carrot_light",             # Light within flaps2 scene
	"candle4/carrot_light",
	"candle5/carrot_light",
	"candle6/carrot_light",
	"candle7/carrot_light",
	"rail/ramp_light"
]

func _ready():
	# Initialize light cache
	cache_all_lights()

# Cache all light references for better performance
func cache_all_lights():
	light_cache.clear()
	var table_node = get_node("..")
	print("Mission lights: Caching lights...")
	
	for light_path in mission_light_paths:
		var light = table_node.get_node_or_null(light_path)
		if light and light.has_method("set_mode") and "LightMode" in light:
			light_cache[light_path] = light
			print("Cached light: ", light_path, " -> ", light)
		else:
			# Try alternative paths or search for the light
			var light_name = light_path.get_file()
			var found_light = find_light_by_name(table_node, light_name)
			if found_light:
				light_cache[light_path] = found_light
				print("Found and cached light: ", light_path, " -> ", found_light)
			else:
				print("Light not found: ", light_path)

# Recursively search for a light by name
func find_light_by_name(node: Node, light_name: String) -> Node:
	# Check if this node is the light we're looking for
	if node.name == light_name and node.has_method("set_mode") and "LightMode" in node:
		return node
	
	# Search children
	for child in node.get_children():
		var found = find_light_by_name(child, light_name)
		if found:
			return found
	
	return null

# Set all mission lights to inactive except specified exceptions
func set_all_lights_inactive(exceptions: Array = []):
	for light_path in light_cache:
		var light = light_cache[light_path]
		var light_name = light_path.get_file()
		
		if light_name in exceptions:
			continue  # Skip exceptions
			
		if light and light.has_method("set_mode") and "LightMode" in light:
			light.set_mode(light.LightMode.INACTIVE)

# Set all mission lights to active except specified exceptions  
func set_all_lights_active(exceptions: Array = []):
	for light_path in light_cache:
		var light = light_cache[light_path]
		var light_name = light_path.get_file()
		
		if light_name in exceptions:
			continue  # Skip exceptions
			
		if light and light.has_method("set_mode") and "LightMode" in light:
			light.set_mode(light.LightMode.ACTIVE)

# Set specific light to a mode by exact path
func set_light_mode_by_path(light_path: String, mode):
	print("Mission lights: set_light_mode_by_path(", light_path, ", ", mode, ")")
	if light_path in light_cache:
		var cached_light = light_cache[light_path]
		if cached_light and cached_light.has_method("set_mode") and "LightMode" in cached_light:
			print("Mission lights: Calling cached_light.set_mode(", mode, ") on ", cached_light)
			cached_light.set_mode(mode)
			return true
	
	# If not found in cache, try to find it
	var table_node = get_node("..")
	var found_light = table_node.get_node_or_null(light_path)
	if found_light and found_light.has_method("set_mode") and "LightMode" in found_light:
		print("Mission lights: Calling found_light.set_mode(", mode, ") on ", found_light)
		found_light.set_mode(mode)
		# Add to cache for future use
		light_cache[light_path] = found_light
		return true
	
	push_warning("Light not found at path: " + light_path)
	return false

# Set specific light to a mode
func set_light_mode(light_name: String, mode):
	for light_path in light_cache:
		if light_path.get_file() == light_name or light_path.ends_with("/" + light_name):
			var cached_light = light_cache[light_path]
			if cached_light and cached_light.has_method("set_mode") and "LightMode" in cached_light:
				cached_light.set_mode(mode)
				return true
	
	# If not found in cache, try to find it
	var table_node = get_node("..")
	var found_light = find_light_by_name(table_node, light_name)
	if found_light:
		found_light.set_mode(mode)
		# Add to cache for future use
		light_cache[light_name] = found_light
		return true
	
	push_warning("Light not found: " + light_name)
	return false

# Control lights for left sinkhole activation (all inactive except left sinkhole)
func activate_left_sinkhole_mode():
	set_all_lights_inactive()
	set_light_mode("left_sinkhole_light", get_light_mode_active())
	print("Mission lights: Left sinkhole mode activated")

# Get the ACTIVE light mode (handles different light implementations)
func get_light_mode_active():
	# Try to get from any cached light
	for light in light_cache.values():
		if light and "LightMode" in light:
			var active_mode = light.LightMode.ACTIVE
			print("Mission lights: get_light_mode_active() from ", light, " -> ", active_mode)
			return active_mode
	
	# Fallback - this should be standardized across all light scripts
	print("Mission lights: get_light_mode_active() fallback -> 1")
	return 1  # Assuming ACTIVE = 1

# Get the INACTIVE light mode
func get_light_mode_inactive():
	# Try to get from any cached light
	for light in light_cache.values():
		if light and "LightMode" in light:
			return light.LightMode.INACTIVE
	
	# Fallback - this should be standardized across all light scripts  
	return 0  # Assuming INACTIVE = 0

# Control lights based on mission progress
func update_lights_for_mission_progress(_active_mission, current_phase_requirements: Dictionary):
	print("Mission lights: Updating lights for mission progress")
	print("Phase requirements: ", current_phase_requirements)
	
	# Set all lights to inactive first
	set_all_lights_inactive()
	
	# Activate lights for current phase requirements
	for collision_type in current_phase_requirements:
		var light_paths = get_light_paths_for_collision_type(collision_type)
		print("Collision type: ", collision_type, " -> Light paths: ", light_paths)
		for light_path in light_paths:
			var success = set_light_mode_by_path(light_path, get_light_mode_active())
			print("Setting light path: ", light_path, " -> Success: ", success)

# Map collision types to light paths (can return multiple paths)
func get_light_paths_for_collision_type(collision_type) -> Array:
	# Get missions node to access CollisionType enum
	var missions_node = get_node("../missions")
	if not missions_node:
		return []
	
	match collision_type:
		missions_node.CollisionType.BUMPER:
			return ["bumper_light"]
		missions_node.CollisionType.ALCOVE_BUMPER:
			return ["bumper_light"]
		missions_node.CollisionType.RAMP:
			return ["rail/ramp_light"]
		missions_node.CollisionType.CANDLESET:
			return ["candleset/target_lights"]
		missions_node.CollisionType.TARGET_SET1:
			return ["targets1/target_lights"]
		missions_node.CollisionType.TARGET_SET2:
			return ["targets2/target_lights"]
		missions_node.CollisionType.ROLLOVER1:
			return ["rollover1/rollover_light"]
		missions_node.CollisionType.ROLLOVER2:
			return ["rollover2/rollover_light"]
		missions_node.CollisionType.SINKHOLE_LEFT:
			return ["left_sinkhole_light"]
		missions_node.CollisionType.SINKHOLE_RIGHT:
			return ["right_sinkhole_light"]
		_:
			return []

# Map collision types to light names (backward compatibility)
func get_light_name_for_collision_type(collision_type) -> String:
	var paths = get_light_paths_for_collision_type(collision_type)
	if paths.size() > 0:
		return paths[0].get_file()
	return ""

# Deactivate individual rollover light
func deactivate_individual_rollover_light(rollover_number: int):
	print("Mission lights: Deactivating rollover ", rollover_number, " light")
	
	var light_path = ""
	match rollover_number:
		1:
			light_path = "rollover1/rollover_light"
		2:
			light_path = "rollover2/rollover_light"
		_:
			push_warning("Invalid rollover number: " + str(rollover_number))
			return
	
	var success = set_light_mode_by_path(light_path, get_light_mode_inactive())
	print("Mission lights: Deactivated rollover ", rollover_number, " light -> Success: ", success)

# Reset all lights (called on ball respawn)
func reset_all_lights():
	set_all_lights_inactive()
	print("All mission lights reset to inactive")
