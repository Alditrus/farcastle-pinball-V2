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
	
	await get_tree().create_timer(2.0).timeout
	
	var js = _get_javascript_singleton()
	if not js:
		push_error("JavaScript singleton not available")
		return
	
	print("JavaScript singleton found")
	
	var session_id = js.eval("window.currentSessionId || ''", true)
	
	if session_id == "" or session_id == null:
		push_warning("Session ID not ready, waiting longer...")
		await get_tree().create_timer(2.0).timeout
		session_id = js.eval("window.currentSessionId || ''", true)
		
		if session_id == "" or session_id == null:
			push_error("Session initialization failed after retry")
			return
	
	GameEventTracker.set_session_id(session_id)
	print("Game session initialized: ", session_id)
	
	var user_fid = js.eval("window.currentUserFid || 0", true)
	var username = js.eval("window.currentUsername || 'Unknown'", true)
	print("Playing as: ", username, " (FID: ", user_fid, ")")
	
	js.eval("if (window.notifyGodotReady) window.notifyGodotReady();")
	print("Called notifyGodotReady()")
