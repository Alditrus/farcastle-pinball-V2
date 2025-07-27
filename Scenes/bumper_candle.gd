extends Node2D

# Boolean to track candle active state
var is_active = false
var is_complete = false

var flame_sound = preload("res://Assets/sounds/flame.wav")

# References to the particle effect nodes
@onready var normal_particles = $normalflame
@onready var complete_particles = $completeflame

# Signal to notify when candle state changes
signal candle_state_changed(candle_node, is_active)

func _ready():
	# Make sure the Area2D is configured for monitoring
	var area = $Area2D
	if area:
		area.monitoring = true
		area.monitorable = true
		
		# Set Area2D to be on all collision layers (32 layers, each bit represents a layer)
		area.collision_layer = 0xFFFFFFFF  # All 32 bits set to 1
		area.collision_mask = 0xFFFFFFFF   # Detect collisions on all layers
		
		# Connect signals
		area.body_entered.connect(_on_area_body_entered)
		
	# Initialize particle effect to match initial state (off)
	update_particle_effect()

# Called when a body enters the Area2D
func _on_area_body_entered(body):
	if body is RigidBody2D and body.is_in_group("balls"):
		# Only activate the candle if it's not already active (don't toggle off)
		if not is_active:
			is_active = true
			AudioCollection.play_sfx(flame_sound)

		# Increase score
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.increase_score("candle")
		
		# Update particle effect based on new state
		update_particle_effect()

		# Deactivate individual light when candle is hit
		deactivate_individual_light()
		
		# Emit signal to notify candleset
		emit_signal("candle_state_changed", self, is_active)

# Updates the particle effect based on the is_active state
func update_particle_effect():
	if normal_particles and complete_particles:
		if is_complete:
			# When complete, normal flame is off and complete flame is on
			normal_particles.emitting = false
			complete_particles.emitting = true
		else:
			# Normal state depends on is_active
			normal_particles.emitting = is_active
			complete_particles.emitting = false

# Public method to explicitly set the candle state
func set_active(active):
	if is_active != active:
		is_active = active
		update_particle_effect()
		emit_signal("candle_state_changed", self, is_active)

# Set the candle to complete state (special flame)
func set_complete(complete):
	is_complete = complete
	update_particle_effect()

# Public method to check if the candle is active
func is_candle_active():
	return is_active

# Method to reset the candle to its default state
func reset():
	is_active = false
	is_complete = false
	update_particle_effect()

# Deactivate individual light for this specific candle
func deactivate_individual_light():
	# Get the parent candleset, then get its target lights
	var candleset = get_parent()
	if not candleset:
		return
	
	var target_lights = candleset.get_node_or_null("target_lights")
	if not target_lights or not target_lights.has_method("set_mode"):
		return
	
	# Determine which candle this is and call the appropriate deactivation function
	match self.name:
		"candle1":
			if target_lights.has_method("deactivate_target_1"):
				target_lights.deactivate_target_1()
		"candle2":
			if target_lights.has_method("deactivate_target_2"):
				target_lights.deactivate_target_2()
		"candle3":
			if target_lights.has_method("deactivate_target_3"):
				target_lights.deactivate_target_3()
