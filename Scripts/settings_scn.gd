extends Control

const ACTION_LABELS := {
	"left": "Move Left",
	"right": "Move Right",
	"crouch": "Crouch",
	"jump": "Jump",
	"sprint": "Sprint",
	"back": "Pause / Back"
}

@onready var master_slider: HSlider = $CenterContainer/Panel/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/Panel/VBoxContainer/MusicSlider
@onready var master_value: Label = $CenterContainer/Panel/VBoxContainer/MasterValue
@onready var music_value: Label = $CenterContainer/Panel/VBoxContainer/MusicValue
@onready var status: Label = $CenterContainer/Panel/VBoxContainer/Status
@onready var keybind_list: VBoxContainer = $CenterContainer/Panel/VBoxContainer/KeybindScroll/KeybindList

var waiting_for_action: String = ""
var waiting_for_event_index: int = -1

func _ready() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	_update_volume_labels()
	_build_keybind_rows()

func _input(event: InputEvent) -> void:
	if waiting_for_action.is_empty() or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		waiting_for_action = ""
		waiting_for_event_index = -1
		status.text = "Key rebind cancelled."
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

func _on_master_slider_value_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_update_volume_labels()

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)
	_update_volume_labels()

func _update_volume_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value)
	music_value.text = "%d%%" % int(music_slider.value)

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
			row.add_child(key_button)

			var remove_button := Button.new()
			remove_button.text = "x"
			remove_button.tooltip_text = "Remove this key"
			remove_button.pressed.connect(_remove_binding.bind(action, event_index))
			row.add_child(remove_button)

		var add_button := Button.new()
		add_button.text = "+"
		add_button.tooltip_text = "Add another key"
		add_button.pressed.connect(_begin_rebind.bind(action, -1))
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
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")
