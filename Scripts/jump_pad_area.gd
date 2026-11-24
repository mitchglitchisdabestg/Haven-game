@tool
extends Area2D

@export_enum("Small", "Medium", "Large") var jump_pad_type: int = 0:
	set(value):
		jump_pad_type = value
		_update_texture()

func _ready() -> void:
	_update_texture()
	if not Engine.is_editor_hint():
		$pad_particles.emitting = SettingsManager.is_vfx_enabled("pad_particles")
		SettingsManager.vfx_setting_changed.connect(_on_vfx_setting_changed)

func _update_texture() -> void:
	if not is_node_ready():
		return
		
	match jump_pad_type:
		0:
			$Sprite2D.texture = preload("res://Resources/Prototype/Purple/texture_01.png")
			$pad_particles.modulate = Color(0.65, 0.3, 1.0, 1.0)
		1:
			$Sprite2D.texture = preload("res://Resources/Prototype/Orange/texture_01.png")
			$pad_particles.modulate = Color(1.0, 0.55, 0.16, 1.0)
		2:
			$Sprite2D.texture = preload("res://Resources/Prototype/Red/texture_01.png")
			$pad_particles.modulate = Color(1.0, 0.2, 0.25, 1.0)

func _on_vfx_setting_changed(setting: String, enabled: bool) -> void:
	if setting == "pad_particles":
		$pad_particles.emitting = enabled

func _on_body_entered(body: Node2D) -> void:
	var rot: float = 45.0
	var time: float = 0.3
	if body.has_method("crouch_anim"):
		SFX.play(SFX.Boost, 0.0, &"jump_pad")
		match jump_pad_type:
			0: body.velocity.y = body.jump_velocity / 1.5
			1: 
				body.velocity.y = body.jump_velocity
				rot = 135.0
			2: 
				body.velocity.y = body.jump_velocity * 1.5
				rot = 360.0
				time = 0.7
		
		if not SettingsManager.is_vfx_enabled("jumping_rotation"): return
		var t = create_tween()
		t.tween_property(body.player_sprite_child, "rotation_degrees", body.player_sprite_child.rotation_degrees + rot * body.direction, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
