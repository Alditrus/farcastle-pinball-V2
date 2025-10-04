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
const DEFAULT_MUSIC_VOLUME: float = -15.0
const DEFAULT_SFX_VOLUME: float = -5.0
const DEFAULT_VOICE_VOLUME: float = 0.0

# Music tracks array (excluding lich_mode)
var music_tracks: Array[String] = [
	"res://Assets/music/Imperator Praetor Spiritus Sanctus.ogg",
	"res://Assets/music/Legibus Antiquis Honoris.ogg",
	"res://Assets/music/Sanctum.ogg",
	"res://Assets/music/Apostolikon.ogg",
	"res://Assets/music/Kosmokrator.ogg",
	"res://Assets/music/Mortis Liberatum Nihil.ogg"
]

# Lich mode track
var lich_mode_track: String = "res://Assets/music/lich_mode.ogg"

# Current track for table scene (randomly selected)
var current_track: String

func _ready():
	# Set process mode to always run so music keeps playing during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	setup_audio_buses()
	setup_sfx_players()
	setup_music_player()
	set_default_volumes()
	select_random_track()
	play_current_track()

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
		# SFX should continue playing even when game is paused
		sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sfx_player)
		sfx_players.append(sfx_player)

# Set up music player to use Music bus
func setup_music_player():
	if music_player:
		music_player.bus = "Music"
		# Ensure music continues playing when game is paused
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if voice_player:
		voice_player.bus = "Voice"
		# Voice should also continue when paused
		voice_player.process_mode = Node.PROCESS_MODE_ALWAYS

# Set default volume levels for all buses
func set_default_volumes():
	set_master_volume(DEFAULT_MASTER_VOLUME)
	set_music_volume(DEFAULT_MUSIC_VOLUME)
	set_sfx_volume(DEFAULT_SFX_VOLUME)
	set_voice_volume(DEFAULT_VOICE_VOLUME)

# Select a random track from the music_tracks array
func select_random_track():
	if music_tracks.size() > 0:
		var random_index = randi() % music_tracks.size()
		current_track = music_tracks[random_index]

# Play the current selected track
func play_current_track():
	if current_track and current_track != "":
		var audio_stream = load(current_track)
		if audio_stream:
			play_music(audio_stream, true)

# Switch to a random track (called when mission is completed)
func switch_to_random_track():
	select_random_track()
	play_current_track()

# Switch to lich mode track
func switch_to_lich_mode_track():
	current_track = lich_mode_track
	play_current_track()

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