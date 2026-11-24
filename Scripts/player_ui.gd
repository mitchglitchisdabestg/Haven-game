extends Control

var player_parent: CharacterBody2D

var paused: bool = false

@onready var debug_container: Control = $MarginContainer/debug
@onready var d_velocity: Label = $MarginContainer/debug/text_cont/velocity
@onready var d_delta: Label = $MarginContainer/debug/text_cont/delta
@onready var hp: ProgressBar = $MarginContainer/Control/hp
@onready var coins: Label = $MarginContainer/Control/VBoxContainer/coins
@onready var helium: Label = $MarginContainer/Control/VBoxContainer/helium
@onready var deaths: Label = $MarginContainer/Control/VBoxContainer/deaths
@onready var player_x_input: LineEdit = $MarginContainer/debug/debug_actions/VBoxContainer/position_controls/x_position
@onready var player_y_input: LineEdit = $MarginContainer/debug/debug_actions/VBoxContainer/position_controls/y_position
@onready var mult_edit: LineEdit = %mult_edit
@onready var fall_damage_flash: ColorRect = $FallDamageFlash

var fall_damage_flash_tween: Tween

func _ready() -> void:
	mult_edit.text = str(Engine.time_scale)
	debug_container.visible = SettingsManager.player_debug_ui_visible

func _on_debug_health_potion_pressed() -> void:
	_grant_debug_collectible(2)

func _on_debug_health_barrel_pressed() -> void:
	_grant_debug_collectible(3)

func _on_debug_helium_pressed() -> void:
	_grant_debug_collectible(1)

func _on_debug_coin_pressed() -> void:
	_grant_debug_collectible(0)

func _on_debug_damage_pressed() -> void:
	if not _can_use_debug_actions():
		return

	player_parent.hp -= 10.0
	if player_parent.hp <= 0.0:
		player_parent.die()

func _on_debug_speedhack_pressed() -> void:
	if mult_edit.text.is_valid_float() or mult_edit.text.is_valid_int(): Engine.time_scale = float(mult_edit.text)

func _on_mult_edit_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float() or new_text.is_valid_int(): _on_debug_speedhack_pressed()

func _grant_debug_collectible(collectible_type: int) -> void:
	if not _can_use_debug_actions():
		return

	player_parent.collect(collectible_type, true)

func _on_debug_set_position_pressed() -> void:
	if not _can_use_debug_actions():
		return
	if not player_x_input.text.is_valid_float() or not player_y_input.text.is_valid_float():
		push_warning("Enter valid numeric X and Y coordinates.")
		return

	player_parent.global_position = Vector2(
		player_x_input.text.to_float(),
		player_y_input.text.to_float()
	)
	player_parent.velocity = Vector2.ZERO
	player_x_input.clear()
	player_y_input.clear()

func _on_x_position_text_submitted(new_text: String) -> void:
	if not _can_use_debug_actions():
		return
	if not new_text.is_valid_float() and not new_text.is_valid_int():
		push_warning("Enter a valid numeric X coordinate.")
		return

	var player_position := player_parent.global_position
	player_position.x = new_text.to_float()
	player_parent.global_position = player_position
	player_parent.velocity.x = 0.0
	player_x_input.clear()

func _on_y_position_text_submitted(new_text: String) -> void:
	if not _can_use_debug_actions():
		return
	if not new_text.is_valid_float() and not new_text.is_valid_int():
		push_warning("Enter a valid numeric Y coordinate.")
		return

	var player_position := player_parent.global_position
	player_position.y = new_text.to_float()
	player_parent.global_position = player_position
	player_parent.velocity.y = 0.0
	player_y_input.clear()

func _can_use_debug_actions() -> bool:
	return player_parent != null and not player_parent.is_dead

func _input(event: InputEvent) -> void:
	if ReplayManager.is_playback_active():
		return

	if event.is_action_pressed("toggle_debug") and not (event is InputEventKey and event.echo):
		var should_show_debug := not SettingsManager.player_debug_ui_visible
		SettingsManager.set_player_debug_ui_visible(should_show_debug)
		debug_container.visible = should_show_debug
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hovered_control := get_viewport().gui_get_hovered_control()
		if not _is_player_ui_button(hovered_control):
			var focused_control := get_viewport().gui_get_focus_owner()
			if focused_control != null:
				focused_control.release_focus()

	if event.is_action_pressed("back"):
		if not paused: 
			%pause.show()
			$ColorRect.show()
			paused = true
			player_parent.set_process(false)
			player_parent.set_physics_process(false)
		else: 
			_on_unpause_pressed()

