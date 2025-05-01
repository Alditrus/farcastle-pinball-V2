@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Load scripts directly without preload to avoid circular reference issues
	var CameraRegionController2D_script = load("res://addons/cameraregion2d/CameraRegionController2D.gd")
	var CameraRegion2D_script = load("res://addons/cameraregion2d/CameraRegion2D.gd")
	var CameraTransition_script = load("res://addons/cameraregion2d/CameraTransition.gd")
	
	# Load icons
	var CameraRegionController2D_icon = load("res://addons/cameraregion2d/icons/CameraRegionController2D.svg")
	var CameraRegion2D_icon = load("res://addons/cameraregion2d/icons/CameraRegion2D.svg")
	var CameraTransition_icon = load("res://addons/cameraregion2d/icons/CameraTransition.svg")
	
	# Add custom types
	add_custom_type("CameraRegionController2D", "Node2D", CameraRegionController2D_script, CameraRegionController2D_icon)
	add_custom_type("CameraRegion2D", "Node2D", CameraRegion2D_script, CameraRegion2D_icon)
	add_custom_type("CameraTransition", "Resource", CameraTransition_script, CameraTransition_icon)


func _exit_tree() -> void:
	remove_custom_type("CameraRegionController2D")
	remove_custom_type("CameraRegion2D")
	remove_custom_type("CameraTransition")
