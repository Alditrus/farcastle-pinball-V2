extends Node2D

# References to the candles in the set
@onready var candles = [$candle, $candle2, $candle3]

# Signal to notify when all candles are activated
signal all_candles_activated

# Timeout for how long the complete flame effect should run (in seconds)
var complete_flame_duration = 1.0
var timer = null

func _ready():
	# Connect signals from each candle
	for candle in candles:
		candle.candle_state_changed.connect(_on_candle_state_changed)
	
	# Create a timer for the complete flame effect
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_complete_flame_timeout)
	add_child(timer)

# Called when any candle's state changes
func _on_candle_state_changed(candle_node, is_active):
	check_all_active()

# Check if all candles are active
func check_all_active():
	var all_active = true
	
	# Check if all candles are active
	for candle in candles:
		if not candle.is_candle_active():
			all_active = false
			break
	
	# If all candles are active, trigger the complete state
	if all_active:
		print("All candles activated!")
		emit_signal("all_candles_activated")
		trigger_complete_flame()

# Trigger the complete flame effect on all candles
func trigger_complete_flame():
	# Set all candles to complete state
	for candle in candles:
		candle.set_complete(true)
	
	# Start the timer for how long the complete flame should be active
	timer.start(complete_flame_duration)

# Called when the complete flame effect timer expires
func _on_complete_flame_timeout():
	# Reset all candles
	for candle in candles:
		candle.set_active(false)
		candle.set_complete(false)
	
	print("Candle set reset")

# Public method to reset all candles
func reset():
	for candle in candles:
		candle.reset()
