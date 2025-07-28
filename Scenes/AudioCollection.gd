extends Node2D

# AudioCollection - Central audio management system for the pinball game
# Manages three audio buses: Music, SFX, and Voice, all connected to Master bus

# Audio player references
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var voice_player: AudioStreamPlayer = $VoicePlayer

# SFX player pool for overlapping sounds
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_player_count: int = 8  # Number of concurrent SFX players

# Audio bus indices (will be set up in _ready)
var master_bus_index: int
var music_bus_index: int
var sfx_bus_index: int
var voice_bus_index: int

# Default volume levels (in dB)
const DEFAULT_MASTER_VOLUME: float = 0.0
const DEFAULT_MUSIC_VOLUME: float = -50.0
const DEFAULT_SFX_VOLUME: float = -5.0
const DEFAULT_VOICE_VOLUME: float = 0.0

# Music tracks (excluding lich_mode.ogg for special use)
var music_tracks: Array[AudioStream] = []
var current_track_index: int = -1
var lich_mode_track: AudioStream
var is_lich_mode_playing: bool = false

func _ready():
	setup_audio_buses()
	setup_sfx_players()
	setup_music_tracks()
	set_default_volumes()
	start_random_music()

# Set up the audio bus structure: Master -> Music/SFX/Voice
func setup_audio_buses():
	# Get or create Master bus (should already exist)
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# Get or create Music bus
	music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		AudioServer.add_bus()
		music_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_index, "Music")
		AudioServer.set_bus_send(music_bus_index, "Master")
	
	# Get or create SFX bus
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index == -1:
		AudioServer.add_bus()
		sfx_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus_index, "SFX")
		AudioServer.set_bus_send(sfx_bus_index, "Master")
	
	# Get or create Voice bus
	voice_bus_index = AudioServer.get_bus_index("Voice")
	if voice_bus_index == -1:
		AudioServer.add_bus()
		voice_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(voice_bus_index, "Voice")
		AudioServer.set_bus_send(voice_bus_index, "Master")

# Set up multiple SFX players for overlapping sounds
func setup_sfx_players():
	for i in range(sfx_player_count):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer" + str(i)
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_players.append(sfx_player)

# Set up music tracks array (excluding lich_mode.ogg)
func setup_music_tracks():
	music_tracks = [
		preload("res://Assets/music/Legibus Antiquis Honoris.ogg"),
		preload("res://Assets/music/Sanctum.ogg"),
		preload("res://Assets/music/Imperator Praetor Spiritus Sanctus.ogg")
	]
	# Load lich mode track separately
	lich_mode_track = preload("res://Assets/music/lich_mode.ogg")

# Start playing a random music track
func start_random_music():
	if music_tracks.size() == 0:
		return
	
	# Stop any currently playing music first
	stop_music()
	
	# Pick a random track that's different from the current one
	var new_index = current_track_index
	if music_tracks.size() > 1:
		while new_index == current_track_index:
			new_index = randi() % music_tracks.size()
	else:
		new_index = 0
	
	current_track_index = new_index
	is_lich_mode_playing = false
	play_music(music_tracks[current_track_index], true)

# Change to a new random music track (for mission changes)
func change_to_random_music():
	# Don't change music if lich mode is playing
	if is_lich_mode_playing:
		return
	start_random_music()

# Start playing lich mode music
func start_lich_mode_music():
	# Stop any currently playing music first
	stop_music()
	is_lich_mode_playing = true
	play_music(lich_mode_track, true)

# Return to normal music rotation from lich mode
func end_lich_mode_music():
	# Stop any currently playing music first
	stop_music()
	is_lich_mode_playing = false
	start_random_music()

# Set default volume levels for all buses
func set_default_volumes():
	set_master_volume(DEFAULT_MASTER_VOLUME)
	set_music_volume(DEFAULT_MUSIC_VOLUME)
	set_sfx_volume(DEFAULT_SFX_VOLUME)
	set_voice_volume(DEFAULT_VOICE_VOLUME)

# Volume control functions (volumes in dB)
func set_master_volume(volume_db: float):
	AudioServer.set_bus_volume_db(master_bus_index, volume_db)

func set_music_volume(volume_db: float):
	AudioServer.set_bus_volume_db(music_bus_index, volume_db)

