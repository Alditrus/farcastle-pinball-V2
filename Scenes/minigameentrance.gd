extends Node2D

# Reference to the jaw sprite and area
@onready var jaw_sprite = $jaw
@onready var entrance_area = $Area2D
@onready var flame1 = $activeflame1
@onready var flame2 = $activeflame2

# Initial Y position of the jaw
var jaw_initial_y = 0
var jaw_open_offset = 30  # How far the jaw should move (30 pixels down)
var missions_node: Node
var is_entrance_active = false

# Called when the node enters the scene tree for the first time
func _ready():
	# Wait a frame to ensure all nodes are initialized
	await get_tree().process_frame
	
	# Store initial jaw position
	if jaw_sprite:
		jaw_initial_y = jaw_sprite.position.y
	
	# Disable the area initially
	if entrance_area:
		entrance_area.monitoring = false
		entrance_area.monitorable = false
	
	# Disable flames initially
	if flame1:
		flame1.emitting = false
	if flame2:
		flame2.emitting = false
	
	# Find and connect to missions system
	missions_node = get_node_or_null("/root/Table/Missions")
	if missions_node:
		missions_node.jaw_progress.connect(_on_jaw_progress)
		
		# Update the UI with the target object type
		update_target_hint()

# Update the jaw position based on progress (0.0 to 1.0)
func _on_jaw_progress(progress_percent: float):
	if jaw_sprite:
		# Calculate the jaw's new Y position
		var offset = jaw_open_offset * progress_percent
		jaw_sprite.position.y = jaw_initial_y + offset
	
	# If jaw is fully open, activate the minigame entrance
	if progress_percent >= 1.0 and not is_entrance_active:
		activate_minigame_entrance()

# Add a visual indicator for what needs to be hit
func update_target_hint():
	if missions_node:
		var target_name = missions_node.get_jaw_target_name()
		var required_hits = missions_node.jaw_hits_required
		print("Hint: Hit %s %d times to open the jaw" % [target_name, required_hits])
		# Could add a label or other UI element here

# Activate the minigame entrance when jaw is fully open
func activate_minigame_entrance():
	if entrance_area:
		# Enable the collision area using set_deferred to avoid in/out signal errors
		entrance_area.set_deferred("monitoring", true)
		entrance_area.set_deferred("monitorable", true)
		is_entrance_active = true
		
		# Visual feedback
		print("🎮 MINIGAME ENTRANCE ACTIVATED! 🎮")
		
		# Optional: Add visual effects
		add_entrance_effects()

# Add visual effects to indicate the entrance is active
func add_entrance_effects():
	# You could add particles, animation, or other visual effects here
	print("Minigame entrance is now active and ready for the ball!")
	
	# Activate the particle flame effects
	if flame1:
		flame1.emitting = true
	if flame2:
		flame2.emitting = true
	
	# Make the jaw sprite flash
	var tween = create_tween()
	tween.tween_property(jaw_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property(jaw_sprite, "modulate", Color(1, 1, 1), 0.2)
	tween.set_loops(3)

# Reset the entrance (called when resetting the game)
func reset_entrance():
	if entrance_area:
		entrance_area.monitoring = false
		entrance_area.monitorable = false
		is_entrance_active = false
	
	# Turn off flame particles
	if flame1:
		flame1.emitting = false
	if flame2:
		flame2.emitting = false
		
	if jaw_sprite:
		jaw_sprite.position.y = jaw_initial_y
		jaw_sprite.modulate = Color(1, 1, 1)
