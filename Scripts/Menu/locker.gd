extends Control
@onready var skin_grid: GridContainer = $SkinScroll/SkinGrid

var skin_labels: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$coins_lbl.text = "Coins: %d" % Constants.total_coins
	_create_skin_buttons()
	_update_equipped_skin_label()

func _on_quit_pressed() -> void:
	get_parent().show_main_menu()

func _on_level_select_pressed() -> void:
	get_parent().show_level_select()
	
func _create_skin_buttons() -> void:
	var resources: Array[SkinResource] = Constants.get_skin_resources()
	var label_font := load("res://Resources/Fonts/augiepixel.ttf") as Font

	for index in range(resources.size()):
		var skin := resources[index]
		var texture := load(skin.texture_path) as Texture2D
		if texture == null:
			push_error("Could not load skin texture: %s" % skin.texture_path)
			continue

		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(210.0, 175.0)
		skin_grid.add_child(slot)

		var button_center := CenterContainer.new()
		button_center.custom_minimum_size = Vector2(210.0, 135.0)
		slot.add_child(button_center)

		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(128.0, 128.0)
		button.pivot_offset = Vector2(64.0, 64.0)
		button.texture_normal = texture
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.pressed.connect(_on_skin_button_pressed.bind(index))
		button.mouse_entered.connect(_on_skin_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_skin_button_mouse_exited.bind(button))
		button_center.add_child(button)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var label := Label.new()
		label.text = skin.skin_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", label_font)
		label.add_theme_font_size_override("font_size", 24)
		slot.add_child(label)
		skin_labels[index] = label


func _on_skin_button_pressed(index: int) -> void:
	Constants.set_selected_skin(index)
	_update_equipped_skin_label()


func _update_equipped_skin_label() -> void:
	var resources: Array[SkinResource] = Constants.get_skin_resources()
	for index in skin_labels:
		var label: Label = skin_labels[index]
		var skin_name: String = resources[index].skin_name
		label.text = "%s ✓" % skin_name if index == Constants.selected_skin else skin_name


func _on_skin_button_mouse_entered(button: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_button_mouse_exited(button: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
