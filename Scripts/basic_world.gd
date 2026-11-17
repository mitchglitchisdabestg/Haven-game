extends StaticBody2D

enum Level { TUTORIAL, TUTORIAL_PART_2, EARTH, CLOUDS, SPACE }

var level_to_load: Level = Level.TUTORIAL

const LEVEL_SCENE_PATHS := {
	Level.TUTORIAL: "res://Scenes/tutorial.tscn",
	Level.TUTORIAL_PART_2: "res://Scenes/tutorialnew.tscn",
	Level.EARTH: "res://Scenes/earth.tscn"
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var scene_path: String = LEVEL_SCENE_PATHS.get(level_to_load, "")
	if scene_path.is_empty():
		push_error("No gameplay scene is configured for level id %d." % level_to_load)
		return

	var level_scene := load(scene_path) as PackedScene
	if level_scene == null:
		push_error("Could not load level scene: %s" % scene_path)
		return
	add_child(level_scene.instantiate())
