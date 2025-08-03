extends Sprite2D

func _ready():
	# Start invisible at normal size
	modulate.a = 0.0
	scale = Vector2(0.25, 0.25)

func show_moloch_animation():
	print("BEHOLD, MOLOCH!!!")
	# Create tweens for alpha and scale separately
	var alpha_tween = create_tween()
	var scale_tween = create_tween()
	
	# Phase 1: Fade in (1 second)
	alpha_tween.tween_property(self, "modulate:a", 1.0, 1.0)
	# Phase 1: Scale up (1 second)
	scale_tween.tween_property(self, "scale", Vector2(3.0, 3.0), 2.0)
	# Phase 3: Fade out (1 second)
	alpha_tween.tween_property(self, "modulate:a", 0.0, 1.0)

	scale = Vector2(0.25, 0.25)
