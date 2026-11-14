extends Node

enum Gravity { EARTH = 908, SPACE = 454 }

func _ready() -> void:
	add_child(load("res://Scenes/Main menu/audio_stream_player.tscn").instantiate())
	
	
	
	
