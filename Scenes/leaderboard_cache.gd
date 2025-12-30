extends Node

# Cached leaderboard data
var leaderboard_data: Array = []
var last_fetch_time: int = 0
var cache_duration_ms: int = 60000  # Cache for 60 seconds
var is_fetching: bool = false

signal leaderboard_updated(data: Array)

func _get_javascript_singleton():
	if Engine.has_singleton("JavaScriptBridge"):
		return Engine.get_singleton("JavaScriptBridge")
	elif Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

# Preload leaderboard data on game start
func preload_leaderboard():
	if not OS.has_feature("web"):
		print("[LeaderboardCache] Not a web build, skipping preload")
		return

	print("[LeaderboardCache] Preloading leaderboard data...")
	await fetch_leaderboard_data(50)  # Fetch top 50 for initial cache

# Get cached leaderboard data with automatic refresh if stale
func get_leaderboard(limit: int = 10, force_refresh: bool = false) -> Array:
	var current_time = Time.get_ticks_msec()
	var cache_age = current_time - last_fetch_time

	# Return cached data if fresh enough and not forcing refresh
	if not force_refresh and cache_age < cache_duration_ms and leaderboard_data.size() > 0:
		print("[LeaderboardCache] Using cached data (age: ", cache_age / 1000.0, "s)")
		return leaderboard_data.slice(0, min(limit, leaderboard_data.size()))

	# If already fetching, wait for it to complete
	if is_fetching:
		print("[LeaderboardCache] Fetch already in progress, waiting...")
		await leaderboard_updated
		return leaderboard_data.slice(0, min(limit, leaderboard_data.size()))

	# Fetch new data
	await fetch_leaderboard_data(limit)
	return leaderboard_data.slice(0, min(limit, leaderboard_data.size()))

# Fetch more entries for infinite scroll
func fetch_more_entries(current_count: int, batch_size: int = 10):
	# If we already have enough cached data, return it
	if current_count < leaderboard_data.size():
		var next_batch = leaderboard_data.slice(current_count, min(current_count + batch_size, leaderboard_data.size()))
		return next_batch

	# Otherwise, fetch more from API
	var new_limit = current_count + batch_size
	await fetch_leaderboard_data(new_limit)

	if leaderboard_data.size() > current_count:
		return leaderboard_data.slice(current_count, leaderboard_data.size())
	else:
		return []

# Fetch leaderboard data from API
func fetch_leaderboard_data(limit: int = 50):
	if is_fetching:
		return

	is_fetching = true

	var js = _get_javascript_singleton()
	if not js:
		print("❌ [LeaderboardCache] No JavaScript singleton available")
		is_fetching = false
		return

	print("🔄 [LeaderboardCache] Fetching top ", limit, " from API...")

	# Call the JavaScript function to get leaderboard
	js.eval("""
		(async () => {
			try {
				if (typeof window.getLeaderboard === 'function') {
					const result = await window.getLeaderboard(%d);
					window.cachedLeaderboardResult = JSON.stringify(result);
				}
			} catch (error) {
				console.error('[LeaderboardCache] Fetch error:', error);
				window.cachedLeaderboardResult = JSON.stringify({ leaderboard: [] });
			}
		})()
	""" % limit, true)

	# Wait for result
	await get_tree().create_timer(1.5).timeout

	var result_json = js.eval("(window.cachedLeaderboardResult || JSON.stringify({ leaderboard: [] }))", true)

	if result_json is String and result_json != "":
		var json = JSON.new()
		var parse_result = json.parse(result_json)

		if parse_result == OK:
			var data = json.data
			if data and data.has("leaderboard"):
				leaderboard_data = data.leaderboard
				last_fetch_time = Time.get_ticks_msec()
				print("✅ [LeaderboardCache] Cached ", leaderboard_data.size(), " entries")
				leaderboard_updated.emit(leaderboard_data)
			else:
				print("⚠️ [LeaderboardCache] No leaderboard data in response")
		else:
			print("⚠️ [LeaderboardCache] Failed to parse leaderboard JSON")
	else:
		print("⚠️ [LeaderboardCache] No leaderboard result received")

	is_fetching = false

# Force refresh the cache
func refresh_cache():
	print("[LeaderboardCache] Force refreshing cache...")
	await fetch_leaderboard_data(50)
