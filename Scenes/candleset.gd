extends Node2D

# References to the candles in the set
@onready var candles = [$candle1, $candle2, $candle3]

# Signal to notify when all candles are activated
signal all_candles_activated

# Timeout for how long the complete flame effect should run (in seconds)
var complete_flame_duration = 1.0
var timer = null

func _ready():
	# Connect signals from each candle
	for candle in candles:
		candle.candle_state_changed.connect(_on_candle_state_changed)
	
	# Create a timer for the complete flame effect
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_complete_flame_timeout)
	add_child(timer)

# Called when any candle's state changes
func _on_candle_state_changed(_candle_node, _is_active):
	check_all_active()

# Check if all candles are active
func check_all_active():
	var all_active = true
	
	# Check if all candles are active
	for candle in candles:
		if not candle.is_candle_active():
			all_active = false
			break
	
	# If all candles are active, trigger the complete state
	if all_active:
		emit_signal("all_candles_activated")
		trigger_complete_flame()
		# Increase score - the bumper level upgrade is now handled in the score_label script
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.increase_score("candle_set_complete")
		# Record collision for mission system
		var missions_node = get_node("../missions")
		if missions_node:
			missions_node.record_collision(missions_node.CollisionType.CANDLESET)
			
			# Check if more CANDLESET completions are needed and reset lights if so
			reset_lights_if_more_completions_needed(missions_node, missions_node.CollisionType.CANDLESET)

# Trigger the complete flame effect on all candles
func trigger_complete_flame():
	# Set all candles to complete state
	for candle in candles:
		candle.set_complete(true)
	
	# Start the timer for how long the complete flame should be active
	timer.start(complete_flame_duration)

# Called when the complete flame effect timer expires
func _on_complete_flame_timeout():
	# Reset all candles
	for candle in candles:
		candle.set_active(false)
		candle.set_complete(false)

# Public method to reset all candles
func reset():
	for candle in candles:
		candle.reset()

# Reset target lights if more completions are needed for current mission phase
func reset_lights_if_more_completions_needed(missions_node, collision_type):
	# Get active missions
	var active_missions = missions_node.get_active_missions()
	
	for mission_id in active_missions:
		var mission = active_missions[mission_id]
		var current_phase_requirements = mission.phases[mission.current_phase]
		
		# Check if this collision type is required in current phase
		if collision_type in current_phase_requirements:
			var current_count = mission.progress[collision_type]
			var required_count = current_phase_requirements[collision_type]
			
			# If we still need more completions, reset the lights to active
			if current_count < required_count:
				var target_lights = get_node_or_null("target_lights")
				if target_lights and target_lights.has_method("set_mode"):
					# Get the ACTIVE mode properly
					if "LightMode" in target_lights:
						target_lights.set_mode(target_lights.LightMode.ACTIVE)
