extends Node2D

@onready var sprite = $Sprite2D
var rotation_speed = 10.0

func _process(delta):
	var balls = get_tree().get_nodes_in_group("balls")	
	
	if balls.size() == 1:
		# Rotate Node2D to look at the ball
		var ball = balls[0]
		var direction = ball.global_position - global_position
		var angle = direction.angle()
		
		# Rotate the Node2D
		rotation = angle
		
		# Keep the sprite stationary by counter-rotating it
		if sprite:
			sprite.rotation = -rotation
	elif balls.size() > 1:
		# Rotate clockwise when multiple balls exist
		rotation += rotation_speed * delta
		
		# Keep the sprite stationary by counter-rotating it
		if sprite:
			sprite.rotation = -rotation
