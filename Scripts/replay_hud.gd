extends CanvasLayer
class_name ReplayHUD

var _playback_controller: ReplayPlaybackController

@onready var health_container: Control = $HUD/HealthContainer
@onready var health_bar: ProgressBar = $HUD/HealthContainer/HealthBar
@onready var health_label: Label = $HUD/HealthContainer/HealthLabel
@onready var debug_label: Label = $HUD/DebugLabel
@onready var controls_panel: Control = $HUD/ControlsPanel
@onready var controls_label: Label = $HUD/ControlsPanel/Controls
@onready var settings_panel: Control = $HUD/SettingsPanel
@onready var smoothing_toggle: CheckButton = $HUD/SettingsPanel/Settings/SmoothingToggle
@onready var smoothing_slider: HSlider = $HUD/SettingsPanel/Settings/SmoothingSpeed
@onready var free_camera_toggle: CheckButton = $HUD/SettingsPanel/Settings/FreeCameraToggle
@onready var zoom_slider: HSlider = $HUD/SettingsPanel/Settings/CameraZoom
@onready var health_visible_toggle: CheckButton = $HUD/SettingsPanel/Settings/HealthVisible
@onready var debug_visible_toggle: CheckButton = $HUD/SettingsPanel/Settings/DebugVisible
@onready var controls_visible_toggle: CheckButton = $HUD/SettingsPanel/Settings/ControlsVisible
@onready var playback_speed_dropdown: OptionButton = $HUD/SettingsPanel/Settings/PlaybackSpeed
@onready var timeline_slider: HSlider = $HUD/TimelinePanel/TimelineContent/Timeline
@onready var current_time_label: Label = $HUD/TimelinePanel/TimelineContent/TimeLabels/CurrentTime
@onready var total_time_label: Label = $HUD/TimelinePanel/TimelineContent/TimeLabels/TotalTime


func _ready() -> void:
	$HUD/SettingsButton.pressed.connect(_on_settings_button_pressed)
	$HUD/SettingsPanel/Settings/SmoothingToggle.toggled.connect(_on_smoothing_toggled)
	$HUD/SettingsPanel/Settings/SmoothingSpeed.value_changed.connect(_on_smoothing_speed_changed)
	$HUD/SettingsPanel/Settings/FreeCameraToggle.toggled.connect(_on_free_camera_toggled)
	$HUD/SettingsPanel/Settings/CameraZoom.value_changed.connect(_on_zoom_changed)
	$HUD/SettingsPanel/Settings/FollowCamera.pressed.connect(_on_follow_camera_pressed)
	$HUD/SettingsPanel/Settings/HealthVisible.toggled.connect(_on_health_visibility_toggled)
	$HUD/SettingsPanel/Settings/DebugVisible.toggled.connect(_on_debug_visibility_toggled)
	$HUD/SettingsPanel/Settings/ControlsVisible.toggled.connect(_on_controls_visibility_toggled)
	playback_speed_dropdown.item_selected.connect(_on_playback_speed_selected)
	timeline_slider.drag_started.connect(_on_timeline_drag_started)
	timeline_slider.drag_ended.connect(_on_timeline_drag_ended)
	timeline_slider.value_changed.connect(_on_timeline_value_changed)
	for speed in SettingsManager.REPLAY_PLAYBACK_SPEEDS:
		playback_speed_dropdown.add_item("%sx" % str(speed))

	settings_panel.visible = false
	controls_label.text = "Controls: Move %s | Jump %s | Sprint %s | Crouch %s | Pause %s\nReplay: Left/Right seek 1s; Shift+Left/Right seek 5s; Space pause/resume\nFree camera: WASD or Arrow Keys (arrows seek while following)" % [
		"%s / %s" % [_action_display("left", "A"), _action_display("right", "D")],
		_action_display("jump", "W / Space"),
		_action_display("sprint", "Shift"),
		_action_display("crouch", "Ctrl"),
		_action_display("back", "Esc")
	]


func setup(playback_controller: ReplayPlaybackController) -> void:
	_playback_controller = playback_controller
	var replay_settings := SettingsManager.get_replay_settings()

	smoothing_toggle.set_pressed_no_signal(bool(replay_settings["camera_smoothing_enabled"]))
	smoothing_slider.set_value_no_signal(float(replay_settings["camera_smoothing_speed"]))
	free_camera_toggle.set_pressed_no_signal(bool(replay_settings["free_camera_enabled"]))
	zoom_slider.set_value_no_signal(float(replay_settings["camera_zoom"]))
	health_visible_toggle.set_pressed_no_signal(bool(replay_settings["health_visible"]))
	debug_visible_toggle.set_pressed_no_signal(bool(replay_settings["debug_visible"]))
	controls_visible_toggle.set_pressed_no_signal(bool(replay_settings["controls_visible"]))
	health_container.visible = health_visible_toggle.button_pressed
	debug_label.visible = debug_visible_toggle.button_pressed
	controls_panel.visible = controls_visible_toggle.button_pressed
	_select_playback_speed(float(replay_settings["playback_speed"]))

	_playback_controller.set_camera_smoothing_enabled(smoothing_toggle.button_pressed)
	_playback_controller.set_camera_smoothing_speed(smoothing_slider.value)
	_playback_controller.set_free_camera_enabled(free_camera_toggle.button_pressed)
	_playback_controller.set_camera_zoom(zoom_slider.value)
	_playback_controller.set_playback_speed(float(replay_settings["playback_speed"]))
	update_timeline(0.0, _playback_controller.get_replay_duration())


