extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the body_entered signal to our handler function
	body_entered.connect(_on_body_entered)

# Called when a physics body enters this area
func _on_body_entered(body):
	# Check if the body that entered is a ball
	if body.is_in_group("balls"):
		# Create a delay timer
		var timer = get_tree().create_timer(0.01)
		
		# Using the function reference pattern instead of a lambda
		timer.timeout.connect(_activate_minigame)

# Function to activate the minigame
func _activate_minigame():
	# Instead of pausing the entire tree, we'll just disable the main table
	# get_tree().paused = true
	
	# Get the Table node
	var table = get_node("/root/Table")
	if table:
		# Disable processing in the main table, except for the minigamewindow
		for child in table.get_children():
			if child.name != "minigamewindow":
				child.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Get the minigamewindow from the table scene
	var minigame_window = get_node("/root/Table/minigamewindow")
	if minigame_window:
		# Use the activate method to properly set up the minigame
		minigame_window.activate()
