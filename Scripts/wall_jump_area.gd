extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		# Track wall contact and the direction away from it
		body.can_wall_jump = true
		body.is_in_wall_jump_area = true
		body.wall_jump_direction = signf(body.global_position.x - global_position.x)
		if body.wall_jump_direction == 0.0:
			body.wall_jump_direction = 1.0


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		body.can_wall_jump = false
		body.is_in_wall_jump_area = false
		body.wall_jump_direction = 0.0
