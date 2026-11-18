extends Node

signal vfx_setting_changed(setting: String, enabled: bool)

const SETTINGS_PATH := "user://settings.json"
const INPUT_ACTIONS := ["left", "right", "crouch", "jump", "sprint", "back", "toggle_debug"]
const VFX_DEFAULTS := {
	"rolling_particles": true,
	"wall_rolling_particles": true,
	"wall_jump_burst": true,
	"jump_burst": true,
	"orb_particles": true,
	"pad_particles": true,
	"land_squish": true,
	"crouch_squish": true,
	"wall_squish": true,
	"movement_rotation": true,
	"jumping_rotation": true
}

var master_volume: float = 100.0
var music_volume: float = 100.0
var sfx_volume: float = 100.0
var sfx_pitch_scales_with_time_scale: bool = true
var player_debug_ui_visible: bool = true
var vfx_enabled: Dictionary = VFX_DEFAULTS.duplicate()

func _ready() -> void:
	add_music_bus()
	add_sfx_bus()
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

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 100.0)
	if not _apply_bus_volume("SFX", sfx_volume):
		return
	_save_settings()

func set_sfx_pitch_scales_with_time_scale(enabled: bool) -> void:
	sfx_pitch_scales_with_time_scale = enabled
	_save_settings()

func set_player_debug_ui_visible(visible: bool) -> void:
	player_debug_ui_visible = visible
	_save_settings()

func is_vfx_enabled(setting: String) -> bool:
	if not VFX_DEFAULTS.has(setting):
		push_error("Unknown VFX setting: %s" % setting)
		return false
	return vfx_enabled.get(setting, VFX_DEFAULTS[setting])

func set_vfx_enabled(setting: String, enabled: bool) -> void:
	if not VFX_DEFAULTS.has(setting):
		push_error("Unknown VFX setting: %s" % setting)
		return
	if is_vfx_enabled(setting) == enabled:
		return

	vfx_enabled[setting] = enabled
	_save_settings()
	vfx_setting_changed.emit(setting, enabled)

func add_music_bus() -> void:
	if AudioServer.get_bus_index("Music") >= 0:
		return

	var bus_index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "Music")
	AudioServer.set_bus_send(bus_index, "Master")

func add_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return

	var bus_index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "SFX")
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
	sfx_volume = _read_volume(settings, "sfx_volume", sfx_volume)
	sfx_pitch_scales_with_time_scale = _read_bool(
		settings,
		"sfx_pitch_scales_with_time_scale",
		sfx_pitch_scales_with_time_scale
	)
	player_debug_ui_visible = _read_bool(
		settings,
		"player_debug_ui_visible",
		player_debug_ui_visible
	)
	var saved_vfx: Variant = settings.get("vfx", {})
	if saved_vfx is Dictionary:
		for setting in VFX_DEFAULTS:
			vfx_enabled[setting] = _read_bool(saved_vfx, setting, VFX_DEFAULTS[setting])
	_apply_saved_keybindings(settings.get("keybindings", {}))

func _read_volume(settings: Dictionary, key: String, default_value: float) -> float:
	var value: Variant = settings.get(key, default_value)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default_value
	return clampf(float(value), 0.0, 100.0)

func _read_bool(settings: Dictionary, key: String, default_value: bool) -> bool:
	var value: Variant = settings.get(key, default_value)
	return value if typeof(value) == TYPE_BOOL else default_value

func _apply_volumes() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)

func _apply_bus_volume(bus_name: String, value: float) -> bool:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false

	var volume_db := -80.0 if value == 0.0 else linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	return true

func get_action_events(action: String) -> Array[InputEvent]:
	if not INPUT_ACTIONS.has(action) or not InputMap.has_action(action):
		push_error("Unknown input action: %s" % action)
		return []

	var events: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		events.append(event.duplicate())
	return events

func set_action_events(action: String, events: Array[InputEvent]) -> void:
	if not INPUT_ACTIONS.has(action) or not InputMap.has_action(action):
		push_error("Unknown input action: %s" % action)
		return

	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event.duplicate())
	_save_settings()

func _apply_saved_keybindings(bindings: Variant) -> void:
	if not bindings is Dictionary:
		return

	for action in INPUT_ACTIONS:
		if not bindings.has(action):
			continue

		var saved_events: Variant = bindings[action]
		if not saved_events is Array:
			push_warning("Ignoring invalid saved keybindings for action '%s'." % action)
			continue

		var key_events: Array[InputEvent] = []
		for saved_event in saved_events:
			if not saved_event is Dictionary:
				continue
			var key_event := _key_event_from_dict(saved_event)
			if key_event != null:
				key_events.append(key_event)

		InputMap.action_erase_events(action)
		for event in key_events:
			InputMap.action_add_event(action, event)

func _key_event_from_dict(data: Dictionary) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.keycode = int(data.get("keycode", 0))
	key_event.physical_keycode = int(data.get("physical_keycode", 0))
	key_event.unicode = int(data.get("unicode", 0))
	key_event.location = int(data.get("location", 0))
	key_event.shift_pressed = bool(data.get("shift_pressed", false))
	key_event.ctrl_pressed = bool(data.get("ctrl_pressed", false))
	key_event.alt_pressed = bool(data.get("alt_pressed", false))
	key_event.meta_pressed = bool(data.get("meta_pressed", false))
	return key_event

func _serialize_keybindings() -> Dictionary:
	var bindings: Dictionary = {}
	for action in INPUT_ACTIONS:
		var saved_events: Array[Dictionary] = []
		for event in InputMap.action_get_events(action):
			if not event is InputEventKey:
				continue
			saved_events.append({
				"keycode": event.keycode,
				"physical_keycode": event.physical_keycode,
				"unicode": event.unicode,
				"location": event.location,
				"shift_pressed": event.shift_pressed,
				"ctrl_pressed": event.ctrl_pressed,
				"alt_pressed": event.alt_pressed,
				"meta_pressed": event.meta_pressed
			})
		bindings[action] = saved_events
	return bindings

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save settings: %s" % error_string(FileAccess.get_open_error()))
		return

	var settings := {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"sfx_pitch_scales_with_time_scale": sfx_pitch_scales_with_time_scale,
		"player_debug_ui_visible": player_debug_ui_visible,
		"vfx": vfx_enabled,
		"keybindings": _serialize_keybindings()
	}
	file.store_string(JSON.stringify(settings, "\t"))
