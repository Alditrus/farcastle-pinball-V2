extends StaticBody2D

var dragging = false
var mouse_offset = Vector2()

func _ready():
	input_pickable = true
	
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				mouse_offset = global_position - get_global_mouse_position()
			else:
				dragging = false

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position() + mouse_offset
