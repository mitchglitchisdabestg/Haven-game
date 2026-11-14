extends Node

const SETTINGS_PATH := "user://settings.json"

var master_volume: float = 100.0
var music_volume: float = 100.0

func _ready() -> void:
	add_music_bus()
	_load_settings()
	_apply_volumes()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 100.0)
	if not _apply_bus_volume("Master", master_volume):
		return
	_save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 100.0)
	if not _apply_bus_volume("Music", music_volume):
		return
	_save_settings()

func add_music_bus() -> void:
	if AudioServer.get_bus_index("Music") >= 0:
		return

	var bus_index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "Music")
	AudioServer.set_bus_send(bus_index, "Master")

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return
	if not json.data is Dictionary:
		return

	var settings: Dictionary = json.data
	master_volume = _read_volume(settings, "master_volume", master_volume)
	music_volume = _read_volume(settings, "music_volume", music_volume)

func _read_volume(settings: Dictionary, key: String, default_value: float) -> float:
	var value: Variant = settings.get(key, default_value)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default_value
	return clampf(float(value), 0.0, 100.0)

func _apply_volumes() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)

func _apply_bus_volume(bus_name: String, value: float) -> bool:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false

	var volume_db := -80.0 if value == 0.0 else linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	return true

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return

	var settings := {
		"master_volume": master_volume,
		"music_volume": music_volume
	}
	file.store_string(JSON.stringify(settings, "\t"))
