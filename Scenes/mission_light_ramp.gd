extends Node2D

enum LightMode { ACTIVE, INACTIVE, IDLE }

var current_mode: LightMode = LightMode.IDLE
var active_sprites: Array[Sprite2D] = []
var sequence_timer: Timer
var current_sprite_index: int = 0
var blink_offset: float

func _ready():
	active_sprites.append(get_node("active_1"))
	active_sprites.append(get_node("active_2"))
	active_sprites.append(get_node("active_3"))
	
	sequence_timer = Timer.new()
	add_child(sequence_timer)
	sequence_timer.wait_time = 0.3
	sequence_timer.timeout.connect(_on_sequence_timer_timeout)
	
	blink_offset = randf() * 0.5
	
	set_mode(current_mode)

func set_mode(mode: LightMode):
	current_mode = mode
	
	match mode:
		LightMode.ACTIVE:
			_hide_all_sprites()
			sequence_timer.wait_time = 0.3 + blink_offset
			sequence_timer.start()
		
		LightMode.INACTIVE:
			_hide_all_sprites()
			sequence_timer.stop()
		
		LightMode.IDLE:
			_hide_all_sprites()
			sequence_timer.wait_time = 0.3 + (blink_offset * 2)
			sequence_timer.start()

func _hide_all_sprites():
	for sprite in active_sprites:
		sprite.visible = false

func _on_sequence_timer_timeout():
	if current_mode == LightMode.ACTIVE or current_mode == LightMode.IDLE:
		_hide_all_sprites()
		active_sprites[current_sprite_index].visible = true
		current_sprite_index = (current_sprite_index + 1) % active_sprites.size()
