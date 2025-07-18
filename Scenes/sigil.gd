extends Node2D

# References to the sigil line sprites
@onready var sigil_line_1 = $sigil_line_1
@onready var sigil_line_2 = $sigil_line_2
@onready var sigil_line_3 = $sigil_line_3
@onready var sigil_line_4 = $sigil_line_4

# References to the mission completion letter sprites
@onready var letter_m = $M
@onready var letter_o = $O
@onready var letter_l = $L
@onready var letter_o2 = $O2
@onready var letter_c = $C
@onready var letter_h = $H

# Reference to the full sigil sprite for timed missions
@onready var sigil_full = $sigil_full

# Reference to missions system
var missions_node: Node2D
var current_mission_id: String = ""
var is_timed_mission_active: bool = false

func _ready():
	# Connect to missions system
	missions_node = get_node("../missions")
	if missions_node:
		missions_node.mission_started.connect(_on_mission_started)
		missions_node.mission_phase_advanced.connect(_on_mission_phase_advanced)
		missions_node.mission_progress_updated.connect(_on_mission_progress_updated)
		missions_node.mission_completed.connect(_on_mission_completed)
	
	# Initialize all sigil lines, letters, and full sigil as invisible
	reset_sigil_lines()
	reset_mission_letters()
	reset_sigil_full()

func _process(_delta):
	# Update timed sigil dissolve effect
	if is_timed_mission_active and sigil_full and sigil_full.visible:
		update_timed_sigil_dissolve()

func reset_sigil_lines(animate: bool = false):
	# Set all sigil lines to invisible
	var sigil_lines = [sigil_line_1, sigil_line_2, sigil_line_3, sigil_line_4]
	
	if animate:
		# Animate fade-out with staggered timing (reverse order)
		for i in range(sigil_lines.size()):
			var line = sigil_lines[sigil_lines.size() - 1 - i]  # Reverse order: 4, 3, 2, 1
			if line:
				animate_sigil_line_out(line, i * 0.15)  # Stagger by 0.15 seconds
	else:
		# Instant hide (for initialization)
		for line in sigil_lines:
			if line:
				line.visible = false
				line.modulate.a = 0.0
				line.scale = Vector2(1.0, 1.0)  # Reset scale

func reset_mission_letters(animate: bool = false):
	# Set all mission completion letters to invisible
	var letters = [letter_m, letter_o, letter_l, letter_o2, letter_c, letter_h]
	
	if animate:
		# Animate fade-out with staggered timing (reverse order)
		for i in range(letters.size()):
			var letter = letters[letters.size() - 1 - i]  # Reverse order
			if letter:
				animate_letter_out(letter, i * 0.1)  # Stagger by 0.1 seconds
	else:
		# Instant hide (for initialization)
		for letter in letters:
			if letter:
				letter.visible = false
				letter.modulate.a = 0.0
				letter.scale = Vector2(1.0, 1.0)  # Reset scale

func update_mission_letters():
	# Get completed missions count and show letters accordingly
	if not missions_node:
		return
	
	var completed_missions = missions_node.get_completed_missions()
	var mission_order = ["raise_the_dead", "communion_with_the_void", "wrath_of_baalhorn", "requiem_of_the_moon", "the_wardens_coffers", "the_stone_blacksmiths_apprentice"]
	var letters = [letter_m, letter_o, letter_l, letter_o2, letter_c, letter_h]
	
	# Count how many missions in order have been completed
	var completed_count = 0
	for mission_id in mission_order:
		if mission_id in completed_missions:
			completed_count += 1
		else:
			break  # Stop at first uncompleted mission
	
	# Show letters up to completed missions count
	for i in range(letters.size()):
		var letter = letters[i]
		if letter:
			if i < completed_count:
				# Show this letter with animation
				animate_letter_in(letter)
			else:
				# Hide this letter (if visible)
				if letter.visible:
					animate_letter_out(letter)

func reset_sigil_full():
	# Reset the full sigil sprite
	if sigil_full:
		sigil_full.visible = false
		sigil_full.modulate.a = 1.0
		# Reset any potential shader effects
		if sigil_full.material:
			sigil_full.material = null

func activate_timed_sigil():
	# Activate the full sigil for timed missions
	if sigil_full:
		# Hide all sigil lines first
		reset_sigil_lines()
		
		# Show the full sigil
		sigil_full.visible = true
		sigil_full.modulate.a = 1.0
		
		# Create a dissolve material if it doesn't exist
		setup_dissolve_material()
		
		is_timed_mission_active = true

func setup_dissolve_material():
	# Create a shader material for the dissolve effect
	if sigil_full and not sigil_full.material:
		var shader_material = ShaderMaterial.new()
		var shader = Shader.new()
		
		# Simple dissolve shader code
		shader.code = """
		shader_type canvas_item;

		uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

		void fragment() {
			vec4 tex_color = texture(TEXTURE, UV);
			
			// Create dissolve effect from top to bottom
			float dissolve_line = 1.0 - UV.y;
			
			if (dissolve_line < dissolve_amount) {
				tex_color.a = 0.0;
			}
			
			COLOR = tex_color;
		}
		"""
		
		shader_material.shader = shader
		shader_material.set_shader_parameter("dissolve_amount", 0.0)
		sigil_full.material = shader_material

func update_timed_sigil_dissolve():
	# Update the dissolve effect based on mission timer
	if not missions_node or not missions_node.mission_timer:
		return
	
	var timer = missions_node.mission_timer
	if timer.is_stopped():
		return
	
	# Calculate dissolve progress (0.0 = full, 1.0 = completely dissolved)
	var time_left = timer.time_left
	var total_time = timer.wait_time
	var progress = 1.0 - (time_left / total_time)  # 0.0 at start, 1.0 at end
	
	# Update shader parameter
	if sigil_full and sigil_full.material:
		sigil_full.material.set_shader_parameter("dissolve_amount", progress)

