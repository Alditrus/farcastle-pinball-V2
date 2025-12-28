extends Control

@onready var event_type_label = $Panel/VBoxContainer/EventTypeLabel
@onready var timestamp_label = $Panel/VBoxContainer/TimestampLabel
@onready var points_label = $Panel/VBoxContainer/PointsLabel
@onready var verified_score_label = $Panel/VBoxContainer/VerifiedScoreLabel

func _ready():
	print("[DebugUI] Debug UI ready, connecting signals...")
	# Connect to GameEventTracker signals
	GameEventTracker.event_about_to_send.connect(_on_event_about_to_send)
	GameEventTracker.score_updated.connect(_on_backend_score_updated)
	print("[DebugUI] Signals connected successfully")

	# Initialize labels
	event_type_label.text = "Event Type: -"
	timestamp_label.text = "Timestamp: -"
	points_label.text = "Points Sent: -"
	verified_score_label.text = "Backend Score: -"
	print("[DebugUI] Labels initialized")

func _on_event_about_to_send(event_type: String, event_data: Dictionary, session_id: String, points: int):
	print("[DebugUI] Event about to send: ", event_type, " | Points: ", points)
	# Update labels with the event information
	event_type_label.text = "Event Type: " + event_type
	points_label.text = "Points Sent: " + str(points)

	# Format timestamp
	if event_data.has("timestamp"):
		timestamp_label.text = "Timestamp: " + str(event_data["timestamp"])
	else:
		timestamp_label.text = "Timestamp: -"

	# Show waiting status for backend response
	verified_score_label.text = "Backend Score: (waiting...)"

func _on_backend_score_updated(new_score: int):
	print("[DebugUI] Received score update: ", new_score)
	# Update with the verified score from backend
	verified_score_label.text = "Backend Score: " + format_score_with_commas(new_score)
	print("[DebugUI] Label updated to: ", verified_score_label.text)

# Format score with commas for readability
func format_score_with_commas(number: int) -> String:
	var score_string = str(number)
	var formatted_string = ""
	var digit_count = 0

	for i in range(score_string.length() - 1, -1, -1):
		digit_count += 1
		formatted_string = score_string[i] + formatted_string
		if digit_count % 3 == 0 and i > 0:
			formatted_string = "," + formatted_string

	return formatted_string
