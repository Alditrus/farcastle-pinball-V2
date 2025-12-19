# game_event_tracker.gd
extends Node

var session_id: String = ""
var events: Array = []
var is_web_build: bool = false

func _ready():
	is_web_build = OS.has_feature("web")

func set_session_id(sid: String):
	session_id = sid
	events.clear()

func record_event(event_type: String, event_data: Dictionary = {}):
	# Add locally for potential debugging
	events.append({
		"type": event_type,
		"data": event_data,
		"timestamp": Time.get_ticks_msec()
	})
	
	# Send to backend if web build
	if is_web_build and session_id != "":
		send_event_to_backend(event_type, event_data)

func send_event_to_backend(event_type: String, event_data: Dictionary):
	# Check if JavaScript singleton exists (only available in web builds)
	if not Engine.has_singleton("JavaScript"):
		return
	
	var event_data_copy = event_data.duplicate()
	event_data_copy["timestamp"] = Time.get_ticks_msec()
	
	var js_code = """
		window.sendGameEvent('%s', '%s', %s);
	""" % [session_id, event_type, JSON.stringify(event_data_copy)]
	
	# Get the JavaScript singleton dynamically
	var js = Engine.get_singleton("JavaScript")
	if js:
		js.eval(js_code)

func get_events() -> Array:
	return events
