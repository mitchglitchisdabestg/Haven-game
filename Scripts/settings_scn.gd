extends Control

@onready var master_slider: HSlider = $CenterContainer/Panel/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/Panel/VBoxContainer/MusicSlider
@onready var master_value: Label = $CenterContainer/Panel/VBoxContainer/MasterValue
@onready var music_value: Label = $CenterContainer/Panel/VBoxContainer/MusicValue
@onready var status: Label = $CenterContainer/Panel/VBoxContainer/Status

func _ready() -> void:
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	_update_volume_labels()

func _on_master_slider_value_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_update_volume_labels()

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)
	_update_volume_labels()

func _update_volume_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value)
	music_value.text = "%d%%" % int(music_slider.value)

func _on_error_message_changed(message: String) -> void:
	status.text = message

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")
