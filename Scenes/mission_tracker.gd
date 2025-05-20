extends Control

@onready var missions_list = $Panel/VBoxContainer/MissionsList

var missions_node: Node

# Called when the node enters the scene tree for the first time
func _ready():
	# Wait one frame to ensure scene is fully loaded
	await get_tree().process_frame
	
	# Find the missions node in the scene
	missions_node = get_node_or_null("/root/Table/Missions")
	
	if missions_node:
		# Connect to mission signals
		missions_node.object_hit.connect(_on_object_hit)
		missions_node.mission_completed.connect(_on_mission_completed)
		
		# Initial update of mission list
		update_mission_display()

# Update the mission display with current active missions
func update_mission_display():
	if not missions_node:
		return
	
	# Clear current missions
	for child in missions_list.get_children():
		child.queue_free()
	
	# Get active missions with progress data
	var active_missions = missions_node.get_active_missions_with_progress()
	
	# Create UI for each mission
	for mission in active_missions:
		# Create container
		var mission_container = VBoxContainer.new()
		missions_list.add_child(mission_container)
		
		# Create mission name label
		var name_label = Label.new()
		name_label.text = mission["name"]
		mission_container.add_child(name_label)
		
		# Create mission description label
		var desc_label = Label.new()
		desc_label.text = mission["description"]
		mission_container.add_child(desc_label)
		
		# Create progress bar
		var progress_bar = ProgressBar.new()
		progress_bar.max_value = 1.0
		progress_bar.value = mission["progress"]
		progress_bar.custom_minimum_size.y = 10
		mission_container.add_child(progress_bar)
		
		# Create progress text
		var progress_label = Label.new()
		progress_label.text = str(mission["current"]) + " / " + str(mission["required"])
		mission_container.add_child(progress_label)
		
		# Add separator
		var separator = HSeparator.new()
		mission_container.add_child(separator)

# Called when an object is hit
func _on_object_hit(_collision_type, _count):
	update_mission_display()

# Called when a mission is completed
func _on_mission_completed(_mission_id):
	update_mission_display()
	# Could add animation or notification here