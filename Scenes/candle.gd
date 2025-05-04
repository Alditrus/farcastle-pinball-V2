extends Node2D

# Boolean to track candle active state
var is_active = false

# Reference to the particle effect node
@onready var particles = $CPUParticles2D

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
		
		# Update particle effect based on new state
		update_particle_effect()
		
		# Debug message
		if is_active:
			print("Candle activated")
		else:
			print("Candle deactivated")

# Updates the particle effect based on the is_active state
func update_particle_effect():
	if particles:
		particles.emitting = is_active

# Public method to explicitly set the candle state
func set_active(active):
	if is_active != active:
		is_active = active
		update_particle_effect()

# Public method to check if the candle is active
func is_candle_active():
	return is_active

# Method to reset the candle to its default state
func reset():
	is_active = false
	update_particle_effect()
