extends Node
class_name ReplayPlaybackController

const DEFAULT_PLAYBACK_SPEED: float = 1.0
const REPLAY_FINISHED_SCENE: PackedScene = preload("res://Scenes/replay_finished.tscn")
const REPLAY_PAUSE_SCENE: PackedScene = preload("res://Scenes/replay_pause.tscn")
const REPLAY_HUD_SCENE: PackedScene = preload("res://Scenes/replay_hud.tscn")
const FREE_CAMERA_SPEED: float = 900.0

var _samples: Array[Dictionary] = []
var _sample_times: Array[float] = []
var _sound_events: Array[Dictionary] = []
var _sound_event_times: Array[float] = []
var _elapsed_seconds: float = 0.0
var _replay_duration: float = 0.0
var _playback_speed: float = DEFAULT_PLAYBACK_SPEED
var _ghost: ReplayGhost
var _hud: ReplayHUD
var _finish_screen: CanvasLayer
var _pause_menu: CanvasLayer
var _next_sound_event_index: int = 0
var _next_sample_index: int = 0
var _is_playing: bool = false
var _is_paused: bool = false
var _has_finished: bool = false
var _is_free_camera: bool = false
var _is_scrubbing: bool = false
var _resume_after_scrub: bool = false


func start_playback(replay_data: Dictionary, ghost: ReplayGhost) -> void:
	_samples.clear()
	_sample_times.clear()
	_sound_events.clear()
	_sound_event_times.clear()
	for sample_value in replay_data["samples"]:
		var sample: Dictionary = sample_value
		_samples.append(sample)

	var physics_tick_rate := float(replay_data["physics_tick_rate"])
	for sample_index in range(_samples.size()):
		var sample: Dictionary = _samples[sample_index]
		_sample_times.append(
			float(sample.get("simulation_time", float(sample["tick"]) / physics_tick_rate))
		)

	var sound_events_value: Variant = replay_data.get("sound_events", [])
	if typeof(sound_events_value) == TYPE_ARRAY:
		for event_value in sound_events_value:
			var sound_event: Dictionary = event_value
			_sound_events.append(sound_event)
			_sound_event_times.append(
				float(sound_event.get("simulation_time", float(sound_event["tick"]) / physics_tick_rate))
			)

	if _samples.is_empty():
		push_error("Cannot play a replay with no samples.")
		return

	var first_sample_time := _sample_times[0]
	for sample_index in range(_sample_times.size()):
		_sample_times[sample_index] -= first_sample_time
	for event_index in range(_sound_event_times.size()):
		_sound_event_times[event_index] = maxf(
			_sound_event_times[event_index] - first_sample_time,
			0.0
		)

	_replay_duration = _sample_times.back()
	SFX.stop_replay_audio()
	_elapsed_seconds = 0.0
	_next_sound_event_index = 0
	_next_sample_index = 0
	_ghost = ghost
	_is_playing = true
	_is_paused = false
	_has_finished = false
	_is_free_camera = false
	_is_scrubbing = false
	_resume_after_scrub = false
	set_process(true)
	SFX.set_replay_playback_speed(_playback_speed)
	_ghost.reset_playback()
	_ghost.apply_sample(_samples[0])
	_ghost.replay_camera.global_position = _ghost.global_position
	_ghost.replay_camera.make_current()

	_hud = REPLAY_HUD_SCENE.instantiate() as ReplayHUD
	if _hud == null:
		push_error("Could not instantiate replay HUD.")
		return
	get_tree().current_scene.add_child(_hud)
	_hud.setup(self)
	_hud.update_replay_state(_samples[0])
	_hud.update_timeline(_elapsed_seconds, _replay_duration)
	_play_sound_events_through(0.0)


func _process(delta: float) -> void:
	var replay_delta := _unscaled_delta(delta)
	if _is_playing and not _is_paused and is_instance_valid(_ghost):
		_elapsed_seconds += replay_delta * _playback_speed
		if _elapsed_seconds >= _replay_duration:
			_elapsed_seconds = _replay_duration
			_play_sound_events_through(_elapsed_seconds)
			_apply_state_at_time(_elapsed_seconds)
			_is_playing = false
			_is_paused = false
			SFX.set_replay_audio_paused(true)
			_show_finished_screen()
		else:
			_play_sound_events_through(_elapsed_seconds)
			_apply_state_at_time(_elapsed_seconds)

	_update_camera(replay_delta)
	if is_instance_valid(_hud):
		_hud.update_timeline(_elapsed_seconds, _replay_duration)


func set_playback_speed(speed: float) -> void:
	_playback_speed = maxf(speed, 0.01)
	SFX.set_replay_playback_speed(_playback_speed)


func get_playback_speed() -> float:
	return _playback_speed


func get_replay_duration() -> float:
	return _replay_duration


func get_elapsed_seconds() -> float:
	return _elapsed_seconds


func is_playback_paused() -> bool:
	return _is_paused


