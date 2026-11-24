extends Node2D
class_name ReplayGhost

@onready var player_sprite_parent: Sprite2D = $sprite_parent
@onready var player_sprite_skin: Sprite2D = $sprite_parent/circle_mask/circle_mask_2/proto_player_texture
@onready var player_sprite: Sprite2D = $sprite_parent/circle_mask
@onready var player_sprite_child: Sprite2D = $sprite_parent/circle_mask/circle_mask_2
@onready var player_shadow: Sprite2D = $sprite_parent/shadow
@onready var roll_particles: GPUParticles2D = $sprite_parent/roll_particles_pos/roll_particles
@onready var wall_left_particles: GPUParticles2D = $sprite_parent/wall_left_pos/wall_particles
@onready var wall_right_particles: GPUParticles2D = $sprite_parent/wall_right_pos/wall_particles
@onready var replay_camera: Camera2D = $Camera2D


func _enter_tree() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var wall_right_emitter := get_node_or_null("sprite_parent/wall_right_pos/wall_particles") as GPUParticles2D
	if wall_right_emitter != null:
		wall_right_emitter.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	replay_camera.global_position = global_position
	replay_camera.make_current()


func apply_skin_metadata(skin_metadata: Dictionary) -> void:
	var texture_path: Variant = skin_metadata.get("texture_path", "")
	if typeof(texture_path) != TYPE_STRING or str(texture_path).is_empty():
		push_warning("Replay skin metadata has no texture path; using the default replay ghost skin.")
		return

	var skin_texture := load(str(texture_path)) as Texture2D
	if skin_texture == null:
		push_warning("Replay skin texture could not be loaded; using the default replay ghost skin: %s" % str(texture_path))
		return

	player_sprite_skin.texture = skin_texture
	player_sprite_skin.scale = _vector_from_metadata(skin_metadata, "sprite_scale", player_sprite_skin.scale)
	player_sprite_skin.position = _vector_from_metadata(skin_metadata, "sprite_position", player_sprite_skin.position)
	player_shadow.scale = _vector_from_metadata(skin_metadata, "shadow_scale", player_shadow.scale)
	player_shadow.position = _vector_from_metadata(skin_metadata, "shadow_position", player_shadow.position)


func apply_sample(sample: Dictionary) -> void:
	global_position = _vector_from_sample(sample, "position")
	player_sprite_parent.position = _vector_from_sample(sample, "sprite_parent_position")
	player_sprite_parent.scale = _vector_from_sample(sample, "sprite_parent_scale")
	player_sprite.rotation = float(sample["circle_mask_rotation_radians"])
	player_sprite_child.rotation = float(sample["circle_mask_2_rotation_radians"])
	roll_particles.emitting = bool(sample["rolling_particles_emitting"])
	roll_particles.amount_ratio = float(sample["rolling_particles_amount_ratio"])
	wall_left_particles.emitting = bool(sample["wall_left_particles_emitting"])
	wall_left_particles.amount_ratio = float(sample["wall_left_particles_amount_ratio"])
	wall_right_particles.emitting = bool(sample["wall_right_particles_emitting"])
	wall_right_particles.amount_ratio = float(sample["wall_right_particles_amount_ratio"])


func reset_playback() -> void:
	var particle_emitters: Array[GPUParticles2D] = [
		roll_particles,
		wall_left_particles,
		wall_right_particles
	]
	for emitter in particle_emitters:
		emitter.emitting = false
		emitter.restart()


func apply_interpolated_samples(first: Dictionary, second: Dictionary, weight: float) -> Dictionary:
	var sample := first.duplicate()
	sample["position"] = _interpolate_vector(first["position"], second["position"], weight)
	sample["sprite_parent_position"] = _interpolate_vector(
		first["sprite_parent_position"],
		second["sprite_parent_position"],
		weight
	)
	sample["sprite_parent_scale"] = _interpolate_vector(
		first["sprite_parent_scale"],
		second["sprite_parent_scale"],
		weight
	)
	sample["circle_mask_rotation_radians"] = lerp_angle(
		float(first["circle_mask_rotation_radians"]),
		float(second["circle_mask_rotation_radians"]),
		weight
	)
	sample["circle_mask_2_rotation_radians"] = lerp_angle(
		float(first["circle_mask_2_rotation_radians"]),
		float(second["circle_mask_2_rotation_radians"]),
		weight
	)
	sample["rolling_particles_amount_ratio"] = lerpf(
		float(first["rolling_particles_amount_ratio"]),
		float(second["rolling_particles_amount_ratio"]),
		weight
	)
	sample["wall_left_particles_amount_ratio"] = lerpf(
		float(first["wall_left_particles_amount_ratio"]),
		float(second["wall_left_particles_amount_ratio"]),
		weight
	)
	sample["wall_right_particles_amount_ratio"] = lerpf(
		float(first["wall_right_particles_amount_ratio"]),
		float(second["wall_right_particles_amount_ratio"]),
		weight
	)
	for key in ["health", "max_health", "direction"]:
		if first.has(key) and second.has(key):
			sample[key] = lerpf(float(first[key]), float(second[key]), weight)
	if weight >= 0.5:
		sample["rolling_particles_emitting"] = second["rolling_particles_emitting"]
		sample["wall_left_particles_emitting"] = second["wall_left_particles_emitting"]
		sample["wall_right_particles_emitting"] = second["wall_right_particles_emitting"]
		for key in [
			"crouching",
			"sprinting",
			"can_wall_jump",
			"times_jumped",
			"times_charged_jumped",
			"times_wall_jumped",
			"times_charged_wall_jumped"
		]:
			if second.has(key):
				sample[key] = second[key]
	apply_sample(sample)
	return sample


func _vector_from_sample(sample: Dictionary, key: String) -> Vector2:
	var values: Array = sample[key]
	return Vector2(float(values[0]), float(values[1]))


func _vector_from_metadata(metadata: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = metadata.get(key)
	if typeof(value) != TYPE_ARRAY:
		return fallback

	var values: Array = value
	if values.size() != 2 or not _is_number(values[0]) or not _is_number(values[1]):
		return fallback
	return Vector2(float(values[0]), float(values[1]))


func _interpolate_vector(first: Array, second: Array, weight: float) -> Array[float]:
	return [
		lerpf(float(first[0]), float(second[0]), weight),
		lerpf(float(first[1]), float(second[1]), weight)
	]


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
