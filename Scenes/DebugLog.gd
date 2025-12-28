extends Node

# Simple debug logging singleton
var logs: Array = []
var max_logs: int = 100

signal log_added(message: String)

func log(message: String):
	var timestamp = Time.get_ticks_msec()
	var log_entry = "[%d] %s" % [timestamp, message]

	logs.append(log_entry)

	# Keep only the last max_logs entries
	if logs.size() > max_logs:
		logs.pop_front()

	# Emit signal for UI updates
	log_added.emit(log_entry)

	# Also print to console
	print(log_entry)

func get_logs() -> Array:
	return logs

func clear_logs():
	logs.clear()
