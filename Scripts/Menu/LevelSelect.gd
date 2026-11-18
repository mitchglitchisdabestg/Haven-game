extends Control

const LEVEL_BUTTONS := [
	{"id": Constants.LEVEL_TUTORIAL, "path": "HBoxContainer2/Level 1"},
	{"id": Constants.LEVEL_TUTORIAL_PART_2, "path": "HBoxContainer2/Level 2"},
	{"id": Constants.LEVEL_EARTH, "path": "HBoxContainer2/Level 3"},
	{"id": Constants.LEVEL_CLOUDS, "path": "HBoxContainer2/Level 4"},
	{"id": Constants.LEVEL_SPACE, "path": "HBoxContainer2/Level 5"}
]

func _on_quit_pressed() -> void:
	_return_to_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	_return_to_main_menu()
	get_viewport().set_input_as_handled()

func _return_to_main_menu() -> void:
	if get_parent().has_method("show_main_menu"):
		get_parent().show_main_menu()
	else:
		get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_locker_pressed() -> void:
	get_parent().show_locker()

func _ready() -> void:
	for level_button in LEVEL_BUTTONS:
		var button_path: String = level_button["path"]
		var level_id: int = level_button["id"]
		var button := get_node_or_null(button_path) as TextureButton
		if button == null:
			push_error("Level button not found: %s" % button_path)
			continue

		button.pressed.connect(load_world.bind(level_id))
		_update_level_stats(button, level_id)

func load_world(level: int) -> void:
	Constants.deaths = 0
	var world: Node2D = load("res://Scenes/basic_world.tscn").instantiate()
	world.level_to_load = level
	Constants.current_level = level
	get_tree().change_scene_to_node(world)

func _update_level_stats(button: TextureButton, level_id: int) -> void:
	var stats_label := button.get_node_or_null("VBoxContainer/stats") as Label
	if stats_label == null:
		push_error("Stats label not found for level id %d." % level_id)
		return

	var stats := Constants.get_level_stats(level_id)
	var completion_status := "Completed" if stats["completed"] else "Not Completed"
	stats_label.text = "%s\nCoins: %d\nHelium cans: %d\nDeaths: %d" % [
		completion_status,
		stats["coins"],
		stats["helium"],
		stats["deaths"]
	]
