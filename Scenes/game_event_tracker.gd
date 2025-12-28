# game_event_tracker.gd
extends Node

var session_id: String = ""
var events: Array = []
var is_web_build: bool = false
var backend_score: int = 0
var last_processed_counter: int = 0

signal score_updated(new_score: int)
signal event_about_to_send(event_type: String, event_data: Dictionary, session_id: String, points: int)

func _ready():
	is_web_build = OS.has_feature("web")

	# Test if JavaScript/JavaScriptBridge is available
	if is_web_build:
		var js = _get_javascript_singleton()
		if js:
			print("JavaScript singleton available")
			# Set up callback for score updates from JavaScript
			_setup_score_callback()
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

func _setup_score_callback():
	var js = _get_javascript_singleton()
	if not js:
		print("[EventTracker] No JS singleton for callback setup")
		return

	# Create a JavaScript interface for Godot to receive score updates
	var js_code = """
		window.updateGodotScore = function(score) {
			console.log('[updateGodotScore] Called with score:', score);
			console.log('[updateGodotScore] window.godot exists:', !!window.godot);
			if (window.godot && window.godot.GameEventTracker) {
				console.log('[updateGodotScore] Calling Godot method');
				window.godot.GameEventTracker.update_score_from_backend(score);
			} else {
				console.error('[updateGodotScore] Cannot call Godot - not available');
			}
		};
		console.log('[EventTracker] updateGodotScore callback registered');
	"""
	js.eval(js_code)
	print("[EventTracker] Score callback setup complete")

# Called from JavaScript when backend returns a score
func update_score_from_backend(score: int):
	print("[EventTracker] update_score_from_backend called: ", score)
	DebugLog.log("[EventTracker] Backend returned score: " + str(score))

	if score == 0 and backend_score == 0:
		print("[EventTracker] ⚠️ WARNING: Backend returned score = 0. Check backend scoring logic!")

	backend_score = score
	print("[EventTracker] About to emit score_updated signal with score: ", score)
	score_updated.emit(score)
	print("[EventTracker] Score updated and signal emitted successfully")

func get_backend_score() -> int:
	return backend_score

func record_event(event_type: String, event_data: Dictionary = {}, points: int = 0):
	# Add locally for potential debugging
	events.append({
		"type": event_type,
		"data": event_data,
		"timestamp": Time.get_ticks_msec(),
		"points": points
	})

	print("[EventTracker] Event: ", event_type, " | Session: ", session_id, " | Web: ", is_web_build)
	DebugLog.log("[EventTracker] Event: " + event_type + " | SID: " + session_id)

	# Send to backend if web build
	if is_web_build and session_id != "":
		send_event_to_backend(event_type, event_data, points)
	else:
		print("[EventTracker] NOT sending - Web: ", is_web_build, " SID: ", session_id)
		DebugLog.log("[EventTracker] NOT sending - Web: " + str(is_web_build) + " SID: " + session_id)

func send_event_to_backend(event_type: String, event_data: Dictionary, points: int = 0):
	# Check if JavaScript singleton exists (only available in web builds)
	var js = _get_javascript_singleton()
	if not js:
		print("[EventTracker] JS singleton not available")
		DebugLog.log("[EventTracker] JS singleton NOT available")
		return

	var event_data_copy = event_data.duplicate()
	event_data_copy["timestamp"] = Time.get_ticks_msec()

	print("[EventTracker] Sending to backend: ", event_type, " | Data: ", JSON.stringify(event_data_copy), " | Points: ", points)
	DebugLog.log("[EventTracker] Sending: " + event_type)

	# Emit signal for debug UI
	event_about_to_send.emit(event_type, event_data_copy, session_id, points)

	# Call sendGameEvent and handle the score response via callback
	var js_code = """
		(async function() {
			console.log('[EventTracker JS] Calling sendGameEvent:', '%s', '%s');
			if (!window.scoreUpdateCounter) window.scoreUpdateCounter = 0;
			const result = await window.sendGameEvent('%s', '%s', %s);
			console.log('[EventTracker JS] Result:', result);
			if (result && result.score !== undefined) {
				console.log('[EventTracker JS] Updating score:', result.score);
				window.lastBackendScore = result.score;
				window.scoreUpdateCounter++;
				console.log('[EventTracker JS] Score update counter:', window.scoreUpdateCounter);
				window.updateGodotScore(result.score);
			} else {
				console.log('[EventTracker JS] No score in result - result:', JSON.stringify(result));
			}
		})();
	""" % [session_id, event_type, session_id, event_type, JSON.stringify(event_data_copy)]

	js.eval(js_code)

	# Poll for the score as a fallback since callback might not work
	poll_for_score_update()

func poll_for_score_update():
	# Wait a bit for the async request to complete
	await get_tree().create_timer(0.2).timeout

	var js = _get_javascript_singleton()
	if not js:
		return

	# Try to get the last backend score using the counter mechanism
	var max_attempts = 10
	var attempts = 0

	while attempts < max_attempts:
		var counter_result = js.eval("window.scoreUpdateCounter || 0", true)
		var score_result = js.eval("window.lastBackendScore !== undefined ? window.lastBackendScore : (window.verifiedScore || -1)", true)

		print("[EventTracker] Poll attempt ", attempts + 1, ": counter = ", counter_result, ", score = ", score_result, " | last_processed = ", last_processed_counter)

		if counter_result is int and counter_result > last_processed_counter:
			# New score update available - accept ANY score value including 0
			if score_result is int or score_result is float:
				var new_score = int(score_result)
				print("[EventTracker] ✅ NEW SCORE UPDATE via polling: ", new_score, " (backend score was: ", backend_score, ")")
				last_processed_counter = counter_result
				update_score_from_backend(new_score)
				return

		await get_tree().create_timer(0.1).timeout
		attempts += 1

	print("[EventTracker] ⚠️ Score polling timed out - no NEW score update received")

func get_events() -> Array:
	return events
