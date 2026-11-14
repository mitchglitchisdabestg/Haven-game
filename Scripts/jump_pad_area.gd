@tool
extends Area2D

@export_enum("Small", "Medium", "Large") var jump_pad_type: int = 0:
	set(value):
		jump_pad_type = value
		_update_texture()

func _ready() -> void:
	_update_texture()

func _update_texture() -> void:
	if not is_node_ready():
		return
		
	match jump_pad_type:
		0: $Sprite2D.texture = preload("res://Resources/Prototype/Purple/texture_01.png")
		1: $Sprite2D.texture = preload("res://Resources/Prototype/Orange/texture_01.png")
		2: $Sprite2D.texture = preload("res://Resources/Prototype/Red/texture_01.png")

func _on_body_entered(body: Node2D) -> void:
	var rot: float = 45
	var time: float = 0.3
	if body.has_method("crouch_anim"):
		match jump_pad_type:
			0: body.velocity.y = body.jump_velocity / 1.5
			1: 
				body.velocity.y = body.jump_velocity
				rot = 135.0
			2: 
				body.velocity.y = body.jump_velocity * 1.5
				rot = 360.0
				time = 0.7
		
		var t = create_tween()
		t.tween_property(body.player_sprite_child, "rotation_degrees", body.player_sprite_child.rotation_degrees + rot * body.direction, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
