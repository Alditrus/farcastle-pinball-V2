extends Node2D

# Boolean to track candle active state
var is_active = false
var is_complete = false

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
		# Toggle the candle state
		is_active = !is_active

		# Increase score
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.increase_score("candle")
		
		# Update particle effect based on new state
		update_particle_effect()
		
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
