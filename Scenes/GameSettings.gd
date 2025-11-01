extends Node

# Global game settings that persist across scenes
var nudge_enabled: bool = true

# Save settings to file
func save_settings():
	var config = ConfigFile.new()
	config.set_value("gameplay", "nudge_enabled", nudge_enabled)
	config.save("user://settings.cfg")

# Load settings from file
func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")

	if err == OK:
		nudge_enabled = config.get_value("gameplay", "nudge_enabled", true)
	else:
		# Use default values if file doesn't exist
		nudge_enabled = true

func _ready():
	load_settings()
