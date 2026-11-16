@tool
extends Area2D

@export_enum("Small", "Medium", "Large", "End") var jump_orb_type: int = 0:
	set(value):
		jump_orb_type = value
		_update_color()

var scale_tween: Tween

func _ready() -> void:
	_update_color()

func _update_color() -> void:
	if not is_node_ready():
		return

	# Match orb colors to the selected launch strength
	match jump_orb_type:
		0:
			$orb.modulate = Color(0.65, 0.3, 1.0, 1.0)
			$orb_center.modulate = Color(0.85, 0.68, 1.0, 1.0)
		1:
			$orb.modulate = Color(1.0, 0.78, 0.16, 1.0)
			$orb_center.modulate = Color(1.0, 0.94, 0.64, 1.0)
		2:
			$orb.modulate = Color(1.0, 0.2, 0.25, 1.0)
			$orb_center.modulate = Color(1.0, 0.65, 0.67, 1.0)
		3:
			$orb.modulate = Color(0.212, 1.0, 1.0, 1.0)
			$orb_center.modulate = Color(0.0, 0.428, 0.442, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		_animate_orb_enter()
		# Set the launch force from the selected orb size
		match jump_orb_type:
			0: body.jump_orb_velocity = body.jump_velocity / 1.35
			1: body.jump_orb_velocity = body.jump_velocity / 1.1
			2: body.jump_orb_velocity = body.jump_velocity * 1.2
			3: body.can_complete_with_orb = true


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		_animate_orb_exit()
		body.jump_orb_velocity = 0.0
		body.can_complete_with_orb = false

func _animate_orb_enter() -> void:
	if scale_tween and scale_tween.is_running():
		scale_tween.kill()

	scale_tween = create_tween()
	scale_tween.tween_property($orb_center, "scale", Vector2(0.065, 0.065), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property($orb, "scale", Vector2(0.115, 0.115), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_orb_exit() -> void:
	if scale_tween and scale_tween.is_running():
		scale_tween.kill()

	scale_tween = create_tween()
	scale_tween.tween_property($orb, "scale", Vector2(0.094, 0.094), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property($orb_center, "scale", Vector2(0.044, 0.044), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
