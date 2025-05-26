extends StaticBody2D

# Dictionary to store multiplier values for each area
var multipliers = {
	"plier1": 2,
	"plier2": 3,
	"plier3": 4,
	"plier4": 5,
	"plier5": 4,
	"plier6": 3,
	"plier7": 2
}

func _ready():
	# Connect all multiplier areas to the score multiplier function
	for i in range(1, 8):
		var area_name = "plier" + str(i)
		if has_node(area_name):
			var area = get_node(area_name)
			area.connect("body_entered", _on_plier_body_entered.bind(area_name))

# Called when a ball enters any of the multiplier areas
func _on_plier_body_entered(body, area_name):
	# Check specifically for the minigameball
	if body.name == "minigameball":
		print("Minigame Complete!")
		var score_label = get_node("/root/Table/ScoreboardUI/ScoreLabel")
		if score_label:
			var multiplier = multipliers[area_name]
			score_label.apply_multiplier(multiplier)
			
			# Deactivate minigame and return to main game after a short delay
			await get_tree().create_timer(0.5).timeout
			
			# Find the minigame window and deactivate it
			var minigame_window = get_node_or_null("/root/Table/minigamewindow")
			if minigame_window and minigame_window.has_method("deactivate"):
				minigame_window.deactivate()
				
				# Unfreeze all main table balls and wait for process to complete
				await unfreeze_main_table_balls()
				
				# Add a short delay to let the ball be ejected before starting jaw closing animation
				await get_tree().create_timer(0.5).timeout
				
				# Reset the minigame entrance
				var minigame_entrance = get_node_or_null("/root/Table/minigameentrance")
				if minigame_entrance and minigame_entrance.has_method("reset_entrance"):
					minigame_entrance.reset_entrance()

# Unfreeze all balls in the main table to resume their movement
# Returns when the process is complete (allows awaiting)
func unfreeze_main_table_balls():
	# Find all balls in the "balls" group
	var balls = get_tree().get_nodes_in_group("balls")
	var captured_ball_found = false
	
	for ball in balls:
		# Skip any minigameball - only unfreeze main table balls
		if ball.name != "minigameball":
			# Check if this was the captured ball
			var was_captured = ball.has_meta("original_position")
			if was_captured:
				captured_ball_found = true
			
			# Restore the ball's appearance and get the callback
			var MinigameArea = load("res://Scenes/minigamearea.gd")
			var animation_complete = MinigameArea.restore_ball_appearance(ball)
			
			# For the captured ball, the callback will handle unfreezing
			if was_captured:
				if animation_complete is Callable:
					await animation_complete.call()
				continue
			
			# For non-captured balls, handle unfreezing here
			if animation_complete is Callable:
				await animation_complete.call()
			
			# Unfreeze non-captured balls
			ball.freeze = false
			
			# Restore stored velocities for non-captured balls
			if ball.has_meta("stored_linear_velocity"):
				ball.linear_velocity = ball.get_meta("stored_linear_velocity")
				ball.angular_velocity = ball.get_meta("stored_angular_velocity")
				
				# Clear the stored values
				ball.remove_meta("stored_linear_velocity")
				ball.remove_meta("stored_angular_velocity")
	
	# If we found a captured ball, add a little extra delay to make sure
	# the ball has time to launch properly
	if captured_ball_found:
		await get_tree().create_timer(0.2).timeout
