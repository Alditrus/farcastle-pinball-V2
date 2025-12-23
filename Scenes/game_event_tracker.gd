# game_event_tracker.gd
extends Node

var session_id: String = ""
var events: Array = []
var is_web_build: bool = false

func _ready():
	is_web_build = OS.has_feature("web")

	# Test if JavaScript/JavaScriptBridge is available
	if is_web_build:
		var js = _get_javascript_singleton()
		if js:
			print("JavaScript singleton available")
		else:
			push_error("JavaScript singleton NOT available - web features won't work")

func _get_javascript_singleton():
	# Try both names for compatibility
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

func set_session_id(sid: String):
	session_id = sid
	events.clear()
	print("GameEventTracker session_id set to: ", session_id)

func get_session_id() -> String:
	return session_id

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
	var js = _get_javascript_singleton()
	if not js:
		return
	
	var event_data_copy = event_data.duplicate()
	event_data_copy["timestamp"] = Time.get_ticks_msec()
	
	var js_code = """
		window.sendGameEvent('%s', '%s', %s);
	""" % [session_id, event_type, JSON.stringify(event_data_copy)]
	
	js.eval(js_code)

func get_events() -> Array:
	return events
