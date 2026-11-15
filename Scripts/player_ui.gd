extends Control

var player_parent: CharacterBody2D

var paused: bool = false

@onready var d_velocity: Label = $MarginContainer/debug/text_cont/velocity
@onready var d_delta: Label = $MarginContainer/debug/text_cont/delta
@onready var hp: ProgressBar = $MarginContainer/Control/hp
@onready var coins: Label = $MarginContainer/Control/coins

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
	can complete with orb = %s" %                                               \
	[str(player_parent.gravity),                                                \
	player_parent.velocity.x, player_parent.velocity.y,                         \
	player_parent.direction,                                                    \
	player_parent.jump_velocity, str(player_parent.can_wall_jump),              \
	str(player_parent.crouch_buffered), str(player_parent.jump_buffered),       \
	str(player_parent.crouch_buffer_used), str(player_parent.jump_buffer_used), \
	player_parent.acceleration, player_parent.friction,                         \
	str(player_parent.crouching), player_parent.deteriorate_amount_mult,        \
	str(player_parent.can_complete_with_orb)]
	
	d_delta.text = "delta = " + str(delta)
	
	hp.value = player_parent.hp
	coins.text = "Coins: " + str(player_parent.coins)


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
