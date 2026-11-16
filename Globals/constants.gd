extends Node

enum Gravity { EARTH = 908, SPACE = 454 }

const COINS_SAVE_PATH := "user://save_data.cfg"
const SKIN_RESOURCE_DIRECTORY := "res://Resources/Skins"

var deaths: int = 0
var health_potion_amount: float = 35.0

const LEVEL_TUTORIAL = 0
const LEVEL_EARTH = 1
const LEVEL_TEST_TUTORIAL = 2

var current_level: int = -1

var selected_skin: int = 0
var skin_resources: Array[SkinResource] = []

# Save coins when updated
var total_coins: int = 0:
	set(value):
		total_coins = value
		save_coins()


func _ready() -> void:
	load_skin_resources()
	load_coins()
	load_selected_skin()
	if OS.get_name() != "Web": add_audio()

func add_audio() -> void:
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


func load_skin_resources() -> void:
	skin_resources.clear()
	var directory := DirAccess.open(SKIN_RESOURCE_DIRECTORY)
	if directory == null:
		push_error("Could not open skin resource directory: %s" % SKIN_RESOURCE_DIRECTORY)
		return

	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "tres":
			continue

		var skin_path := "%s/%s" % [SKIN_RESOURCE_DIRECTORY, file_name]
		var skin := load(skin_path) as SkinResource
		if skin == null:
			push_error("Could not load skin resource: %s" % skin_path)
			continue
		if skin.skin_name.is_empty():
			skin.skin_name = file_name.get_basename().capitalize()
		skin_resources.append(skin)

	skin_resources.sort_custom(_sort_skin_resources)
	if skin_resources.is_empty():
		push_error("No .tres skin resources found in %s." % SKIN_RESOURCE_DIRECTORY)


func _sort_skin_resources(first: SkinResource, second: SkinResource) -> bool:
	if first.display_order == second.display_order:
		return first.skin_name < second.skin_name
	return first.display_order < second.display_order


func get_skin_resources() -> Array[SkinResource]:
	return skin_resources


func get_selected_skin_resource() -> SkinResource:
	if skin_resources.is_empty():
		return null
	return skin_resources[selected_skin]


func set_selected_skin(index: int) -> void:
	if index < 0 or index >= skin_resources.size():
		push_error("Skin index is out of range: %d" % index)
		return

	selected_skin = index

	var config := ConfigFile.new()
	var load_error := config.load(COINS_SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("Could not load player save data: %s" % error_string(load_error))
		return

	config.set_value("Player", "selected_skin", selected_skin)
	var save_error := config.save(COINS_SAVE_PATH)
	if save_error != OK:
		push_error("Could not save selected skin: %s" % error_string(save_error))


func load_selected_skin() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(COINS_SAVE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		return
	if load_error != OK:
		push_error("Could not load selected skin: %s" % error_string(load_error))
		return

	var saved_skin: Variant = config.get_value("Player", "selected_skin", 0)
	if typeof(saved_skin) != TYPE_INT or saved_skin < 0 or saved_skin >= skin_resources.size():
		push_warning("Saved skin index is invalid; using the default skin.")
		return

	selected_skin = int(saved_skin)
