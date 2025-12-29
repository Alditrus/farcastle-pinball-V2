extends Node

func _ready():
	print("GameSession node ready")
	
	if OS.has_feature("web"):
		initialize_web_session()
	else:
		print("Not a web build, skipping session initialization")

func _get_javascript_singleton():
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

func initialize_web_session():
	print("Initializing web session...")

	await get_tree().create_timer(1.0).timeout

	var js = _get_javascript_singleton()
	if not js:
		push_error("JavaScript singleton not available")
		return

	print("JavaScript singleton found")

	# Check if game has already been initialized by the main HTML
	var game_initialized = js.eval("window.gameInitialized || false", true)
	var existing_session_id = js.eval("window.currentSessionId || ''", true)
	var game_scene_loaded_before = js.eval("window.gameSceneLoadedBefore || false", true)
	print("Game initialized: ", game_initialized, " | Existing session: ", existing_session_id, " | Scene loaded before: ", game_scene_loaded_before)

	var session_id = ""

	# If the game scene has been loaded before, we need a new session
	# This handles the case where we're restarting after game over
	if game_initialized and game_scene_loaded_before and existing_session_id != "" and existing_session_id != null:
		print("🔄 Detected game restart - need new session (old session: ", existing_session_id, ")")

		# Check if startNewSession function exists
		var has_function = js.eval("typeof window.startNewSession === 'function'", true)
		print("startNewSession function exists: ", has_function)

		if has_function:
			print("🔄 Calling startNewSession() to get a fresh session...")

			# Clear any previous result
			js.eval("window.sessionStartResult = null;")

			var js_code = """
				(async function() {
					console.log('🔄 [GD] Godot calling startNewSession()');
					console.log('🔄 [GD] Current FID:', window.currentUserFid);
					try {
						const result = await window.startNewSession();
						console.log('✅ [GD] startNewSession result:', result);
						console.log('✅ [GD] New session ID:', result.sessionId);
						console.log('✅ [GD] window.currentSessionId updated to:', window.currentSessionId);
						window.sessionStartResult = result;
					} catch (error) {
						console.error('❌ [GD] startNewSession error:', error);
						window.sessionStartResult = { success: false, error: error.message };
					}
				})();
			"""

			js.eval(js_code)

			# Wait for the async call to complete
			await get_tree().create_timer(1.5).timeout

			# Get the result
			var result_json = js.eval("JSON.stringify(window.sessionStartResult || {})", true)
			print("Raw result JSON: ", result_json)

			var json_parser = JSON.new()
			var parse_result = json_parser.parse(result_json)

			if parse_result == OK:
				var result_data = json_parser.data
				print("Parsed result data: ", result_data)

				if result_data.has("success") and result_data.success and result_data.has("sessionId"):
					session_id = result_data.sessionId
					print("✅ New session created successfully: ", session_id)

					# Verify window.currentSessionId was also updated
					var updated_window_session = js.eval("window.currentSessionId || ''", true)
					print("✅ Verified window.currentSessionId: ", updated_window_session)

					if updated_window_session != session_id:
						push_warning("⚠️ Session ID mismatch! Result: ", session_id, " vs Window: ", updated_window_session)
				else:
					push_warning("❌ Failed to create new session: ", result_data.get("error", "Unknown error"))
					print("Full result data: ", result_data)
			else:
				push_warning("❌ Failed to parse session result JSON")
		else:
			push_warning("❌ startNewSession function not available")

	# If we don't have a new session, use the existing one
	if session_id == "" or session_id == null:
		print("Using existing session from initial load...")
		session_id = js.eval("window.currentSessionId || ''", true)

		# Wait a bit more if session still not ready
		if session_id == "" or session_id == null:
			push_warning("Session ID not ready, waiting longer...")
			await get_tree().create_timer(1.0).timeout
			session_id = js.eval("window.currentSessionId || ''", true)

			if session_id == "" or session_id == null:
				push_error("Session initialization failed - no valid session available")
				return

	GameEventTracker.set_session_id(session_id)
	print("Game session initialized: ", session_id)

	var user_fid = js.eval("window.currentUserFid || 0", true)
	var username = js.eval("window.currentUsername || 'Unknown'", true)
	print("Playing as: ", username, " (FID: ", user_fid, ")")

	# Mark that the game scene has been loaded at least once
	js.eval("window.gameSceneLoadedBefore = true;")

	js.eval("if (window.notifyGodotReady) window.notifyGodotReady();")
	print("Called notifyGodotReady()")
