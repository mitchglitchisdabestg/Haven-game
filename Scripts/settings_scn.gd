extends Control

const ACTION_LABELS := {
	"left": "Move Left",
	"right": "Move Right",
	"crouch": "Crouch",
	"jump": "Jump",
	"sprint": "Sprint",
	"back": "Pause / Back",
	"toggle_debug": "Toggle Debug UI"
}

const VFX_OPTIONS := [
	{"key": "rolling_particles", "label": "Rolling particles"},
	{"key": "wall_rolling_particles", "label": "Wall rolling particles"},
	{"key": "wall_jump_burst", "label": "Wall jump burst"},
	{"key": "jump_burst", "label": "Surface jump bursts"},
	{"key": "orb_particles", "label": "Orb particles"},
	{"key": "pad_particles", "label": "Pad particles"},
	{"key": "land_squish", "label": "Landing squish"},
	{"key": "crouch_squish", "label": "Crouch squish"},
	{"key": "wall_squish", "label": "Wall hit squish"},
	{"key": "movement_rotation", "label": "Movement rotation"},
	{"key": "jumping_rotation", "label": "Jumping rotation"}
]

const CONTENT_PATH := "CenterContainer/Panel/MarginContainer/ContentScroll/VBoxContainer/"

@onready var master_slider: HSlider = get_node(CONTENT_PATH + "MasterSlider")
@onready var music_slider: HSlider = get_node(CONTENT_PATH + "MusicSlider")
@onready var sfx_slider: HSlider = get_node(CONTENT_PATH + "SFXSlider")
@onready var master_value: Label = get_node(CONTENT_PATH + "MasterValue")
@onready var music_value: Label = get_node(CONTENT_PATH + "MusicValue")
@onready var sfx_value: Label = get_node(CONTENT_PATH + "SFXValue")
@onready var sfx_pitch_toggle: CheckButton = get_node(CONTENT_PATH + "SFXPitchToggle")
@onready var debug_ui_toggle: CheckButton = get_node(CONTENT_PATH + "DebugUIToggle")
@onready var status: Label = get_node(CONTENT_PATH + "Status")
@onready var keybind_list: VBoxContainer = get_node(CONTENT_PATH + "KeybindScroll/KeybindList")
@onready var vfx_option_grid: GridContainer = get_node(CONTENT_PATH + "VFXScroll/VFXOptionGrid")

var waiting_for_action: String = ""
var waiting_for_event_index: int = -1

func _ready() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	sfx_pitch_toggle.button_pressed = SettingsManager.sfx_pitch_scales_with_time_scale
	debug_ui_toggle.button_pressed = SettingsManager.player_debug_ui_visible
	_update_volume_labels()
	_build_vfx_toggles()
	_build_keybind_rows()

func _input(event: InputEvent) -> void:
	if waiting_for_action.is_empty() or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		cancel_key_rebind()
		_return_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	var key_event := event.duplicate() as InputEventKey
	key_event.pressed = false
	key_event.echo = false
	var events := SettingsManager.get_action_events(waiting_for_action)
	if waiting_for_event_index < 0:
		events.append(key_event)
	elif waiting_for_event_index < events.size():
		events[waiting_for_event_index] = key_event
	else:
		push_error("Key binding index is out of range for action '%s'." % waiting_for_action)
		return

	var rebound_action := waiting_for_action
	waiting_for_action = ""
	waiting_for_event_index = -1
	SettingsManager.set_action_events(rebound_action, events)
	status.text = "Key binding saved."
	_build_keybind_rows()
	get_viewport().set_input_as_handled()

func cancel_key_rebind() -> void:
	waiting_for_action = ""
	waiting_for_event_index = -1
	status.text = "Key rebind cancelled."

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	_return_to_main_menu()
	get_viewport().set_input_as_handled()

func _return_to_main_menu() -> void:
	cancel_key_rebind()
	if get_parent().has_method("show_main_menu"):
		get_parent().show_main_menu()
	else:
		get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_master_slider_value_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_update_volume_labels()

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)
	_update_volume_labels()

func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)
	_update_volume_labels()

func _on_sfx_pitch_toggle_toggled(enabled: bool) -> void:
	SettingsManager.set_sfx_pitch_scales_with_time_scale(enabled)

func _on_debug_ui_toggle_toggled(enabled: bool) -> void:
	SettingsManager.set_player_debug_ui_visible(enabled)

func _build_vfx_toggles() -> void:
	for child in vfx_option_grid.get_children():
		child.queue_free()

	for option in VFX_OPTIONS:
		var setting: String = option["key"]
		var toggle := CheckButton.new()
		toggle.text = option["label"]
		toggle.button_pressed = SettingsManager.is_vfx_enabled(setting)
		toggle.toggled.connect(_on_vfx_toggle_toggled.bind(setting))
		vfx_option_grid.add_child(toggle)

func _on_vfx_toggle_toggled(enabled: bool, setting: String) -> void:
	SettingsManager.set_vfx_enabled(setting, enabled)

func _update_volume_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value)
	music_value.text = "%d%%" % int(music_slider.value)
	sfx_value.text = "%d%%" % int(sfx_slider.value)

func _build_keybind_rows() -> void:
	for child in keybind_list.get_children():
		child.queue_free()

	for action in SettingsManager.INPUT_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		keybind_list.add_child(row)

		var action_label := Label.new()
		action_label.custom_minimum_size.x = 120.0
		action_label.text = ACTION_LABELS.get(action, action.capitalize())
		row.add_child(action_label)

		var events := SettingsManager.get_action_events(action)
		if events.is_empty():
			var unbound_label := Label.new()
			unbound_label.text = "Unbound"
			unbound_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(unbound_label)

		for event_index in range(events.size()):
			var key_button := Button.new()
			key_button.text = events[event_index].as_text()
			key_button.custom_minimum_size.x = 72.0
			key_button.pressed.connect(_begin_rebind.bind(action, event_index))
			key_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row.add_child(key_button)

			var remove_button := Button.new()
			remove_button.text = "x"
			remove_button.tooltip_text = "Remove this key"
			remove_button.pressed.connect(_remove_binding.bind(action, event_index))
			remove_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row.add_child(remove_button)

		var add_button := Button.new()
		add_button.text = "+"
		add_button.tooltip_text = "Add another key"
		add_button.pressed.connect(_begin_rebind.bind(action, -1))
		add_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.add_child(add_button)

func _begin_rebind(action: String, event_index: int) -> void:
	waiting_for_action = action
	waiting_for_event_index = event_index
	status.text = "Press a key to bind %s. Escape cancels." % ACTION_LABELS.get(action, action)

func _remove_binding(action: String, event_index: int) -> void:
	var events := SettingsManager.get_action_events(action)
	if event_index < 0 or event_index >= events.size():
		push_error("Key binding index is out of range for action '%s'." % action)
		return

	events.remove_at(event_index)
	SettingsManager.set_action_events(action, events)
	status.text = "Key binding removed."
	_build_keybind_rows()

func _on_error_message_changed(message: String) -> void:
	status.text = message

func _on_back_button_pressed() -> void:
	get_parent().show_main_menu()
