extends Control
@onready var background = $Background
var sway_speed : float = 0.05
var screen_center : Vector2
var start_position : Vector2


@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var locker_button: Button = $MarginContainer/VBoxContainer/Locker
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $MarginContainer/VBoxContainer/CreditsButton
@onready var enable_audio_web: Button = $MarginContainer/VBoxContainer/enable_audio_web


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_center = get_viewport_rect().size / 2.0
	start_position = background.position
	
	if OS.get_name() != "Web":
		enable_audio_web.hide()
		enable_audio_web.disabled = true
		
	
func _on_new_game_button_pressed() -> void:

	get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")

	

func _on_quit_pressed() -> void:
	get_tree().quit()
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = (mouse_pos - screen_center) * sway_speed
	background.position = start_position - offset


func _on_new_game_button_mouse_entered() -> void:
	new_game_button.text = ">> Level Select"

func _on_new_game_button_mouse_exited() -> void:
	new_game_button.text = "Level Select"

func _on_locker_button_mouse_entered() -> void:
	locker_button.text = ">> Locker"

func _on_locker_button_mouse_exited() -> void:
	locker_button.text = "Locker"

func _on_settings_button_mouse_entered() -> void:
	settings_button.text = ">> Settings"

func _on_settings_button_mouse_exited() -> void:
	settings_button.text = "Settings"

func _on_quit_button_mouse_entered() -> void:
	quit_button.text = ">> Quit"

func _on_quit_button_mouse_exited() -> void:
	quit_button.text = "Quit"
	
func _on_credits_button_mouse_entered() -> void:
	credits_button.text = ">> Credits"
func _on_credits_button_mouse_exited() -> void:
	credits_button.text = "Credits"

func _on_locker_pressed() -> void:
		get_tree().change_scene_to_file("res://Scenes/Main menu/Locker.tscn")

func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/settings.tscn")

func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/credits.tscn")


func _on_enable_audio_web_pressed() -> void:
	if OS.get_name() == "Web": Constants.add_audio()


func _on_enable_audio_web_mouse_entered() -> void:
	enable_audio_web.text = ">> Enable Audio"


func _on_enable_audio_web_mouse_exited() -> void:
	enable_audio_web.text = "Enable Audio"
