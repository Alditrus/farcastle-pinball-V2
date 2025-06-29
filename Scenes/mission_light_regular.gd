extends Node2D

enum LightMode { ACTIVE, INACTIVE, IDLE }

var current_mode: LightMode = LightMode.IDLE
var active_sprite: Sprite2D
var blink_timer: Timer
var blink_offset: float

func _ready():
	active_sprite = get_node("active")
	
	blink_timer = Timer.new()
	add_child(blink_timer)
	blink_timer.wait_time = 1.0
	blink_timer.timeout.connect(_on_blink_timer_timeout)
	
	blink_offset = randf() * 2.0
	
	set_mode(current_mode)

func set_mode(mode: LightMode):
	current_mode = mode
	
	match mode:
		LightMode.ACTIVE:
			active_sprite.visible = true
			blink_timer.stop()
		
		LightMode.INACTIVE:
			active_sprite.visible = false
			blink_timer.stop()
		
		LightMode.IDLE:
			blink_timer.wait_time = 1.0 + blink_offset
			blink_timer.start()

func _on_blink_timer_timeout():
	if current_mode == LightMode.IDLE:
		active_sprite.visible = !active_sprite.visible