func update_replay_state(sample: Dictionary) -> void:
	var max_health := float(sample.get("max_health", 100.0))
	var health := float(sample.get("health", max_health))
	health_bar.max_value = max_health
	health_bar.value = health
	health_label.text = "Health: %.0f / %.0f" % [health, max_health]

	var position := _sample_vector(sample, "position")
	var velocity := _sample_vector(sample, "velocity")
	debug_label.text = (
		"Replay Debug\n"
		+ "Position: %.2f, %.2f\n" % [position.x, position.y]
		+ "Velocity: %.2f, %.2f\n" % [velocity.x, velocity.y]
		+ "Health: %.0f / %.0f\n" % [health, max_health]
		+ "Direction: %.0f | Crouching: %s | Sprinting: %s\n"
		% [
			float(sample.get("direction", 0.0)),
			str(bool(sample.get("crouching", false))),
			str(bool(sample.get("sprinting", false)))
		]
		+ "Wall jump: %s | Jumps: %d / %d / %d / %d\n"
		% [
			str(bool(sample.get("can_wall_jump", false))),
			int(sample.get("times_jumped", 0)),
			int(sample.get("times_charged_jumped", 0)),
			int(sample.get("times_wall_jumped", 0)),
			int(sample.get("times_charged_wall_jumped", 0))
		]
	)


func update_timeline(current_time: float, total_time: float) -> void:
	var safe_total_time := maxf(total_time, 0.0)
	timeline_slider.max_value = safe_total_time
	timeline_slider.set_value_no_signal(clampf(current_time, 0.0, safe_total_time))
	current_time_label.text = _format_time(current_time)
	total_time_label.text = _format_time(total_time)


func set_settings_visible(should_show: bool) -> void:
	settings_panel.visible = should_show


func _sample_vector(sample: Dictionary, key: String) -> Vector2:
	var value: Variant = sample.get(key, [0.0, 0.0])
	if typeof(value) != TYPE_ARRAY:
		return Vector2.ZERO
	var values: Array = value
	if values.size() != 2:
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))


func _action_display(action: String, fallback: String) -> String:
	var key_names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			key_names.append((event as InputEventKey).as_text())
	return " / ".join(key_names) if not key_names.is_empty() else fallback


func _format_time(time_seconds: float) -> String:
	var total_milliseconds := maxi(roundi(maxf(time_seconds, 0.0) * 1000.0), 0)
	var hours := int(total_milliseconds / 3600000.0)
	var minutes := int(total_milliseconds / 60000.0) % 60
	var seconds := int(total_milliseconds / 1000.0) % 60
	var milliseconds := total_milliseconds % 1000
	if hours > 0:
		return "%02d:%02d:%02d.%03d" % [hours, minutes, seconds, milliseconds]
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]


func _select_playback_speed(speed: float) -> void:
	var selected_index := -1
	for index in range(SettingsManager.REPLAY_PLAYBACK_SPEEDS.size()):
		if is_equal_approx(SettingsManager.REPLAY_PLAYBACK_SPEEDS[index], speed):
			selected_index = index
			break
	if selected_index < 0:
		selected_index = SettingsManager.REPLAY_PLAYBACK_SPEEDS.find(1.0)
	playback_speed_dropdown.set_block_signals(true)
	playback_speed_dropdown.select(selected_index)
	playback_speed_dropdown.set_block_signals(false)


func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_smoothing_toggled(enabled: bool) -> void:
	_playback_controller.set_camera_smoothing_enabled(enabled)
	SettingsManager.set_replay_setting("camera_smoothing_enabled", enabled)


func _on_smoothing_speed_changed(speed: float) -> void:
	_playback_controller.set_camera_smoothing_speed(speed)
	SettingsManager.set_replay_setting("camera_smoothing_speed", speed)


func _on_free_camera_toggled(enabled: bool) -> void:
	_playback_controller.set_free_camera_enabled(enabled)
	SettingsManager.set_replay_setting("free_camera_enabled", enabled)


func _on_zoom_changed(zoom: float) -> void:
	_playback_controller.set_camera_zoom(zoom)
	SettingsManager.set_replay_setting("camera_zoom", zoom)


func _on_follow_camera_pressed() -> void:
	free_camera_toggle.set_pressed_no_signal(false)
	_playback_controller.set_free_camera_enabled(false)
	_playback_controller.recenter_camera()
	SettingsManager.set_replay_setting("free_camera_enabled", false)


func _on_health_visibility_toggled(show_health: bool) -> void:
	health_container.visible = show_health
	SettingsManager.set_replay_setting("health_visible", show_health)


func _on_debug_visibility_toggled(show_debug: bool) -> void:
	debug_label.visible = show_debug
	SettingsManager.set_replay_setting("debug_visible", show_debug)


func _on_controls_visibility_toggled(show_controls: bool) -> void:
	controls_panel.visible = show_controls
	SettingsManager.set_replay_setting("controls_visible", show_controls)


func _on_playback_speed_selected(index: int) -> void:
	if index < 0 or index >= SettingsManager.REPLAY_PLAYBACK_SPEEDS.size():
		return
	var speed: float = SettingsManager.REPLAY_PLAYBACK_SPEEDS[index]
	_playback_controller.set_playback_speed(speed)
	SettingsManager.set_replay_setting("playback_speed", speed)


func _on_timeline_drag_started() -> void:
	_playback_controller.begin_timeline_scrub()


func _on_timeline_drag_ended(_value_changed: bool) -> void:
	_playback_controller.end_timeline_scrub()


func _on_timeline_value_changed(value: float) -> void:
	_playback_controller.seek_to_time(value)
