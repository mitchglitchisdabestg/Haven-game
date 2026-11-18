extends Control

func _on_back_button_pressed() -> void:
	_return_to_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	_return_to_main_menu()
	get_viewport().set_input_as_handled()

func _return_to_main_menu() -> void:
	if get_parent().has_method("show_main_menu"):
		get_parent().show_main_menu()
	else:
		get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")
