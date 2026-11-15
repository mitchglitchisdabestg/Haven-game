extends StaticBody2D

enum Level { TUTORIAL, EARTH }

var level_to_load: Level = Level.TUTORIAL

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match level_to_load:
		0: add_child(load("res://Scenes/tutorial.tscn").instantiate())
		1: add_child(load("res://Scenes/earth.tscn").instantiate())
