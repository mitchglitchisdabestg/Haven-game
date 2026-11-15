extends Node

enum Gravity { EARTH = 908, SPACE = 454 }

var deaths: int = 0

var health_potion_amount: float = 35.0

const LEVEL_TUTORIAL = 0
const LEVEL_EARTH = 1

var current_level: int = -1

func _ready() -> void:
	add_child(load("res://Scenes/Main menu/audio_stream_player.tscn").instantiate())
	
	
	
	
