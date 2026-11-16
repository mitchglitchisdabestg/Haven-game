extends Control

var player_parent: CharacterBody2D

var paused: bool = false

@onready var d_velocity: Label = $MarginContainer/debug/text_cont/velocity
@onready var d_delta: Label = $MarginContainer/debug/text_cont/delta
@onready var hp: ProgressBar = $MarginContainer/Control/hp
@onready var coins: Label = $MarginContainer/Control/VBoxContainer/coins
@onready var helium: Label = $MarginContainer/Control/VBoxContainer/helium
@onready var deaths: Label = $MarginContainer/Control/VBoxContainer/deaths

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

func _grant_debug_collectible(collectible_type: int) -> void:
	if not _can_use_debug_actions():
		return

	player_parent.collect(collectible_type)

func _can_use_debug_actions() -> bool:
	return player_parent != null and not player_parent.is_dead

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		if not paused: 
			%pause.show()
			$ColorRect.show()
			paused = true
			player_parent.set_process(false)
			player_parent.set_physics_process(false)
		else: 
			_on_unpause_pressed()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_parent: return
	
	# Show movement and input buffer states
	d_velocity.text = "gravity = %s
	velocity x = %d
	velocity y = %d
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
	
	hp.value = player_parent.hp
	coins.text = "Coins: " + str(player_parent.collectible_stats["Coins"])
	helium.text = "Helium Cans: " + str(player_parent.collectible_stats["Helium"])
	deaths.text = "Deaths: " + str(Constants.deaths)


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