func is_playback_finished() -> bool:
	return _has_finished


func set_playback_paused(paused: bool) -> void:
	_is_paused = paused and _is_playing
	SFX.set_replay_audio_paused(_is_paused)


func begin_timeline_scrub() -> void:
	if _is_scrubbing:
		return

	_is_scrubbing = true
	_resume_after_scrub = (_is_playing and not _is_paused) or _has_finished
	if _is_playing and not _is_paused:
		set_playback_paused(true)


func end_timeline_scrub() -> void:
	if not _is_scrubbing:
		return

	_is_scrubbing = false
	var should_resume := _resume_after_scrub
	_resume_after_scrub = false
	if should_resume and _is_playing and not _has_finished:
		set_playback_paused(false)


func seek_to_time(replay_time: float) -> void:
	if _samples.is_empty() or not is_instance_valid(_ghost):
		return

	var was_finished := _has_finished
	_elapsed_seconds = clampf(replay_time, 0.0, _replay_duration)
	_next_sound_event_index = _find_first_sound_after_time(_elapsed_seconds)
	_apply_state_at_time(_elapsed_seconds)

	if _elapsed_seconds >= _replay_duration:
		_is_playing = false
		_is_paused = false
		SFX.set_replay_audio_paused(true)
		if is_instance_valid(_pause_menu):
			_pause_menu.queue_free()
			_pause_menu = null
		_show_finished_screen()
	elif was_finished:
		_has_finished = false
		if is_instance_valid(_finish_screen):
			_finish_screen.queue_free()
			_finish_screen = null
		_is_playing = true
		_is_paused = _is_scrubbing
		SFX.set_replay_audio_paused(_is_paused)

	if is_instance_valid(_hud):
		_hud.update_timeline(_elapsed_seconds, _replay_duration)


func set_camera_smoothing_enabled(enabled: bool) -> void:
	if is_instance_valid(_ghost):
		_ghost.replay_camera.position_smoothing_enabled = enabled


func set_camera_smoothing_speed(speed: float) -> void:
	if is_instance_valid(_ghost):
		_ghost.replay_camera.position_smoothing_speed = clampf(speed, 1.0, 20.0)


func set_free_camera_enabled(enabled: bool) -> void:
	_is_free_camera = enabled
	if not enabled:
		recenter_camera()


func set_camera_zoom(zoom: float) -> void:
	if is_instance_valid(_ghost):
		var zoom_value := clampf(zoom, 0.25, 4.0)
		_ghost.replay_camera.zoom = Vector2(zoom_value, zoom_value)


func recenter_camera() -> void:
	if not is_instance_valid(_ghost):
		return
	_is_free_camera = false
	_ghost.replay_camera.global_position = _ghost.global_position
	_ghost.replay_camera.reset_smoothing()


func restart_playback() -> void:
	if _samples.is_empty() or not is_instance_valid(_ghost):
		push_error("Cannot restart replay playback without loaded samples and a ghost.")
		return

	SFX.stop_replay_audio()
	_elapsed_seconds = 0.0
	_next_sound_event_index = 0
	_next_sample_index = 0
	_has_finished = false
	_is_paused = false
	_is_playing = true
	_is_scrubbing = false
	_resume_after_scrub = false
	SFX.set_replay_audio_paused(false)
	_ghost.reset_playback()
	_ghost.apply_sample(_samples[0])
	_hud.update_replay_state(_samples[0])
	if not _is_free_camera:
		recenter_camera()
	_play_sound_events_through(0.0)
	if is_instance_valid(_hud):
		_hud.update_timeline(_elapsed_seconds, _replay_duration)
	if is_instance_valid(_finish_screen):
		_finish_screen.queue_free()
	_finish_screen = null
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null


func _apply_state_at_time(replay_time: float) -> void:
	if _samples.is_empty() or not is_instance_valid(_ghost):
		return

	var final_sample_index := _samples.size() - 1
	if replay_time >= _replay_duration:
		_next_sample_index = final_sample_index
		var final_sample: Dictionary = _samples[final_sample_index]
		_ghost.apply_sample(final_sample)
		if is_instance_valid(_hud):
			_hud.update_replay_state(final_sample)
	else:
		_next_sample_index = _find_sample_at_or_before_time(replay_time)
		var next_sample_index := mini(_next_sample_index + 1, final_sample_index)
		var first_time := _sample_times[_next_sample_index]
		var second_time := _sample_times[next_sample_index]
		var interpolation_weight := 0.0
		if second_time > first_time:
			interpolation_weight = clampf(
				(replay_time - first_time) / (second_time - first_time),
				0.0,
				1.0
			)
		var current_sample: Dictionary = _ghost.apply_interpolated_samples(
			_samples[_next_sample_index],
			_samples[next_sample_index],
			interpolation_weight
		)
		if is_instance_valid(_hud):
			_hud.update_replay_state(current_sample)

	if not _is_free_camera:
		_ghost.replay_camera.global_position = _ghost.global_position


