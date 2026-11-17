extends Control
@onready var background: TextureRect = $Background
@onready var menu_buttons: MarginContainer = $MarginContainer
@onready var level_select_page: Control = $LevelSelectPage
@onready var locker_page: Control = $LockerPage
@onready var settings_page: Control = $SettingsPage
@onready var credits_page: Control = $CreditsPage

@export var background_sway_speed: float = 0.05
@export var background_smoothing_speed: float = 6.0
var background_center: Vector2
var background_start_position: Vector2


@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var locker_button: Button = $MarginContainer/VBoxContainer/Locker
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $MarginContainer/VBoxContainer/CreditsButton
@onready var enable_audio_web: Button = $MarginContainer/VBoxContainer/enable_audio_web


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	background_center = get_viewport_rect().size / 2.0
	background_start_position = background.position
	_show_main_menu()
	
	if OS.get_name() != "Web":
		enable_audio_web.hide()
		enable_audio_web.disabled = true
		
	
func _on_new_game_button_pressed() -> void:
	show_level_select()

func _on_quit_pressed() -> void:
	get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = (mouse_pos - background_center) * background_sway_speed
	var target_position: Vector2 = background_start_position - offset
	var smoothing_weight := 1.0 - exp(-background_smoothing_speed * delta)
	background.position = background.position.lerp(target_position, smoothing_weight)

func show_level_select() -> void:
	_show_page(level_select_page)

func show_locker() -> void:
	_show_page(locker_page)

func show_settings() -> void:
	_show_page(settings_page)

func show_credits() -> void:
	_show_page(credits_page)

func show_main_menu() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	for page in [level_select_page, locker_page, settings_page, credits_page]:
		page.hide()
	menu_buttons.show()
	$Background3.show()
	$Background2.size = Vector2(616.0, 565.0)
	$Background2.position = Vector2(332.0, 87.0)
	$Background2.show()

func _show_page(page: Control) -> void:
	menu_buttons.hide()
	$Background3.hide()
	for other_page in [level_select_page, locker_page, settings_page, credits_page]:
		other_page.visible = other_page == page
		
		match page.name:
			"LevelSelectPage":
				$Background2.size = Vector2(1200.0, 565.0)
				$Background2.position = Vector2(39.0, 87.0)
			"LockerPage":
				$Background2.size = Vector2(1200.0, 565.0)
				$Background2.position = Vector2(39.0, 87.0)
			"SettingsPage":
				$Background2.hide()
				#$Background2.size = Vector2(1200.0, 565.0)
				#$Background2.position = Vector2(39.0, 87.0)
			"CreditsPage":
				$Background2.hide()
				#$Background2.size = Vector2(1200.0, 565.0)
				#$Background2.position = Vector2(39.0, 87.0)

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
	show_locker()

func _on_settings_button_pressed() -> void:
	show_settings()

func _on_credits_button_pressed() -> void:
	show_credits()


func _on_enable_audio_web_pressed() -> void:
	if OS.get_name() == "Web": Constants.add_audio()


func _on_enable_audio_web_mouse_entered() -> void:
	enable_audio_web.text = ">> Enable Audio"


func _on_enable_audio_web_mouse_exited() -> void:
	enable_audio_web.text = "Enable Audio"
