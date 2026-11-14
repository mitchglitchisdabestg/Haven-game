extends Control

func _ready() -> void:
	visible = false

func show_death_screen(collectible_stats: Dictionary) -> void:
	# Show the collected run totals
	var stats_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Stats
	var collectible_names: Array = collectible_stats.keys()
	collectible_names.sort()
	var stats_text := "Collectibles\n"

	if collectible_names.is_empty():
		stats_text += "None collected"
	else:
		for collectible_name in collectible_names:
			stats_text += "%s: %d\n" % [collectible_name, collectible_stats[collectible_name]]

	stats_label.text = stats_text.strip_edges()
	visible = true
	$CenterContainer/PanelContainer/VBoxContainer/MainMenuButton.grab_focus()

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_level_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")