func update_sigil_for_phase(phase_number: int):
	# Check if this is a timed mission (mission 3: wrath_of_baalhorn)
	if current_mission_id == "wrath_of_baalhorn":
		# For timed mission, use sigil_full instead of lines
		activate_timed_sigil()
		return
	
	# Show sigil lines sequentially based on current phase with animation
	# phase_number is 0-indexed, so we add 1 to get the line number
	var lines_to_show = phase_number + 1
	
	# Array of sigil lines for easier iteration
	var sigil_lines = [sigil_line_1, sigil_line_2, sigil_line_3, sigil_line_4]
	
	# Animate lines up to current phase
	for i in range(sigil_lines.size()):
		var line = sigil_lines[i]
		if line:
			if i < lines_to_show:
				# Show this line with fade-in animation
				animate_sigil_line_in(line, i * 0.2)  # Stagger animations by 0.2 seconds
			else:
				# Hide this line (shouldn't normally happen, but safety check)
				line.visible = false
				line.modulate.a = 0.0

func animate_sigil_line_in(sigil_line: Node2D, delay: float = 0.0):
	# Don't animate if already visible
	if sigil_line.visible and sigil_line.modulate.a >= 1.0:
		return
	
	# Set up initial state
	sigil_line.visible = true
	sigil_line.modulate.a = 0.0
	
	# Create tween for fade-in animation
	var tween = create_tween()
	
	# Add delay if specified
	if delay > 0.0:
		tween.tween_interval(delay)
	
	# Animate alpha from 0 to 1 over 0.8 seconds with smooth easing
	tween.tween_property(sigil_line, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Optional: Add a subtle glow effect by scaling slightly
	tween.parallel().tween_property(sigil_line, "scale", Vector2(1.05, 1.05), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sigil_line, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

func animate_sigil_line_out(sigil_line: Node2D, delay: float = 0.0):
	# Don't animate if already hidden
	if not sigil_line.visible or sigil_line.modulate.a <= 0.0:
		return
	
	# Create tween for fade-out animation
	var tween = create_tween()
	
	# Add delay if specified
	if delay > 0.0:
		tween.tween_interval(delay)
	
	# Animate scale down slightly while fading out for a nice effect
	tween.parallel().tween_property(sigil_line, "scale", Vector2(0.95, 0.95), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Animate alpha from current value to 0 over 0.5 seconds
	tween.parallel().tween_property(sigil_line, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Hide the line and reset scale when animation completes
	tween.tween_callback(func():
		sigil_line.visible = false
		sigil_line.scale = Vector2(1.0, 1.0)
	)

func animate_letter_in(letter: Node2D, delay: float = 0.0):
	# Don't animate if already visible
	if letter.visible and letter.modulate.a >= 1.0:
		return
	
	# Set up initial state
	letter.visible = true
	letter.modulate.a = 0.0
	
	# Create tween for fade-in animation
	var tween = create_tween()
	
	# Add delay if specified
	if delay > 0.0:
		tween.tween_interval(delay)
	
	# Animate alpha from 0 to 1 over 1.0 seconds with smooth easing
	tween.tween_property(letter, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Add a dramatic glow effect by scaling up then down
	tween.parallel().tween_property(letter, "scale", Vector2(1.2, 1.2), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(letter, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

func animate_letter_out(letter: Node2D, delay: float = 0.0):
	# Skip if letter doesn't exist
	if not letter:
		return
	
	# Create tween for fade-out animation
	var tween = create_tween()
	
	# Add delay if specified
	if delay > 0.0:
		tween.tween_interval(delay)
	
	# Animate scale down while fading out
	tween.parallel().tween_property(letter, "scale", Vector2(0.8, 0.8), 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Animate alpha to 0 over 0.6 seconds
	tween.parallel().tween_property(letter, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Hide the letter and reset properties when animation completes
	tween.tween_callback(func():
		letter.visible = false
		letter.modulate.a = 0.0
		letter.scale = Vector2(1.0, 1.0)
	)

func _on_mission_started(mission):
	# Track the current mission
	current_mission_id = mission.id
	
	# When a mission starts, show the sigil line for the current phase
	update_sigil_for_phase(mission.current_phase)

func _on_mission_phase_advanced(mission):
	# Update sigil when phase advances
	if mission.id == current_mission_id:
		update_sigil_for_phase(mission.current_phase)

func _on_mission_progress_updated(_mission, _collision_type, _current_count, _required_count):
	# Mission progress updated - no longer need to check phase changes here
	pass

func _on_mission_completed(_mission):
	# Reset timed mission state
	if current_mission_id == "wrath_of_baalhorn":
		is_timed_mission_active = false
		reset_sigil_full()
	else:
		# When a mission is completed, hide all sigil lines with animation
		reset_sigil_lines(true)
	
	# Clear current mission tracking
	current_mission_id = ""
	
	# Update mission completion letters
	# Use a small delay to let the sigil lines start their animation first
	await get_tree().create_timer(0.3).timeout
	update_mission_letters()
	
	# Check if all missions are completed (cycle reset)
	if missions_node:
		var completed_missions = missions_node.get_completed_missions()
		var mission_order = ["raise_the_dead", "communion_with_the_void", "wrath_of_baalhorn", "requiem_of_the_moon", "the_wardens_coffers", "the_stone_blacksmiths_apprentice"]
		
		# If all missions completed and about to cycle, reset letters
		if completed_missions.size() >= mission_order.size():
			# Wait a bit to show the complete word, then reset
			await get_tree().create_timer(2.0).timeout
			reset_mission_letters(true)
