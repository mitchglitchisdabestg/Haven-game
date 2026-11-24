extends CanvasLayer
class_name ReplaySavePrompt

signal save_confirmed(replay_name: String)
signal discard_requested

@onready var choice_panel: Control = $CenterContainer/Panel/Choice
@onready var name_panel: Control = $CenterContainer/Panel/NameEntry
@onready var replay_name_input: LineEdit = $CenterContainer/Panel/NameEntry/ReplayName
@onready var error_label: Label = $CenterContainer/Panel/NameEntry/Error


func _ready() -> void:
	$CenterContainer/Panel/Choice/SaveReplay.pressed.connect(_on_save_replay_pressed)
	$CenterContainer/Panel/Choice/DontSave.pressed.connect(func() -> void: discard_requested.emit())
	$CenterContainer/Panel/NameEntry/Confirm.pressed.connect(_on_confirm_pressed)
	$CenterContainer/Panel/NameEntry/Cancel.pressed.connect(_on_cancel_name_pressed)
	replay_name_input.text_submitted.connect(_on_name_submitted)
	choice_panel.visible = true
	name_panel.visible = false
	$CenterContainer/Panel/Choice/SaveReplay.grab_focus()


func show_save_error(message: String) -> void:
	error_label.text = "Could not save replay: %s" % message
	error_label.visible = true
	name_panel.visible = true
	choice_panel.visible = false


func _on_save_replay_pressed() -> void:
	error_label.visible = false
	replay_name_input.text = ""
	choice_panel.visible = false
	name_panel.visible = true
	replay_name_input.grab_focus()


func _on_confirm_pressed() -> void:
	var replay_name := replay_name_input.text.strip_edges()
	if replay_name.is_empty():
		error_label.text = "Enter a replay name."
		error_label.visible = true
		return
	save_confirmed.emit(replay_name)


func _on_name_submitted(_text: String) -> void:
	_on_confirm_pressed()


func _on_cancel_name_pressed() -> void:
	error_label.visible = false
	name_panel.visible = false
	choice_panel.visible = true
	$CenterContainer/Panel/Choice/SaveReplay.grab_focus()
