extends Control

var player_parent: CharacterBody2D

@onready var d_velocity: Label = $MarginContainer/debug/text_cont/velocity
@onready var d_delta: Label = $MarginContainer/debug/text_cont/delta

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_parent: return
	
	d_velocity.text = "gravity = %s
	velocity x = %d
	velocity y = %d
	crouching = %s
	player_sprite pos y = %.2f" % [str(player_parent.gravity), player_parent.velocity.x, player_parent.velocity.y, str(player_parent.crouching), player_parent.player_sprite.position.y]
	
	d_delta.text = "delta = " + str(delta)