func set_sfx_volume(volume_db: float):
	AudioServer.set_bus_volume_db(sfx_bus_index, volume_db)

func set_voice_volume(volume_db: float):
	AudioServer.set_bus_volume_db(voice_bus_index, volume_db)

# Volume getter functions
func get_master_volume() -> float:
	return AudioServer.get_bus_volume_db(master_bus_index)

func get_music_volume() -> float:
	return AudioServer.get_bus_volume_db(music_bus_index)

func get_sfx_volume() -> float:
	return AudioServer.get_bus_volume_db(sfx_bus_index)

func get_voice_volume() -> float:
	return AudioServer.get_bus_volume_db(voice_bus_index)

# Mute/unmute functions
func set_master_mute(muted: bool):
	AudioServer.set_bus_mute(master_bus_index, muted)

func set_music_mute(muted: bool):
	AudioServer.set_bus_mute(music_bus_index, muted)

func set_sfx_mute(muted: bool):
	AudioServer.set_bus_mute(sfx_bus_index, muted)

func set_voice_mute(muted: bool):
	AudioServer.set_bus_mute(voice_bus_index, muted)

# Mute status getters
func is_master_muted() -> bool:
	return AudioServer.is_bus_mute(master_bus_index)

func is_music_muted() -> bool:
	return AudioServer.is_bus_mute(music_bus_index)

func is_sfx_muted() -> bool:
	return AudioServer.is_bus_mute(sfx_bus_index)

func is_voice_muted() -> bool:
	return AudioServer.is_bus_mute(voice_bus_index)

# Audio playback functions
func play_music(audio_stream: AudioStream, loop: bool = true):
	if music_player and audio_stream:
		# Stop any currently playing music first
		if music_player.playing:
			music_player.stop()
		
		music_player.stream = audio_stream
		if audio_stream is AudioStreamOggVorbis:
			audio_stream.loop = loop
		elif audio_stream is AudioStreamWAV:
			audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		music_player.play()

func play_sfx(audio_stream: AudioStream):
	if audio_stream:
		# Find an available SFX player (not currently playing)
		var available_player = null
		for player in sfx_players:
			if not player.playing:
				available_player = player
				break
		
		# If no available player, use the first one (oldest sound gets cut)
		if not available_player:
			available_player = sfx_players[0]
		
		# Play the sound
		available_player.stream = audio_stream
		available_player.play()

func play_voice(audio_stream: AudioStream):
	if voice_player and audio_stream:
		voice_player.stream = audio_stream
		voice_player.play()

# Stop functions
func stop_music():
	if music_player:
		music_player.stop()

func stop_sfx():
	for player in sfx_players:
		player.stop()

func stop_voice():
	if voice_player:
		voice_player.stop()

func stop_all_audio():
	stop_music()
	stop_sfx()
	stop_voice()

# Check if audio is playing
func is_music_playing() -> bool:
	return music_player and music_player.playing

func is_sfx_playing() -> bool:
	for player in sfx_players:
		if player.playing:
			return true
	return false

func is_voice_playing() -> bool:
	return voice_player and voice_player.playing

# Utility function to convert linear volume (0.0-1.0) to dB
func linear_to_db(linear_volume: float) -> float:
	if linear_volume <= 0.0:
		return -80.0  # Minimum volume
	return 20.0 * log(linear_volume) / log(10.0)

# Utility function to convert dB to linear volume (0.0-1.0)
func db_to_linear(db_volume: float) -> float:
	return pow(10.0, db_volume / 20.0)

# Set volume using linear scale (0.0-1.0)
func set_master_volume_linear(volume: float):
	set_master_volume(linear_to_db(volume))

func set_music_volume_linear(volume: float):
	set_music_volume(linear_to_db(volume))

func set_sfx_volume_linear(volume: float):
	set_sfx_volume(linear_to_db(volume))

func set_voice_volume_linear(volume: float):
	set_voice_volume(linear_to_db(volume))

# Get volume using linear scale (0.0-1.0)
func get_master_volume_linear() -> float:
	return db_to_linear(get_master_volume())

func get_music_volume_linear() -> float:
	return db_to_linear(get_music_volume())

func get_sfx_volume_linear() -> float:
	return db_to_linear(get_sfx_volume())

func get_voice_volume_linear() -> float:
	return db_to_linear(get_voice_volume())