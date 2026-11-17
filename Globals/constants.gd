extends Node

enum Gravity { EARTH = 1400, SPACE = 700 }

const COINS_SAVE_PATH := "user://save_data.cfg"
const LEVEL_STATS_SAVE_PATH := "user://level_stats.cfg"
const SAVE_DATA_PASSWORD := "HavenGameLocalSave_v1"
const SKIN_RESOURCE_DIRECTORY := "res://Resources/Skins"

var deaths: int = 0
var health_potion_amount: float = 35.0

const LEVEL_TUTORIAL = 0
const LEVEL_TUTORIAL_PART_2 = 1
const LEVEL_EARTH = 2
const LEVEL_CLOUDS = 3
const LEVEL_SPACE = 4
const LEVEL_TEST_TUTORIAL = LEVEL_TUTORIAL_PART_2

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
	var load_error := _load_save_config(COINS_SAVE_PATH, config)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("Could not load player save data before saving coins: %s" % error_string(load_error))
		return
	config.set_value("Player", "total_coins", total_coins)
	var save_error := config.save_encrypted_pass(COINS_SAVE_PATH, SAVE_DATA_PASSWORD)
	if save_error != OK:
		push_error("Could not encrypt player save data: %s" % error_string(save_error))


func load_coins() -> void:
	var config := ConfigFile.new()
	var err := _load_save_config(COINS_SAVE_PATH, config)
	if err == OK:
		total_coins = _read_saved_count(config.get_value("Player", "total_coins", 0))
	elif err != ERR_FILE_NOT_FOUND:
		push_error("Could not load player save data: %s" % error_string(err))


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
	var load_error := _load_save_config(COINS_SAVE_PATH, config)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("Could not load player save data: %s" % error_string(load_error))
		return

	config.set_value("Player", "selected_skin", selected_skin)
	var save_error := config.save_encrypted_pass(COINS_SAVE_PATH, SAVE_DATA_PASSWORD)
	if save_error != OK:
		push_error("Could not encrypt selected skin save data: %s" % error_string(save_error))


func load_selected_skin() -> void:
	var config := ConfigFile.new()
	var load_error := _load_save_config(COINS_SAVE_PATH, config)
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


func get_level_stats(level_id: int) -> Dictionary:
	var stats := {
		"completed": false,
		"coins": 0,
		"helium": 0,
		"deaths": 0
	}
	if level_id < 0:
		push_error("Cannot load stats for invalid level id: %d" % level_id)
		return stats

	var config := ConfigFile.new()
	var load_error := _load_save_config(LEVEL_STATS_SAVE_PATH, config)
	if load_error == ERR_FILE_NOT_FOUND:
		return stats
	if load_error != OK:
		push_error("Could not load level stats: %s" % error_string(load_error))
		return stats

	var section := "Level_%d" % level_id
	var completed_value: Variant = config.get_value(section, "completed", false)
	stats["completed"] = completed_value if typeof(completed_value) == TYPE_BOOL else false
	stats["coins"] = _read_saved_count(config.get_value(section, "coins", 0))
	stats["helium"] = _read_saved_count(config.get_value(section, "helium", 0))
	stats["deaths"] = _read_saved_count(config.get_value(section, "deaths", 0))
	return stats


func record_level_stats(
	level_id: int,
	collectible_stats: Dictionary,
	completed: bool,
	death_increment: int = 0
) -> void:
	if level_id < 0:
		push_error("Cannot save stats for invalid level id: %d" % level_id)
		return

	var config := ConfigFile.new()
	var load_error := _load_save_config(LEVEL_STATS_SAVE_PATH, config)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("Could not load level stats before saving: %s" % error_string(load_error))
		return

	var section := "Level_%d" % level_id
	var previous_coins := _read_saved_count(config.get_value(section, "coins", 0))
	var previous_helium := _read_saved_count(config.get_value(section, "helium", 0))
	var previous_deaths := _read_saved_count(config.get_value(section, "deaths", 0))
	var previous_completed: Variant = config.get_value(section, "completed", false)

	config.set_value(section, "completed", completed or (previous_completed is bool and previous_completed))
	config.set_value(section, "coins", maxi(previous_coins, _read_saved_count(collectible_stats.get("Coins", 0))))
	config.set_value(section, "helium", maxi(previous_helium, _read_saved_count(collectible_stats.get("Helium", 0))))
	config.set_value(section, "deaths", previous_deaths + maxi(death_increment, 0))

	var save_error := config.save_encrypted_pass(LEVEL_STATS_SAVE_PATH, SAVE_DATA_PASSWORD)
	if save_error != OK:
		push_error("Could not encrypt level stats: %s" % error_string(save_error))


func _load_save_config(path: String, config: ConfigFile) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var is_encrypted := file.get_buffer(4) == "GDEC".to_ascii_buffer()
	file.close()

	if is_encrypted:
		return config.load_encrypted_pass(path, SAVE_DATA_PASSWORD)

	var legacy_load_error := config.load(path)
	if legacy_load_error != OK:
		return legacy_load_error

	var migration_error := config.save_encrypted_pass(path, SAVE_DATA_PASSWORD)
	if migration_error != OK:
		push_error("Could not encrypt legacy save data at %s: %s" % [path, error_string(migration_error)])
		return migration_error
	return OK


func _read_saved_count(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)
