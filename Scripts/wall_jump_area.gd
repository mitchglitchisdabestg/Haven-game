extends Area2D

const PARTICLE_BURST_SCENE: PackedScene = preload("res://Scenes/Particles/particle_burst.tscn")

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		# Track wall contact and the direction away from it
		body.can_wall_jump = true
		body.is_in_wall_jump_area = true
		body.current_wall_jump_area = self
		var dir = signf(body.global_position.x - global_position.x)
		body.wall_jump_direction = dir
		body.hit_wall_anim(dir)
		if body.wall_jump_direction == 0.0:
			body.wall_jump_direction = 1.0


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		if body.current_wall_jump_area == self:
			body.current_wall_jump_area = null
		body.can_wall_jump = false
		body.is_in_wall_jump_area = false
		body.wall_jump_direction = 0.0
		if body.has_method("stop_wall_particle_emission"):
			body.stop_wall_particle_emission()


func spawn_wall_jump_effect(effect_position: Vector2, jump_direction: float) -> void:
	var effect := PARTICLE_BURST_SCENE.instantiate() as ParticleBurst
	if effect == null:
		push_error("Could not instantiate wall jump particle effect.")
		return

	effect.particle_color = Color(0.77, 0.62, 0.42, 1.0)
	effect.emission_direction = Vector3(jump_direction, -0.2, 0.0)
	effect.particle_amount = 22
	effect.particle_speed_min = 70.0
	effect.particle_speed_max = 220.0
	get_tree().current_scene.add_child(effect)
	effect.global_position = effect_position
