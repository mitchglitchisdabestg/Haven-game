extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		body.can_wall_jump = true


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		body.can_wall_jump = false
