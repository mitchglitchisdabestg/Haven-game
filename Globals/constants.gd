extends Node

enum Gravity { EARTH = 908, SPACE = 454 }

const COINS_SAVE_PATH := "user://save_data.cfg"

var deaths: int = 0
var health_potion_amount: float = 35.0

const LEVEL_TUTORIAL = 0
const LEVEL_EARTH = 1

var current_level: int = -1

# Save coins when updated
var total_coins: int = 0:
	set(value):
		total_coins = value
		save_coins()


func _ready() -> void:
	load_coins()
	add_child(load("res://Scenes/Main menu/audio_stream_player.tscn").instantiate())


func save_coins() -> void:
	var config := ConfigFile.new()
	config.load(COINS_SAVE_PATH)
	config.set_value("Player", "total_coins", total_coins)
	config.save(COINS_SAVE_PATH)


func load_coins() -> void:
	var config := ConfigFile.new()
	var err := config.load(COINS_SAVE_PATH)
	if err == OK:
		total_coins = config.get_value("Player", "total_coins", 0)
