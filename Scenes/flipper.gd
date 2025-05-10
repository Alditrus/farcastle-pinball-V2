# This script manages a flipper.

extends Node2D

# On a given flipper instance, you can override the exported parameters using the Godot inspector.

# Use this control to operate the flipper.
# Unfortunately Godot 3.x can't tell the difference between the left and right shift keys,
# so you may not want to use the shift keys for your flippers.
@export var keycode = "ui_left"

# The flipper takes this long to traverse its arc.
@export var snap_time = 0.25

# The flipper's arc is this big, in degrees.
@export var snap_angle = 50


@export var flipper_proximity: float = 150.0

var intermediate_time = 0.0
var was_pressing = false
var flipper_body: RigidBody2D
var is_active = false
var last_rotation = 0.0
var current_rotation_speed = 0.0
var is_tilted = false  # Track whether the table is tilted

func _ready():
	flipper_body = $RigidBody2D
	add_to_group("flippers")
	
	# Set up collision checking area
	var area = Area2D.new()
	area.name = "FlipperArea"
	flipper_body.add_child(area)
	
	# Create a collision shape that matches the flipper polygon
	var collision_shape = CollisionPolygon2D.new()
	collision_shape.polygon = flipper_body.get_node("CollisionPolygon2D").polygon
	collision_shape.position = flipper_body.get_node("CollisionPolygon2D").position
	collision_shape.scale = flipper_body.get_node("CollisionPolygon2D").scale
	area.add_child(collision_shape)
	
	# Connect body entered signal
	area.body_entered.connect(_on_area_body_entered)
	
	# Try to find the nudge system and connect to its tilt signal
	await get_tree().process_frame
	var nudge_system = find_nudge_system()
	if nudge_system:
		nudge_system.tilt_state_changed.connect(_on_tilt_state_changed)

# Find the nudge system in the scene
func find_nudge_system():
	# Check if we're in a table scene
	var parent = get_parent()
	while parent:
		# Try to find nudge system as a direct child of our parent
		for child in parent.get_children():
			if child.has_method("handle_tilt") and child.has_signal("tilt_state_changed"):
				return child
		
		# Move up in the scene tree
		parent = parent.get_parent()
	
	# If we can't find it through the scene tree, try to find it by group
	var nudge_nodes = get_tree().get_nodes_in_group("nudge_system")
	if nudge_nodes.size() > 0:
		return nudge_nodes[0]
	
	return null

# Handle tilt state changes
func _on_tilt_state_changed(tilted):
	is_tilted = tilted

func _physics_process(delta):
	var is_pressing = Input.is_action_pressed(keycode) and not is_tilted  # Disable when tilted
	var prev_rotation = flipper_body.rotation_degrees
	
	if is_pressing:
		is_active = true
		if intermediate_time < snap_time:
			intermediate_time += delta
			if intermediate_time > snap_time:
				intermediate_time = snap_time
			flipper_body.rotation_degrees = (intermediate_time / snap_time) * snap_angle
	else:
		is_active = false
		if intermediate_time > 0:
			intermediate_time -= delta
			if intermediate_time < 0:
				intermediate_time = 0
			flipper_body.rotation_degrees = (intermediate_time / snap_time) * snap_angle
	
	# Calculate current rotation speed
	current_rotation_speed = (flipper_body.rotation_degrees - prev_rotation) / delta
	
	# Check for balls when flipper is moving rapidly in either direction
	if abs(current_rotation_speed) > 50 and is_active:
		check_for_nearby_balls()
	
	was_pressing = is_pressing

func check_for_nearby_balls():
	# Find all balls in the scene
	var balls = get_tree().get_nodes_in_group("balls")
	
	for ball in balls:
		# Check distance to the ball
		var distance = (ball.global_position - flipper_body.global_position).length()
		
		# Only consider balls close to the flipper
		if distance < flipper_proximity:
			# Create a physics ray test to check if the ball is close to our flipper
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.new()
			query.from = flipper_body.global_position
			query.to = ball.global_position
			query.collision_mask = ball.collision_layer
			query.exclude = [flipper_body]
			
			var result = space_state.intersect_ray(query)
			
			# If ray hits the ball, it's in a position where the flipper can hit it
			if result and result.collider == ball:
				launch_ball(ball)

func _on_area_body_entered(body):
	if body.is_in_group("balls") and is_active and abs(current_rotation_speed) > 30:
		launch_ball(body)

func launch_ball(ball):
	# Ensure the ball is not sleeping
	ball.sleeping = false
	
	# Calculate distance from flipper to determine launch force
	# Reverse the force factor: more force further from pivot
	var distance = (ball.global_position - flipper_body.global_position).length()
	var force_factor = clamp(distance / flipper_proximity, 0, 1.0)
	
	# Calculate direction from flipper to ball (similar to bumper logic)
	var direction = (ball.global_position - flipper_body.global_position).normalized()
	
	# Mix the bumper-style physics with flipper direction
	# Bias the direction upward (negative Y in Godot) by adding Vector2.UP
	var launch_direction = (direction + Vector2.UP * 2.0).normalized()
	
	# Apply force based on rotation speed, distance and upward bias
	var base_force = 500 * force_factor
	var rotation_boost = abs(current_rotation_speed) * 0.5 * force_factor
	var launch_force = launch_direction * (base_force + rotation_boost)
	
	# Apply impulse to the ball
	ball.apply_central_impulse(launch_force)