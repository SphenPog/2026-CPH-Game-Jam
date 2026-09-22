extends Node2D

@onready var music_player: AudioStreamPlayer = $MusicPlayer

func play_music(track: AudioStream) -> void:
	if not track:
		return
		
	if music_player.stream == track and music_player.playing:
		return
		
	music_player.stream = track
	music_player.play()

func play_sfx(stream: AudioStream, pitch_scale: float = 1.0, random_pitch: float = 0.0) -> AudioStreamPlayer:
	if not stream:
		return
		
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = stream
	sfx_player.pitch_scale = pitch_scale + randf_range(-random_pitch, random_pitch)
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
	
	return sfx_player

func play_sfx_at_position(stream: AudioStream, world_position: Vector2, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
		
	var sfx_player = AudioStreamPlayer2D.new()
	sfx_player.stream = stream
	sfx_player.global_position = world_position
	sfx_player.pitch_scale = pitch_scale
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
