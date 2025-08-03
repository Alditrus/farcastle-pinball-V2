extends AudioStreamPlayer2D

func _ready():
	# Set the audio bus to SFX
	bus = "SFX"
	
	# Enable looping for the audio stream
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD