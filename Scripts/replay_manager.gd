extends Node

const REPLAY_DIRECTORY: String = "user://replays"
const FORMAT_VERSION: int = 1
const OUTCOME_FAILED: String = "failed"
const OUTCOME_COMPLETED: String = "completed"
const OUTCOME_ABANDONED: String = "abandoned"
const BASIC_WORLD_SCENE_PATH: String = "res://Scenes/basic_world.tscn"

var _is_recording: bool = false
var _recording_metadata: Dictionary = {}
var _samples: Array[Dictionary] = []
var _sound_events: Array[Dictionary] = []
var _last_sampled_physics_frame: int = -1
var _simulation_time: float = 0.0
var _pending_recording: Dictionary = {}
var _is_playback_active: bool = false
var _playback_data: Dictionary = {}
var _open_replay_picker_on_level_select: bool = false


func start_recording(level_id: int, skin_metadata: Dictionary) -> void:
	if _is_recording:
		push_error("Cannot start a replay recording while another recording is active.")
		return
	if not _pending_recording.is_empty():
		push_error("Cannot start a replay recording while another recording awaits a save decision.")
		return

	_recording_metadata = {
		"format_version": FORMAT_VERSION,
		"recorded_at_utc": Time.get_datetime_string_from_system(true, true),
		"level_id": level_id,
		"level_identifier": "level_%d" % level_id,
		"skin": skin_metadata.duplicate(true),
		"physics_tick_rate": maxi(Engine.physics_ticks_per_second, 1)
	}
	_samples.clear()
	_sound_events.clear()
	_last_sampled_physics_frame = -1
	_simulation_time = 0.0
	_is_recording = true


func record_sound_event(
	sound_id: String,
	physics_frame: int,
	pitch_scale: float,
	volume_db: float,
	pitch_scale_at_1x: float = -1.0
) -> void:
	if not _is_recording:
		return

	var event_tick := _samples.size()
	if not _samples.is_empty() and _last_sampled_physics_frame == physics_frame:
		event_tick -= 1
	var sound_event := {
		"sound_id": sound_id,
		"tick": maxi(event_tick, 0),
		"pitch_scale": pitch_scale,
		"volume_db": volume_db,
		"simulation_time": _simulation_time
	}
	if pitch_scale_at_1x > 0.0:
		sound_event["pitch_scale_at_1x"] = pitch_scale_at_1x
	if _last_sampled_physics_frame != physics_frame:
		sound_event["_physics_frame"] = physics_frame
	_sound_events.append(sound_event)


func record_sample(sample: Dictionary, physics_frame: int, simulation_delta: float = 0.0) -> void:
	if not _is_recording:
		return

	var is_same_physics_frame := not _samples.is_empty() and _last_sampled_physics_frame == physics_frame
	if not _samples.is_empty() and not is_same_physics_frame:
		_simulation_time += maxf(simulation_delta, 0.0)

	var sample_index := _samples.size()
	if is_same_physics_frame:
		sample_index -= 1
	var stored_sample: Dictionary = sample.duplicate(true)
	stored_sample["tick"] = sample_index
	stored_sample["simulation_time"] = _simulation_time

	if is_same_physics_frame:
		_samples[sample_index] = stored_sample
	else:
		_samples.append(stored_sample)
	_last_sampled_physics_frame = physics_frame

	for event_index in range(_sound_events.size()):
		var sound_event: Dictionary = _sound_events[event_index]
		if int(sound_event.get("_physics_frame", -1)) != physics_frame:
			continue
		sound_event["simulation_time"] = _simulation_time
		sound_event.erase("_physics_frame")
		_sound_events[event_index] = sound_event


func finalize_recording(
	outcome: String,
	final_sample: Dictionary,
	physics_frame: int,
	simulation_delta: float = 0.0
) -> void:
	if not _is_recording:
		return

	record_sample(final_sample, physics_frame, simulation_delta)
	_is_recording = false

	var replay_data: Dictionary = _recording_metadata.duplicate(true)
	replay_data["outcome"] = outcome
	replay_data["finalized_at_utc"] = Time.get_datetime_string_from_system(true, true)
	replay_data["sample_count"] = _samples.size()
	replay_data["duration_seconds"] = _simulation_time
	replay_data["samples"] = _samples.duplicate(true)
	replay_data["sound_events"] = _sound_events.duplicate(true)

	for sound_event in replay_data["sound_events"]:
		sound_event.erase("_physics_frame")

	if outcome == OUTCOME_ABANDONED:
		var recorded_at_utc := str(replay_data["recorded_at_utc"])
		var timestamp := recorded_at_utc.replace(":", "-").replace(" ", "_")
		replay_data["name"] = _get_unique_replay_name(
			"level_%d_%s" % [int(replay_data["level_id"]), timestamp]
		)
		var save_error := _save_replay(replay_data)
		if save_error != OK:
			push_error("Could not save abandoned replay: %s" % error_string(save_error))
	else:
		_pending_recording = replay_data

	_recording_metadata.clear()
	_samples.clear()
	_sound_events.clear()
	_last_sampled_physics_frame = -1
	_simulation_time = 0.0


func has_pending_recording() -> bool:
	return not _pending_recording.is_empty()


func save_pending_recording(replay_name: String) -> Error:
	if _pending_recording.is_empty():
		push_error("There is no finalized replay waiting to be saved.")
		return ERR_UNCONFIGURED

	var unique_name := _get_unique_replay_name(replay_name)
	_pending_recording["name"] = unique_name
	var save_error := _save_replay(_pending_recording)
	if save_error != OK:
		push_error("Could not save replay: %s" % error_string(save_error))
		return save_error

	_pending_recording.clear()
	return OK


func discard_pending_recording() -> void:
	_pending_recording.clear()


func is_recording() -> bool:
	return _is_recording


func is_playback_active() -> bool:
	return _is_playback_active


func get_playback_data() -> Dictionary:
	return _playback_data


func start_playback_file(path: String) -> void:
	if _is_recording:
		push_error("Cannot start replay playback while a recording is active.")
		return
	if _is_playback_active:
		end_playback()
	_open_replay_picker_on_level_select = false

	var replay_data := _load_replay_file(path)
	if replay_data.is_empty():
		return

	var world_scene := load(BASIC_WORLD_SCENE_PATH) as PackedScene
	if world_scene == null:
		push_error("Could not load replay world scene: %s" % BASIC_WORLD_SCENE_PATH)
		return

	var world := world_scene.instantiate()
	if not world.has_method("supports_level") or not bool(world.call("supports_level", int(replay_data["level_id"]))):
		push_error("Replay level id %d is not supported by the current level loader." % int(replay_data["level_id"]))
		world.free()
		return

	world.set("level_to_load", int(replay_data["level_id"]))
	_playback_data = replay_data
	_is_playback_active = true
	Constants.current_level = int(replay_data["level_id"])

	var change_error := get_tree().change_scene_to_node(world)
	if change_error != OK:
		push_error("Could not enter replay playback mode: %s" % error_string(change_error))
		end_playback()
		world.free()


func end_playback() -> void:
	SFX.stop_replay_audio()
	_is_playback_active = false
	_playback_data.clear()
	Constants.current_level = -1


func return_to_level_select(open_replay_picker: bool = false) -> void:
	end_playback()
	_open_replay_picker_on_level_select = open_replay_picker
	var change_error := get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")
	if change_error != OK:
		push_error("Could not return to Level Select: %s" % error_string(change_error))


func consume_replay_picker_request() -> bool:
	var should_open_picker := _open_replay_picker_on_level_select
	_open_replay_picker_on_level_select = false
	return should_open_picker


func _load_replay_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open replay file %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}

	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		push_error(
			"Could not parse replay JSON at line %d: %s" % [
				parser.get_error_line(),
				parser.get_error_message()
			]
		)
		return {}

	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Replay JSON root must be an object.")
		return {}

	var replay_data: Dictionary = parser.data
	if not _validate_replay_data(replay_data):
		return {}
	return replay_data


func _validate_replay_data(replay_data: Dictionary) -> bool:
	var format_version: Variant = replay_data.get("format_version")
	if not _is_integer_value(format_version) or int(format_version) != FORMAT_VERSION:
		push_error("Unsupported replay format version: %s" % str(format_version))
		return false

	var level_id: Variant = replay_data.get("level_id")
	if not _is_integer_value(level_id):
		push_error("Replay is missing a valid integer level_id.")
		return false

	var physics_tick_rate: Variant = replay_data.get("physics_tick_rate")
	if not _is_integer_value(physics_tick_rate) or int(physics_tick_rate) <= 0:
		push_error("Replay is missing a valid positive physics_tick_rate.")
		return false

	var skin: Variant = replay_data.get("skin")
	if typeof(skin) != TYPE_DICTIONARY:
		push_error("Replay is missing its skin metadata object.")
		return false

	var sample_count: Variant = replay_data.get("sample_count")
	var samples_value: Variant = replay_data.get("samples")
	if typeof(samples_value) != TYPE_ARRAY:
		push_error("Replay samples must be an array.")
		return false

	var samples: Array = samples_value
	if samples.is_empty() or not _is_integer_value(sample_count) or int(sample_count) != samples.size():
		push_error("Replay sample_count does not match its non-empty samples array.")
		return false

	var previous_sample_time: float = -1.0
	var samples_with_time: int = 0
	for sample_index in range(samples.size()):
		var sample_value: Variant = samples[sample_index]
		if typeof(sample_value) != TYPE_DICTIONARY:
			push_error("Replay sample %d must be an object." % sample_index)
			return false

		var sample: Dictionary = sample_value
		if not _validate_sample(sample, sample_index):
			return false
		if sample.has("simulation_time"):
			samples_with_time += 1
			var sample_time := float(sample["simulation_time"])
			if sample_time < previous_sample_time:
				push_error("Replay sample simulation times must be chronological.")
				return false
			previous_sample_time = sample_time
	if samples_with_time != 0 and samples_with_time != samples.size():
		push_error("Replay samples must either all contain simulation_time or all omit it.")
		return false

	var sound_events_value: Variant = replay_data.get("sound_events", [])
	if typeof(sound_events_value) != TYPE_ARRAY:
		push_error("Replay sound_events must be an array when present.")
		return false
	var previous_event_tick: int = -1
	var previous_event_time: float = -1.0
	for event_index in range(sound_events_value.size()):
		var event_value: Variant = sound_events_value[event_index]
		if typeof(event_value) != TYPE_DICTIONARY:
			push_error("Replay sound event %d must be an object." % event_index)
			return false
		var sound_event: Dictionary = event_value
		var sound_id: Variant = sound_event.get("sound_id")
		var event_tick: Variant = sound_event.get("tick")
		var pitch_scale: Variant = sound_event.get("pitch_scale")
		var pitch_scale_at_1x: Variant = sound_event.get("pitch_scale_at_1x")
		var volume_db: Variant = sound_event.get("volume_db")
		if typeof(sound_id) != TYPE_STRING or str(sound_id).is_empty():
			push_error("Replay sound event %d has an invalid sound_id." % event_index)
			return false
		if not SFX.has_replay_sound(str(sound_id)):
			push_error("Replay sound event %d uses an unsupported sound identifier: %s" % [event_index, str(sound_id)])
			return false
		if not _is_integer_value(event_tick) or int(event_tick) < 0 or int(event_tick) >= samples.size():
			push_error("Replay sound event %d has an invalid tick." % event_index)
			return false
		if not _is_number(pitch_scale) or float(pitch_scale) <= 0.0 or not _is_number(volume_db):
			push_error("Replay sound event %d has invalid playback parameters." % event_index)
			return false
		if sound_event.has("pitch_scale_at_1x") and (
			not _is_number(pitch_scale_at_1x) or float(pitch_scale_at_1x) <= 0.0
		):
			push_error("Replay sound event %d has an invalid pitch_scale_at_1x." % event_index)
			return false
		if int(event_tick) < previous_event_tick:
			push_error("Replay sound events must be ordered by tick.")
			return false
		var event_time := float(event_tick) / float(physics_tick_rate)
		if sound_event.has("simulation_time"):
			if not _is_number(sound_event["simulation_time"]):
				push_error("Replay sound event %d has an invalid simulation_time." % event_index)
				return false
			event_time = float(sound_event["simulation_time"])
		if event_time < 0.0 or event_time < previous_event_time:
			push_error("Replay sound events must have non-negative chronological times.")
			return false
		previous_event_time = event_time
		previous_event_tick = int(event_tick)
	return true


func _validate_sample(sample: Dictionary, sample_index: int) -> bool:
	var vector_keys: Array[String] = [
		"position",
		"velocity",
		"sprite_parent_position",
		"sprite_parent_scale"
	]
	for key in vector_keys:
		if not _is_numeric_pair(sample.get(key)):
			push_error("Replay sample %d has an invalid %s vector." % [sample_index, key])
			return false

	var numeric_keys: Array[String] = [
		"circle_mask_rotation_radians",
		"circle_mask_2_rotation_radians",
		"rolling_particles_amount_ratio",
		"wall_left_particles_amount_ratio",
		"wall_right_particles_amount_ratio"
	]
	for key in numeric_keys:
		if not _is_number(sample.get(key)):
			push_error("Replay sample %d has an invalid %s value." % [sample_index, key])
			return false

	var boolean_keys: Array[String] = [
		"rolling_particles_emitting",
		"wall_left_particles_emitting",
		"wall_right_particles_emitting"
	]
	for key in boolean_keys:
		if typeof(sample.get(key)) != TYPE_BOOL:
			push_error("Replay sample %d has an invalid %s value." % [sample_index, key])
			return false

	if not _is_integer_value(sample.get("tick")) or int(sample["tick"]) != sample_index:
		push_error("Replay sample %d has an invalid tick index." % sample_index)
		return false
	if sample.has("simulation_time") and (
		not _is_number(sample["simulation_time"]) or float(sample["simulation_time"]) < 0.0
	):
		push_error("Replay sample %d has an invalid simulation_time." % sample_index)
		return false

	for key in ["health", "max_health", "direction"]:
		if sample.has(key) and not _is_number(sample[key]):
			push_error("Replay sample %d has an invalid %s value." % [sample_index, key])
			return false
	if sample.has("simulation_gravity") and not _is_numeric_pair(sample["simulation_gravity"]):
		push_error("Replay sample %d has an invalid simulation_gravity vector." % sample_index)
		return false
	if sample.has("health") and sample.has("max_health") and (
		float(sample["max_health"]) <= 0.0
		or float(sample["health"]) < 0.0
		or float(sample["health"]) > float(sample["max_health"])
	):
		push_error("Replay sample %d has health outside its valid range." % sample_index)
		return false
	for key in ["crouching", "sprinting", "can_wall_jump"]:
		if sample.has(key) and typeof(sample[key]) != TYPE_BOOL:
			push_error("Replay sample %d has an invalid %s value." % [sample_index, key])
			return false
	return true


func _is_numeric_pair(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var pair: Array = value
	return pair.size() == 2 and _is_number(pair[0]) and _is_number(pair[1])


func _is_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value))


func _is_integer_value(value: Variant) -> bool:
	if not _is_number(value):
		return false
	if typeof(value) == TYPE_INT:
		return true

	var numeric_value: float = float(value)
	return is_finite(numeric_value) and numeric_value == floorf(numeric_value)


func _save_replay(replay_data: Dictionary) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(REPLAY_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error

	var replay_path := "%s/%s.json" % [REPLAY_DIRECTORY, str(replay_data["name"])]

	var file := FileAccess.open(replay_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(replay_data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error

	print("Replay saved to: %s" % ProjectSettings.globalize_path(replay_path))
	return OK


func _get_unique_replay_name(requested_name: String) -> String:
	var base_name := _sanitize_replay_name(requested_name)
	var candidate := base_name
	var suffix := 2
	while FileAccess.file_exists("%s/%s.json" % [REPLAY_DIRECTORY, candidate]):
		var suffix_text := " (%d)" % suffix
		candidate = base_name.left(100 - suffix_text.length()) + suffix_text
		suffix += 1
	return candidate


func _sanitize_replay_name(requested_name: String) -> String:
	const INVALID_CHARACTERS: String = "<>:\"/\\|?*"
	var sanitized := ""
	for character in requested_name.strip_edges():
		if character.unicode_at(0) < 32 or INVALID_CHARACTERS.contains(character):
			sanitized += "_"
		else:
			sanitized += character

	sanitized = sanitized.strip_edges()
	while sanitized.ends_with(".") or sanitized.ends_with(" "):
		sanitized = sanitized.left(sanitized.length() - 1)
	if sanitized.is_empty():
		sanitized = "Replay"
	if sanitized.length() > 100:
		sanitized = sanitized.left(100)

	var device_name := sanitized.get_slice(".", 0).to_upper()
	if device_name in ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]:
		sanitized = "_" + sanitized
	return sanitized
