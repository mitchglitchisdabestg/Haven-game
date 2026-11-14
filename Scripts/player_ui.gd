extends Control

var player_parent: CharacterBody2D

@onready var d_velocity: Label = $MarginContainer/debug/text_cont/velocity
@onready var d_delta: Label = $MarginContainer/debug/text_cont/delta
@onready var hp: ProgressBar = $MarginContainer/Control/hp

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_parent: return
	
	d_velocity.text = "gravity = %s
	velocity x = %d
	velocity y = %d
	direction = %d
	jump velocity = %.2f
	can wall jump = %s
	acceleration = %.2f
	friction = %.2f
	crouching = %s
	deteriorate mult = %.2f" %                                                  \
	[str(player_parent.gravity),                                                \
	player_parent.velocity.x, player_parent.velocity.y,                         \
	player_parent.direction,                                                    \
	player_parent.jump_velocity, str(player_parent.can_wall_jump),              \
	player_parent.acceleration, player_parent.friction,                         \
	str(player_parent.crouching), player_parent.deteriorate_amount_mult]
	
	d_delta.text = "delta = " + str(delta)
	
	hp.value = player_parent.hp
