extends Node2D

# Central controller for all mission lights distributed throughout the game

# Dictionary to cache light references for performance
var light_cache: Dictionary = {}

# List of light paths to control (relative to table root)
var mission_light_paths = [
	"bumper_light",                    # Direct child of table
	"left_sinkhole_light",            # Direct child of table
	"right_sinkhole_light",           # Direct child of table
	"candleset/target_lights",        # Light within candleset scene
	"targets1/target_lights",         # Light within targets1 scene
	"targets2/target_lights",         # Light within targets2 scene
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
	
	for light_path in mission_light_paths:
		var light = table_node.get_node_or_null(light_path)
		if light and light.has_method("set_mode") and "LightMode" in light:
			light_cache[light_path] = light
		else:
			# Try alternative paths or search for the light
			var light_name = light_path.get_file()
			var found_light = find_light_by_name(table_node, light_name)
			if found_light:
				light_cache[light_path] = found_light

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

# Set specific light to a mode
func set_light_mode(light_name: String, mode):
	for light_path in light_cache:
		if light_path.get_file() == light_name or light_path.ends_with("/" + light_name):
			var light = light_cache[light_path]
			if light and light.has_method("set_mode") and "LightMode" in light:
				light.set_mode(mode)
				return true
	
	# If not found in cache, try to find it
	var table_node = get_node("..")
	var light = find_light_by_name(table_node, light_name)
	if light:
		light.set_mode(mode)
		# Add to cache for future use
		light_cache[light_name] = light
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
			return light.LightMode.ACTIVE
	
	# Fallback - this should be standardized across all light scripts
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
func update_lights_for_mission_progress(active_mission, current_phase_requirements: Dictionary):
	# Set all lights to inactive first
	set_all_lights_inactive()
	
	# Activate lights for current phase requirements
	for collision_type in current_phase_requirements:
		var light_name = get_light_name_for_collision_type(collision_type)
		if light_name != "":
			set_light_mode(light_name, get_light_mode_active())

# Map collision types to light names
func get_light_name_for_collision_type(collision_type) -> String:
	# Get missions node to access CollisionType enum
	var missions_node = get_node("../missions")
	if not missions_node:
		return ""
	
	match collision_type:
		missions_node.CollisionType.BUMPER:
			return "bumper_light"
		missions_node.CollisionType.ALCOVE_BUMPER:
			return "bumper_light"
		missions_node.CollisionType.RAMP:
			return "ramp_light"
		missions_node.CollisionType.CANDLESET:
			return "candleset_light"
		missions_node.CollisionType.TARGET_SET1:
			return "target_light"  # Could be more specific
		missions_node.CollisionType.TARGET_SET2:
			return "target_light"  # Could be more specific
		missions_node.CollisionType.ROLLOVER1:
			return "rollover_light"
		missions_node.CollisionType.ROLLOVER2:
			return "rollover_light"
		missions_node.CollisionType.SINKHOLE_LEFT:
			return "left_sinkhole_light"
		missions_node.CollisionType.SINKHOLE_RIGHT:
			return "right_sinkhole_light"
		_:
			return ""

# Reset all lights (called on ball respawn)
func reset_all_lights():
	set_all_lights_inactive()
	print("All mission lights reset to inactive")
