extends Node2D

var is_dragging = false
var drag_start_position = Vector2.ZERO
var initial_position = Vector2.ZERO
var min_x_position = 0
var max_x_position = 0
var drag_area: Area2D
var has_been_dragged = false  # Track if the goathead has been dragged at least once

var eject_sound = preload("res://Assets/sounds/eject.wav")

# Called when the node enters the scene tree for the first time.
func _ready():
	# Make sure this node always processes even when the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Store the initial position
	initial_position = position
	
	# Set min and max X bounds (adjust these values as needed)
	min_x_position = initial_position.x - 180
	max_x_position = initial_position.x + 180
	
	# Get reference to the Area2D
	drag_area = $DragArea
	
	# Make sure we have the area and connect input events
	if drag_area:
		drag_area.input_event.connect(_on_drag_area_input_event)
	else:
		# If there's no Area2D yet, create one
		drag_area = Area2D.new()
		drag_area.name = "DragArea"
		add_child(drag_area)
		
		# Create a collision shape for the area
		var collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(100, 100) # Adjust size as needed
		collision_shape.shape = shape
		drag_area.add_child(collision_shape)
		
		# Connect input events
		drag_area.input_event.connect(_on_drag_area_input_event)
	
	# Try to find and freeze the ball when the scene starts
	var ball = _find_ball()
	if ball:
		ball.freeze = true
		ball.visible = false
	
# Handle input events for the drag area
func _on_drag_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_start_position = get_global_mouse_position()
				has_been_dragged = true  # User has started dragging
			else:
				# Release button - handle release
				_handle_release()

# Helper function to find the ball in either context
func _find_ball():
	var ball
	
	# First try direct access (when running minigame directly)
	ball = get_parent().get_node_or_null("minigameball")
	if not ball:
		# Try the original node name from the packed scene
		ball = get_parent().get_node_or_null("ball")
	
	# If not found, try to find the ball in the scene tree
	if not ball:
		# Try to find the ball in the Minigame scene within a SubViewport
		var root = get_tree().get_root()
		
		var table = root.get_node_or_null("Table")
		if table:
			var minigame_window = table.get_node_or_null("minigamewindow")
			if minigame_window:
				var sub_viewport = minigame_window.get_node_or_null("SubViewport")
				if sub_viewport:
					var minigame = sub_viewport.get_node_or_null("Minigame")
					if minigame:
						ball = minigame.get_node_or_null("minigameball")
						if not ball:
							# Try the original node name from the packed scene
							ball = minigame.get_node_or_null("ball")
	
	return ball

# Called every frame to handle dragging
func _process(_delta):
	if is_dragging:
		var current_mouse_pos = get_global_mouse_position()

		# Check if cursor/finger left the viewport bounds
		var viewport_rect = get_viewport_rect()
		if not viewport_rect.has_point(current_mouse_pos):
			# Cursor/finger left screen - trigger release
			_handle_release()
			return

		var new_x = position.x + (current_mouse_pos.x - drag_start_position.x)

		# Clamp the position within bounds
		new_x = clamp(new_x, min_x_position, max_x_position)

		# Update position (only X axis)
		position.x = new_x

		# Update drag start for smooth dragging
		drag_start_position = current_mouse_pos

# Centralized release handler
func _handle_release():
	if not is_dragging:
		return

	# Stop dragging
	is_dragging = false

	# Only release the ball if the goathead has been dragged at least once
	if has_been_dragged:
		# Find the ball
		var ball = _find_ball()
		var spawn_area = $SpawnArea

		if ball and spawn_area:
			AudioCollection.play_sfx(eject_sound)

			# Make ball visible and position it at spawn point
			ball.visible = true
			ball.global_position = spawn_area.global_position

			# Completely reset physics state
			ball.freeze = false
			ball.sleeping = false
			ball.can_sleep = false