func _find_sample_at_or_before_time(replay_time: float) -> int:
	var low := 0
	var high := _sample_times.size()
	while low < high:
		var middle := (low + high) >> 1
		if _sample_times[middle] <= replay_time:
			low = middle + 1
		else:
			high = middle
	return maxi(low - 1, 0)


func _find_first_sound_after_time(replay_time: float) -> int:
	var low := 0
	var high := _sound_event_times.size()
	while low < high:
		var middle := (low + high) >> 1
		if _sound_event_times[middle] <= replay_time:
			low = middle + 1
		else:
			high = middle
	return low


func _play_sound_events_through(replay_time: float) -> void:
	while _next_sound_event_index < _sound_events.size():
		if _sound_event_times[_next_sound_event_index] > replay_time:
			return
		var sound_event: Dictionary = _sound_events[_next_sound_event_index]
		SFX.play_replay_event(
			str(sound_event["sound_id"]),
			float(sound_event.get("pitch_scale_at_1x", sound_event["pitch_scale"])),
			float(sound_event["volume_db"]),
			_playback_speed
		)
		_next_sound_event_index += 1


func _show_pause_menu() -> void:
	if _has_finished or is_instance_valid(_pause_menu):
		return
	if not _is_paused:
		set_playback_paused(true)
	_pause_menu = REPLAY_PAUSE_SCENE.instantiate() as CanvasLayer
	if _pause_menu == null:
		push_error("Could not instantiate replay pause menu.")
		set_playback_paused(false)
		return
	get_tree().current_scene.add_child(_pause_menu)
	_pause_menu.get_node("CenterContainer/Panel/Buttons/Resume").pressed.connect(_on_resume_pressed)
	_pause_menu.get_node("CenterContainer/Panel/Buttons/RestartReplay").pressed.connect(restart_playback)
	_pause_menu.get_node("CenterContainer/Panel/Buttons/ChangeReplay").pressed.connect(_on_change_replay_pressed)
	_pause_menu.get_node("CenterContainer/Panel/Buttons/ReplaySettings").pressed.connect(_on_pause_settings_pressed)
	_pause_menu.get_node("CenterContainer/Panel/Buttons/BackToLevelSelect").pressed.connect(_on_back_to_level_select_pressed)


func _on_resume_pressed() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null
	set_playback_paused(false)


func _on_pause_settings_pressed() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null
	_hud.set_settings_visible(true)


func _show_finished_screen() -> void:
	if _has_finished:
		return

	_has_finished = true
	_is_paused = false
	_finish_screen = REPLAY_FINISHED_SCENE.instantiate() as CanvasLayer
	if _finish_screen == null:
		push_error("Could not instantiate replay-finished screen.")
		return

	get_tree().current_scene.add_child(_finish_screen)
	_finish_screen.get_node("CenterContainer/Panel/VBoxContainer/RestartReplay").pressed.connect(restart_playback)
	_finish_screen.get_node("CenterContainer/Panel/VBoxContainer/PlayAnotherReplay").pressed.connect(_on_change_replay_pressed)
	_finish_screen.get_node("CenterContainer/Panel/VBoxContainer/BackToLevelSelect").pressed.connect(_on_back_to_level_select_pressed)


func _on_change_replay_pressed() -> void:
	ReplayManager.return_to_level_select(true)


func _on_back_to_level_select_pressed() -> void:
	ReplayManager.return_to_level_select()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _has_finished:
			return
		if _is_paused:
			if is_instance_valid(_pause_menu):
				_on_resume_pressed()
			else:
				_hud.set_settings_visible(false)
				_show_pause_menu()
		else:
			_show_pause_menu()
		return

	if key_event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if _is_playing:
			if _is_paused and is_instance_valid(_pause_menu):
				_on_resume_pressed()
			else:
				set_playback_paused(not _is_paused)
		return

	if key_event.keycode != KEY_LEFT and key_event.keycode != KEY_RIGHT:
		return

	get_viewport().set_input_as_handled()
	if _is_free_camera:
		return

	var seek_seconds := 5.0 if key_event.shift_pressed else 1.0
	if key_event.keycode == KEY_LEFT:
		seek_seconds = -seek_seconds
	seek_to_time(_elapsed_seconds + seek_seconds)


func _update_camera(unscaled_delta: float) -> void:
	if not is_instance_valid(_ghost):
		return

	var camera := _ghost.replay_camera
	if not _is_free_camera:
		camera.global_position = _ghost.global_position
		return

	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement.y += 1.0
	if movement.length_squared() > 0.0:
		camera.global_position += movement.normalized() * FREE_CAMERA_SPEED * unscaled_delta


func _unscaled_delta(delta: float) -> float:
	if Engine.time_scale <= 0.0:
		return 0.0
	return delta / Engine.time_scale


func _exit_tree() -> void:
	if ReplayManager.is_playback_active():
		ReplayManager.end_playback()
