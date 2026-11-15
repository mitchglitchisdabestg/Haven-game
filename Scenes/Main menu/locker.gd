extends Control
@onready var background = $Background
var sway_speed : float = 0.05
var screen_center : Vector2
var start_position : Vector2

@onready var skin_3: TextureButton = $"Skin 3"
@onready var skin_2: TextureButton = $"Skin 2"
@onready var skin_5: TextureButton = $"Skin 5"
@onready var skin_4: TextureButton = $"Skin 4"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_center = get_viewport_rect().size / 2.0
	start_position = background.position
	

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = (mouse_pos - screen_center) * sway_speed
	background.position = start_position - offset

	
	
	
	
	



func _on_skin_1_pressed() -> void:
	Constants.selected_skin = 0


func _on_skin_2_pressed() -> void:
	Constants.selected_skin = 1


func _on_skin_3_pressed() -> void:
	Constants.selected_skin = 2

func _on_skin_4_pressed() -> void:
	Constants.selected_skin = 3

func _on_skin_5_pressed() -> void:
	Constants.selected_skin = 4


func _on_skin_1_mouse_entered() -> void:
	var t = create_tween()
	t.tween_property($"Skin 1", "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_1_mouse_exited() -> void:
	var t = create_tween()
	t.tween_property($"Skin 1", "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_2_mouse_entered() -> void:
	var t = create_tween()
	t.tween_property($"Skin 2", "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_2_mouse_exited() -> void:
	var t = create_tween()
	t.tween_property($"Skin 2", "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_3_mouse_entered() -> void:
	var t = create_tween()
	t.tween_property($"Skin 3", "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_3_mouse_exited() -> void:
	var t = create_tween()
	t.tween_property($"Skin 3", "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_4_mouse_entered() -> void:
	var t = create_tween()
	t.tween_property($"Skin 4", "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_4_mouse_exited() -> void:
	var t = create_tween()
	t.tween_property($"Skin 4", "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_5_mouse_entered() -> void:
	var t = create_tween()
	t.tween_property($"Skin 5", "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_skin_5_mouse_exited() -> void:
	var t = create_tween()
	t.tween_property($"Skin 5", "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
