extends Node

func _ready():
	print("📊 [GAME_SESSION] _ready() started")
	
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
	print("📊 [WEB_SESSION] Starting initialization...")
	
	var js = _get_javascript_singleton()
	if not js:
		push_error("JavaScript singleton not available")
		return
	
	print("✅ JavaScript singleton found")
	
	# Get session ID immediately - no waiting needed!
	var session_id = js.eval("window.currentSessionId || ''", true)
	
	if session_id == "" or session_id == null:
		# Only wait if we ACTUALLY don't have a session yet
		push_warning("Session ID not ready yet, waiting briefly...")
		await get_tree().create_timer(0.5).timeout  # Much shorter wait
		session_id = js.eval("window.currentSessionId || ''", true)
		
		if session_id == "" or session_id == null:
			push_error("❌ Session initialization failed")
			return
	
	GameEventTracker.set_session_id(session_id)
	print("✅ Game session initialized: ", session_id)
	
	var user_fid = js.eval("window.currentUserFid || 0", true)
	var username = js.eval("window.currentUsername || 'Unknown'", true)
	print("✅ Playing as: ", username, " (FID: ", user_fid, ")")
	
	js.eval("if (window.notifyGodotReady) window.notifyGodotReady();")
	print("✅ Notified JavaScript")
