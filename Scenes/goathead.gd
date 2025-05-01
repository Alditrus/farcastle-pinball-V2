extends Node2D

var is_dragging = false
var drag_start_position = Vector2.ZERO
var initial_position = Vector2.ZERO
var min_x_position = 0
var max_x_position = 0
var drag_area: Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Store the initial position
	initial_position = position
	
	# Set min and max X bounds (adjust these values as needed)
	min_x_position = initial_position.x - 150
	max_x_position = initial_position.x + 150
	
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
	
# Handle input events for the drag area
func _on_drag_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_start_position = get_global_mouse_position()
			else:
				# Stop dragging
				is_dragging = false
				
				# Move the ball to the SpawnArea position
				var ball = get_parent().get_node("Ball")
				var spawn_area = $SpawnArea
				if ball and spawn_area:
					# Re-enable visibility and unfreeze the ball
					ball.visible = true
					ball.freeze = false
					ball.global_position = spawn_area.global_position

# Called every frame to handle dragging
func _process(_delta):
	if is_dragging:
		var current_mouse_pos = get_global_mouse_position()
		var new_x = position.x + (current_mouse_pos.x - drag_start_position.x)
		
		# Clamp the position within bounds
		new_x = clamp(new_x, min_x_position, max_x_position)
		
		# Update position (only X axis)
		position.x = new_x
		
		# Update drag start for smooth dragging
		drag_start_position = current_mouse_pos
