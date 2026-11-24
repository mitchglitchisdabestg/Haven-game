extends StaticBody2D

enum Level { TUTORIAL, TUTORIAL_PART_2, EARTH, CLOUDS, SPACE }

var level_to_load: Level = Level.TUTORIAL

const LEVEL_SCENE_PATHS := {
	Level.TUTORIAL: "res://Scenes/tutorial.tscn",
	Level.TUTORIAL_PART_2: "res://Scenes/tutorialnew.tscn",
	Level.EARTH: "res://Scenes/earth.tscn"
}
const REPLAY_GHOST_SCENE: PackedScene = preload("res://Scenes/replay_ghost.tscn")


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _enter_tree() -> void:
	if not ReplayManager.is_playback_active():
		return

	var player := get_node_or_null("player") as CharacterBody2D
	if player == null:
		push_error("Replay world does not contain the expected player node.")
		return

	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_process(false)
	player.set_physics_process(false)
	player.propagate_call("set_process", [false])
	player.propagate_call("set_physics_process", [false])
	player.propagate_call("set_process_input", [false])
	player.propagate_call("set_process_unhandled_input", [false])
	player.propagate_call("set_process_unhandled_key_input", [false])

	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true

	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false
		player_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var player_ui := player.get_node_or_null("CanvasLayer") as CanvasLayer
	if player_ui != null:
		player_ui.visible = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var scene_path: String = LEVEL_SCENE_PATHS.get(level_to_load, "")
	if scene_path.is_empty():
		push_error("No gameplay scene is configured for level id %d." % level_to_load)
		return

	var level_scene := load(scene_path) as PackedScene
	if level_scene == null:
		push_error("Could not load level scene: %s" % scene_path)
		if ReplayManager.is_playback_active():
			_abort_replay_playback()
		return
	add_child(level_scene.instantiate())
	if ReplayManager.is_playback_active():
		_start_replay_playback()


func supports_level(level_id: int) -> bool:
	return LEVEL_SCENE_PATHS.has(level_id)


func _start_replay_playback() -> void:
	var replay_data: Dictionary = ReplayManager.get_playback_data()
	var ghost := REPLAY_GHOST_SCENE.instantiate() as ReplayGhost
	if ghost == null:
		push_error("Could not instantiate replay ghost scene.")
		_abort_replay_playback()
		return

	add_child(ghost)
	var skin_metadata: Dictionary = replay_data["skin"]
	ghost.apply_skin_metadata(skin_metadata)

	var playback_controller := ReplayPlaybackController.new()
	playback_controller.name = "ReplayPlaybackController"
	add_child(playback_controller)
	playback_controller.start_playback(replay_data, ghost)


func _abort_replay_playback() -> void:
	ReplayManager.end_playback()
	var change_error := get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")
	if change_error != OK:
		push_error("Could not return to Level Select after replay initialization failed: %s" % error_string(change_error))
