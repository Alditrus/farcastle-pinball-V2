extends Node2D

@onready var animated_sprite = $Area2D/AnimatedSprite2D
var timer = 0.0
var animation_active = false
var ball_exited = false
var initial_speed_scale = 1.0
var current_speed_scale = 1.0
var last_ball_position = Vector2.ZERO
var checking_ball_direction = false

# Constants for animation speed scaling
const BASE_VELOCITY = 300.0   # Reference velocity for normal animation speed
const MIN_SPEED_SCALE = 0.5   # Minimum animation speed scale
const MAX_SPEED_SCALE = 3.0   # Maximum animation speed scale
const SLOWDOWN_RATE = 1    # Higher value = faster exponential slowdown

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect signals for ball entering and exiting the area
	$Area2D.body_entered.connect(_on_area_2d_body_entered)
	$Area2D.body_exited.connect(_on_area_2d_body_exited)
	# Make sure the animation is not playing initially
	animated_sprite.stop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# If animation is active, track the timer
	if animation_active:
		timer += delta
		
		# Apply exponential slowdown after ball has exited
		if ball_exited:
			# Calculate new speed scale using exponential decay: e^(-kt)
			# where k is the slowdown rate and t is time since ball exited
			var decay_factor = exp(-SLOWDOWN_RATE * (timer - timer_at_exit))
			current_speed_scale = initial_speed_scale * decay_factor
			
			# Apply the new speed scale (keeping the same direction)
			animated_sprite.speed_scale = current_speed_scale
			
			# If animation becomes too slow, pause it on the last frame
			if current_speed_scale < 0.05:
				animated_sprite.pause()
				animation_active = false
				timer = 0.0
				ball_exited = false
		
		# If ball hasn't exited but time limit reached, pause animation
		elif timer >= 5.0:
			animated_sprite.pause()
			animation_active = false
			timer = 0.0
			ball_exited = false
	
	# Check ball direction if needed
	if checking_ball_direction:
		var balls = get_tree().get_nodes_in_group("balls")
		if balls.size() > 0:
			var ball = balls[0]
			
			# Get ball velocity magnitude for speed calculation
			var velocity_magnitude = ball.linear_velocity.length()
			# Calculate animation speed scale based on ball velocity
			var speed_scale = calculate_speed_scale(velocity_magnitude)
			initial_speed_scale = speed_scale
			current_speed_scale = speed_scale
			
			# Determine direction based on ball's velocity
			if ball.linear_velocity.y > 0:
				# Ball is moving downward (top to bottom)
				_play_animation_backwards(speed_scale)
			else:
				# Ball is moving upward (bottom to top)
				_play_animation_forwards(speed_scale)
				
			checking_ball_direction = false

# Calculate animation speed scale based on ball velocity
func calculate_speed_scale(velocity):
	# Calculate relative speed: ball velocity / base velocity
	var relative_speed = velocity / BASE_VELOCITY
	
	# Clamp between minimum and maximum speed scales
	return clamp(relative_speed, MIN_SPEED_SCALE, MAX_SPEED_SCALE)

# Called when a body enters the Area2D
func _on_area_2d_body_entered(body):
	# Check if the body is a ball
	if body.is_in_group("balls"):
		# Calculate velocity speed scale for both animation and scoring
		var velocity_magnitude = body.linear_velocity.length()
		var speed_scale = calculate_speed_scale(velocity_magnitude)
		
		# Store initial position and start checking direction
		# Increase score with speed scale
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.start_spinner_points(speed_scale)
		
		last_ball_position = body.global_position
		checking_ball_direction = true
		animation_active = true
		ball_exited = false
		timer = 0.0

# Called when a body exits the Area2D
var timer_at_exit = 0.0
func _on_area_2d_body_exited(body):
	# Check if the body is a ball
	if body.is_in_group("balls") and animation_active:
		# Mark that the ball has exited so we start slowing down
		ball_exited = true
		# Store the time when the ball exited
		timer_at_exit = timer
		
		# Tell score label that spinner ball has exited to start points decay
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			score_label.spinner_ball_exit()

# Plays the animation forwards with specified speed scale (bottom to top entry)
func _play_animation_forwards(speed_scale):
	animated_sprite.play("default", 1.0) # Direction: forward
	animated_sprite.speed_scale = speed_scale # Apply speed scaling

# Plays the animation backwards with specified speed scale (top to bottom entry)
func _play_animation_backwards(speed_scale):
	animated_sprite.play("default", -1.0) # Direction: backward
	animated_sprite.speed_scale = speed_scale # Apply speed scaling