func _is_player_ui_button(control: Control) -> bool:
	var current_control := control
	while current_control != null and self.is_ancestor_of(current_control):
		if current_control is BaseButton:
			return true
		current_control = current_control.get_parent() as Control
	return false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_parent: return
	
	# Show movement and input buffer states
	d_velocity.text = "gravity = %s
	velocity x = %.2f
	velocity y = %.2f
	pos x = %.2f
	pos y = %.2f
	max vertical velocity y = %.2f
	direction = %d
	jump velocity = %.2f
	can wall jump = %s
	crouch buffered = %s
	jump buffered = %s
	crouch buffer used = %s
	jump buffer used = %s
	acceleration = %.2f
	friction = %.2f
	crouching = %s
	deteriorate mult = %.2f
	impact strength = %.3f
	target scale y = %.3f
	target position y = %.3f
	squashed scale y = %.3f
	squashed position y = %.3f
	times jumped = %d
	times charged jumped = %d
	times wall jumped = %d
	times charged wall jumped = %d
	pixels ran while sprinting = %.1f
	can complete with orb = %s" %                                               \
	[str(player_parent.gravity),                                                \
	player_parent.velocity.x, player_parent.velocity.y,                         \
	player_parent.global_position.x,                                            \
	player_parent.global_position.y,                                            \
	player_parent.max_vertical_velocity_y,                                      \
	player_parent.direction,                                                    \
	player_parent.jump_velocity, str(player_parent.can_wall_jump),              \
	str(player_parent.crouch_buffered), str(player_parent.jump_buffered),       \
	str(player_parent.crouch_buffer_used), str(player_parent.jump_buffer_used), \
	player_parent.acceleration, player_parent.friction,                         \
	str(player_parent.crouching), player_parent.deteriorate_amount_mult,        \
	player_parent.impact_strength, player_parent.target_scale_y,                \
	player_parent.target_position_y, player_parent.squashed_scale_y,            \
	player_parent.squashed_position_y,                                          \
	player_parent.times_jumped, player_parent.times_charged_jumped,             \
	player_parent.times_wall_jumped, player_parent.times_charged_wall_jumped,   \
	player_parent.pixels_ran_while_sprinting,                                   \
	str(player_parent.can_complete_with_orb)]
	
	d_delta.text = "delta = " + str(delta)
	_update_position_placeholders()
	
	hp.value = player_parent.hp
	coins.text = "Coins: " + str(player_parent.collectible_stats["Coins"])
	helium.text = "Helium Cans: " + str(player_parent.collectible_stats["Helium"])
	deaths.text = "Deaths: " + str(Constants.deaths)

func _update_position_placeholders() -> void:
	if player_parent == null:
		return
	player_x_input.placeholder_text = str(snappedf(player_parent.global_position.x, 0.01))
	player_y_input.placeholder_text = str(snappedf(player_parent.global_position.y, 0.01))

func show_fall_damage_flash(
	impact_velocity_y: float,
	damage_dealt: float,
	damage_strength: float
) -> void:
	if damage_dealt <= 0.0:
		return

	if fall_damage_flash_tween and fall_damage_flash_tween.is_running():
		fall_damage_flash_tween.kill()

	var is_fatal_speed := impact_velocity_y >= 4000.0
	var flash_opacity := 1.0
	var flash_duration := 1.0
	if not is_fatal_speed:
		flash_opacity = lerpf(0.25, 0.6, clampf(damage_strength, 0.0, 1.0))
		flash_duration = 0.3

	fall_damage_flash.modulate.a = 0.0
	fall_damage_flash_tween = fall_damage_flash.create_tween()
	fall_damage_flash_tween.tween_property(fall_damage_flash, "modulate:a", flash_opacity, 0.04)
	fall_damage_flash_tween.tween_property(
		fall_damage_flash,
		"modulate:a",
		0.0,
		flash_duration - 0.04
	)

func _on_main_menu_pressed() -> void:
	Constants.current_level = -1
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_restart_pressed() -> void:
	var world: Node2D = load("res://Scenes/basic_world.tscn").instantiate()
	
	world.level_to_load = Constants.current_level
	
	get_tree().change_scene_to_node(world)

func _on_back_to_lvl_select_pressed() -> void:
	Constants.current_level = -1
	get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")


func _on_unpause_pressed() -> void:
	%pause.hide()
	$ColorRect.hide()
	paused = false
	player_parent.set_process(true)
	player_parent.set_physics_process(true)
