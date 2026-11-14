extends Control
@onready var background = $Background
var sway_speed : float = 0.05
var screen_center : Vector2
var start_position : Vector2

@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var level_1: TextureButton = $"HBoxContainer2/Level 1"
@onready var level_2: TextureButton = $"HBoxContainer2/Level 2"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_center = get_viewport_rect().size / 2.0
	start_position = background.position
	

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = (mouse_pos - screen_center) * sway_speed
	background.position = start_position - offset


func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/basic_world.tscn")


func _on_level_2_pressed() -> void:
		get_tree().change_scene_to_file("res://Scenes/basic_platforms.tscn")
