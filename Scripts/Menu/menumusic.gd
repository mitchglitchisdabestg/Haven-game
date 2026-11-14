extends AudioStreamPlayer

var music_position = 0.0
var music_is_playing = false
@onready var audio_player: AudioStreamPlayer = $"."


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !music_is_playing:
		audio_player.play(music_position)
		music_is_playing = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if !music_is_playing:
		audio_player.play(music_position)
		music_is_playing = true
	else:
		music_position = audio_player.get_playback_position()
		audio_player.stop()
		music_is_playing = false
