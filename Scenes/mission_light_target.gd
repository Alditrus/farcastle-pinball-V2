extends Node2D

enum LightMode { ACTIVE, INACTIVE, IDLE }

var current_mode: LightMode = LightMode.IDLE
var target_1_light: Node2D
var target_2_light: Node2D
var target_3_light: Node2D
var sequence_timer: Timer
var current_light_index: int = 0

func _ready():
	target_1_light = get_node("target_1_light")
	target_2_light = get_node("target_2_light")
	target_3_light = get_node("target_3_light")
	
	sequence_timer = Timer.new()
	add_child(sequence_timer)
	sequence_timer.wait_time = 0.5
	sequence_timer.timeout.connect(_on_sequence_timer_timeout)
	
	set_mode(current_mode)

func set_mode(mode: LightMode):
	print("Target lights: set_mode called with ", mode, " on node ", self.name)
	current_mode = mode
	
	match mode:
		LightMode.ACTIVE:
			print("Target lights: Setting to ACTIVE")
			_set_all_lights_active()
			sequence_timer.stop()
		
		LightMode.INACTIVE:
			print("Target lights: Setting to INACTIVE")
			_set_all_lights_inactive()
			sequence_timer.stop()
		
		LightMode.IDLE:
			print("Target lights: Setting to IDLE")
			_set_all_lights_inactive()
			current_light_index = 0
			sequence_timer.start()

func activate_target_1():
	if current_mode == LightMode.ACTIVE:
		_set_target_light_active(target_1_light)

func activate_target_2():
	if current_mode == LightMode.ACTIVE:
		_set_target_light_active(target_2_light)

func activate_target_3():
	if current_mode == LightMode.ACTIVE:
		_set_target_light_active(target_3_light)

func deactivate_target_1():
	_set_target_light_inactive(target_1_light)

func deactivate_target_2():
	_set_target_light_inactive(target_2_light)

func deactivate_target_3():
	_set_target_light_inactive(target_3_light)

func _set_all_lights_inactive():
	_set_target_light_inactive(target_1_light)
	_set_target_light_inactive(target_2_light)
	_set_target_light_inactive(target_3_light)

func _set_all_lights_active():
	print("Target lights: _set_all_lights_active called")
	_set_target_light_active(target_1_light)
	_set_target_light_active(target_2_light)
	_set_target_light_active(target_3_light)

func _set_target_light_active(light_node: Node2D):
	var node_name = "null" if not light_node else str(light_node.name)
	print("Target lights: _set_target_light_active called for ", node_name)
	if light_node:
		var active_sprite = light_node.get_node("active")
		print("Target lights: active_sprite found: ", active_sprite)
		if active_sprite:
			active_sprite.visible = true
			print("Target lights: Set ", light_node.name, "/active sprite visible = true")

func _set_target_light_inactive(light_node: Node2D):
	if light_node:
		var active_sprite = light_node.get_node("active")
		if active_sprite:
			active_sprite.visible = false

func _on_sequence_timer_timeout():
	if current_mode == LightMode.IDLE:
		_set_all_lights_inactive()
		
		var lights = [target_1_light, target_2_light, target_3_light]
		var current_light = lights[current_light_index]
		_set_target_light_active(current_light)
		
		current_light_index = (current_light_index + 1) % lights.size()
