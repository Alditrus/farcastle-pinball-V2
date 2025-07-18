extends Area2D

# Left sinkhole area - mission resumption logic has been moved to Exit.gd
# This area is now only used for collision detection and scoring (handled by Sinkholearea.gd)

func _ready():
	# Connect the body entered signal if any other functionality is needed
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Left lane mission resumption logic has been removed
	# Missions now resume automatically when the ball enters the table
	# This left lane area is now only used for collision detection and scoring
	pass

