extends CharacterBody2D


var speed: float = 650.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
var jump_velocity: float = -745.0
const CHARGED_JUMP_MULT: float = 1.3
var direction: float
@export var fall_gravity_multiplier: float = 1.8
@export var jump_release_gravity_multiplier: float = 1.8
var sprint_speed_mult: float = 1.02
var max_speed: float = 1800.0
var min_speed: float = 650.0

@onready var roll_particles: GPUParticles2D = $sprite_parent/roll_particles_pos/roll_particles
@onready var wall_right_particles: GPUParticles2D = $sprite_parent/wall_right_pos/wall_particles
@onready var wall_left_particles: GPUParticles2D = $sprite_parent/wall_left_pos/wall_particles
const PARTICLE_BURST_SCENE: PackedScene = preload("res://Scenes/Particles/particle_burst.tscn")

var dash_speed: float = 1000
var dash_direction:float
var is_dashing:bool
var dash_duration: float = 100
var dash_timer:float
var dash_cooldown:bool
var dash_cooldown_timer:float = 3

@export var gravity: Vector2 = Vector2(0.0, Constants.Gravity.EARTH)
@export var max_vertical_velocity_y: float = 5000.0

const FALL_DAMAGE_THRESHOLD := 1800.0
const MAX_FALL_DAMAGE := 65.0
const FATAL_FALL_SPEED := 4000.0
const FALLING_ROLL_ROTATION_SPEED := 1.0
const MAX_HEALTH: float = 100.0
const REPLAY_SAVE_PROMPT_SCENE: PackedScene = preload("res://Scenes/replay_save_prompt.tscn")

@onready var player_sprite_parent: Node2D = $sprite_parent
@onready var player_sprite: Sprite2D = $sprite_parent/circle_mask
@onready var player_sprite_skin: Sprite2D = $sprite_parent/circle_mask/circle_mask_2/proto_player_texture
@onready var player_sprite_child: Sprite2D = $sprite_parent/circle_mask/circle_mask_2

@onready var ball_radius: float = $CollisionShape2D.shape.radius

var sprinting: bool = false
var times_jumped: int = 0
var times_charged_jumped: int = 0
var times_wall_jumped: int = 0
var times_charged_wall_jumped: int = 0
var pixels_ran_while_sprinting: float = 0.0

var crouching: bool = false
var crouching_sprite_scale_y: float = 0.1
var sprite_scale_y: float = 0.159
var crouching_sprite_y_pos: float = 19.0
var crouching_tween: Tween
var crouch_buffered: bool = false
var jump_buffered: bool = false
var crouch_buffer_used: bool = false
var jump_buffer_used: bool = false

var hit_wall_tween: Tween

var hit_floor_tween: Tween
const MAX_LANDING_IMPACT_SPEED := 1500.0
const LANDING_SQUASH_SCALE_FACTOR := 0.75
var impact_strength: float = 0.0
var target_scale_y: float = 0.0
var target_position_y: float = 0.0
var squashed_scale_y: float = 0.0
var squashed_position_y: float = 0.0

var can_wall_jump: bool = false
var is_in_wall_jump_area: bool = false
var wall_jump_direction: float = 0.0
var current_wall_jump_area: Area2D
var jump_orb_velocity: float = 0.0

# Track coins helium and run totals
var coins: int = 0
var collectible_stats: Dictionary = {
	"Coins": 0,
	"Helium": 0
}
var helium_time_remaining: float = 0.0

const helium_duration: float = 2.0
const HELIUM_GRAVITY_MULTIPLIER: float = 0.1

# Keep player health within its range
var hp: float = 100.0:
	set(value):
		hp = clampf(value, 0.0, MAX_HEALTH)

var can_complete_with_orb: bool = false

var is_dead: bool = false
var _end_flow_started: bool = false
var _replay_save_prompt: ReplaySavePrompt

func _ready() -> void:
	if ReplayManager.is_playback_active():
		return

	$CanvasLayer/player_ui.player_parent = self # set the ui player reference to this so it can get values to display
	SettingsManager.vfx_setting_changed.connect(_on_vfx_setting_changed)
	roll_particles.emitting = false
	wall_right_particles.emitting = false
	wall_left_particles.emitting = false
	
	var selected_skin: SkinResource = Constants.get_selected_skin_resource()
	var skin_metadata: Dictionary = {"index": Constants.selected_skin}
	if selected_skin != null:
		skin_metadata["name"] = selected_skin.skin_name
		skin_metadata["texture_path"] = selected_skin.texture_path
		skin_metadata["sprite_scale"] = [selected_skin.sprite_scale.x, selected_skin.sprite_scale.y]
		skin_metadata["sprite_position"] = [selected_skin.sprite_position.x, selected_skin.sprite_position.y]
		skin_metadata["shadow_scale"] = [selected_skin.shadow_scale.x, selected_skin.shadow_scale.y]
		skin_metadata["shadow_position"] = [selected_skin.shadow_position.x, selected_skin.shadow_position.y]
	ReplayManager.start_recording(Constants.current_level, skin_metadata)
	if selected_skin == null:
		return

	var skin_texture := load(selected_skin.texture_path) as Texture2D
	if skin_texture == null:
		push_error("Could not load skin texture: %s" % selected_skin.texture_path)
		return

	player_sprite_skin.texture = skin_texture
	player_sprite_skin.scale = selected_skin.sprite_scale
	player_sprite_skin.position = selected_skin.sprite_position
	$sprite_parent/shadow.scale = selected_skin.shadow_scale
	$sprite_parent/shadow.position = selected_skin.shadow_position


func _exit_tree() -> void:
	ReplayManager.finalize_recording(
		ReplayManager.OUTCOME_ABANDONED,
		_get_replay_state(),
		Engine.get_physics_frames()
	)


func _process(delta: float) -> void:
	# Heal over time and expire helium
	hp += 1.5 * delta
	helium_time_remaining = maxf(helium_time_remaining - delta, 0.0)
	if hp <= 0.0:
		die(delta)
		return
	
	if Input.is_action_just_pressed("crouch"):
		crouch_buffered = true
	
	if Input.is_action_just_released("crouch"):
		crouch_buffered = false
		crouch_buffer_used = false
		if crouching:
			crouching = false
			crouch_anim()

	if Input.is_action_just_released("jump"):
		jump_buffered = false
		jump_buffer_used = false
	
	if Input.is_action_just_pressed("sprint"): 
		sprinting = true
		#crouch_anim()
	
	if Input.is_action_just_released("sprint"): 
		sprinting = false
		#crouch_anim()
	


func crouch_anim() -> void:
	if crouching and not (is_on_floor() or can_wall_jump):
		crouching = false
	
	if crouching_tween and crouching_tween.is_running():
		crouching_tween.kill()

	if not SettingsManager.is_vfx_enabled("crouch_squish"):
		player_sprite_parent.scale.y = sprite_scale_y
		player_sprite_parent.position.y = 0.0
		return
	
	crouching_tween = create_tween()
	crouching_tween.tween_property(player_sprite_parent, "scale:y", crouching_sprite_scale_y if crouching else sprite_scale_y, 0.2).set_ease(Tween.EASE_OUT)
	crouching_tween.parallel().tween_property(player_sprite_parent, "position:y", crouching_sprite_y_pos if crouching else 0.0, 0.2).set_ease(Tween.EASE_OUT)

func hit_wall_anim(dir: float = 1.0) -> void:
	if not SettingsManager.is_vfx_enabled("wall_squish"):
		return

	hit_wall_tween = create_tween()
	
	hit_wall_tween.tween_property(player_sprite_parent, "scale:x", 0.135, 0.04).set_ease(Tween.EASE_OUT)
	hit_wall_tween.parallel().tween_property(player_sprite_parent, "position:x", -13.0 * dir, 0.04).set_ease(Tween.EASE_OUT)
	
	hit_wall_tween.tween_property(player_sprite_parent, "scale:x", sprite_scale_y, 0.1).set_ease(Tween.EASE_IN)
	hit_wall_tween.parallel().tween_property(player_sprite_parent, "position:x", 0.0, 0.04).set_ease(Tween.EASE_OUT)

func hit_floor_anim(impact_velocity_y: float, restore_after_squash: bool = true) -> void:
	if not SettingsManager.is_vfx_enabled("land_squish"):
		return

	impact_strength = clampf(impact_velocity_y / MAX_LANDING_IMPACT_SPEED, 0.0, 1.0)
	var visually_crouching := crouching and SettingsManager.is_vfx_enabled("crouch_squish")
	target_scale_y = crouching_sprite_scale_y if visually_crouching else sprite_scale_y
	target_position_y = crouching_sprite_y_pos if visually_crouching else 0.0
	squashed_scale_y = lerpf(target_scale_y, target_scale_y * LANDING_SQUASH_SCALE_FACTOR, impact_strength)
	var sprite_radius_at_normal_scale := ball_radius / sprite_scale_y
	squashed_position_y = target_position_y + sprite_radius_at_normal_scale * (target_scale_y - squashed_scale_y)

	if hit_floor_tween and hit_floor_tween.is_running():
		hit_floor_tween.kill()
	if crouching_tween and crouching_tween.is_running():
		crouching_tween.kill()

	hit_floor_tween = create_tween()
	hit_floor_tween.tween_property(player_sprite_parent, "scale:y", squashed_scale_y, 0.03).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hit_floor_tween.parallel().tween_property(player_sprite_parent, "position:y", squashed_position_y, 0.03).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if restore_after_squash:
		hit_floor_tween.tween_property(player_sprite_parent, "scale:y", target_scale_y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		hit_floor_tween.parallel().tween_property(player_sprite_parent, "position:y", target_position_y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)


var deteriorate_amount_mult: float = 1.0

func _physics_process(delta: float) -> void:
	
	var crouch_wall_jump := false
	var was_on_floor := is_on_floor()

	# Buffer jump presses until player reaches a surface or releases the keybind
	if Input.is_action_just_pressed("jump"):
		if can_complete_with_orb: 
			complete(delta)
			return
		jump_buffered = true
	# Activate buffered crouching when player reaches a surface
	_activate_crouch_buffer()

	# Add the gravity.
	var current_gravity = gravity
	if helium_time_remaining > 0.0:
		current_gravity *= HELIUM_GRAVITY_MULTIPLIER
	if velocity.y < 0 and not Input.is_action_pressed("jump"):
		current_gravity *= jump_release_gravity_multiplier
	elif velocity.y > 0:
		current_gravity *= fall_gravity_multiplier
		
	velocity.y += current_gravity.y * delta
	
	# Handle jump.
	if jump_buffered and (jump_orb_velocity != 0.0 or is_on_floor() or can_wall_jump):
		roll_particles.emitting = false
		jump_buffered = false
		jump_buffer_used = Input.is_action_pressed("jump")
		if jump_orb_velocity != 0.0:
			_record_jump()
			SFX.play(SFX.Jump, SFX.DEFAULT_SFX_PITCH, &"player_jump")
			velocity.y = jump_orb_velocity
			crouching = false
			if is_on_floor():
				crouch_anim()
		elif can_wall_jump and crouching:
			_record_jump(true, true)
			SFX.play(SFX.ChargedWallJump, SFX.DEFAULT_SFX_PITCH, &"player_charged_wall_jump")
			_spawn_wall_jump_burst()
			# Launch away from the wall with a stronger jump
			velocity.y = jump_velocity * CHARGED_JUMP_MULT
			velocity.x = wall_jump_direction * speed * 1.175
			crouching = false
			crouch_anim()
			crouch_wall_jump = true
		elif crouching:
			_record_jump(true)
			SFX.play(SFX.ChargedJump, SFX.DEFAULT_SFX_PITCH, &"player_charged_jump")
			_spawn_surface_jump_burst(true)
			velocity.y = jump_velocity * CHARGED_JUMP_MULT #if holding crouch and jump do charged
			crouching = false
			crouch_anim()
			_record_replay_state(delta)
			return
		else:
			_record_jump(false, can_wall_jump)
			if can_wall_jump:
				SFX.play(SFX.WallJump, SFX.DEFAULT_SFX_PITCH, &"player_wall_jump")
				_spawn_wall_jump_burst()
			else:
				SFX.play(SFX.Jump, SFX.DEFAULT_SFX_PITCH, &"player_jump")
				_spawn_surface_jump_burst(false)
			velocity.y = jump_velocity
		can_wall_jump = false
		
		if SettingsManager.is_vfx_enabled("jumping_rotation"):
			var t = create_tween()
			t.tween_property(player_sprite_child, "rotation_degrees", player_sprite_child.rotation_degrees + 90.0 * direction, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = Input.get_axis("left", "right")
	# Slow down crouching movement on a floor
	var movement_speed := speed * 0.7 if crouching and is_on_floor() else speed
	if crouch_wall_jump:
		pass
	elif direction:
		velocity.x = move_toward(velocity.x, direction * movement_speed, acceleration * delta)
		roll_particles.process_material.direction = Vector3(-direction, 0.0, 0.0)
		#if direction > 0.1: player_sprite.flip_h = true
		#else: player_sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	if sprinting and is_on_floor():
		speed = clampf(speed * sprint_speed_mult, min_speed, max_speed)
		jump_velocity = -clampf(speed * sprint_speed_mult, min_speed, max_speed) * 0.3
	else:
		speed = min_speed
		jump_velocity = -745.0
	
	velocity.y = minf(velocity.y, max_vertical_velocity_y)
	var sprint_start_x := global_position.x
	var sprinting_on_ground := sprinting and is_on_floor()
	var impact_velocity_y := velocity.y
	var landing_jump_buffered := jump_buffered
	var landing_crouch_buffered := crouch_buffered
	var position_before_move := global_position
	move_and_slide()
	var movement_distance := global_position.distance_to(position_before_move)
	_update_roll_particles()
	_update_wall_particles(movement_distance)
	if sprinting_on_ground:
		pixels_ran_while_sprinting += absf(global_position.x - sprint_start_x)

	_activate_crouch_buffer()
	if crouching and not (is_on_floor() or can_wall_jump):
		crouching = false
		crouch_anim()
	if not was_on_floor and is_on_floor() and impact_velocity_y > 0.0:
		if not landing_jump_buffered:
			hit_floor_anim(impact_velocity_y, not landing_crouch_buffered)
		var damage_dealt := _apply_fall_damage(impact_velocity_y, delta)
		if damage_dealt > 0.0:
			var flash_strength := clampf(
				(impact_velocity_y - FALL_DAMAGE_THRESHOLD) / (FATAL_FALL_SPEED - FALL_DAMAGE_THRESHOLD),
				0.0,
				1.0
			)
			$CanvasLayer/player_ui.show_fall_damage_flash(impact_velocity_y, damage_dealt, flash_strength)
		if damage_dealt > 45.0:
			SFX.play(SFX.LandCritical, 0.0, &"player_land_critical")
		elif damage_dealt > 20.0:
			SFX.play(SFX.LandDamaging, 0.0, &"player_land_damaging")
		else:
			SFX.play(SFX.Land, SFX.DEFAULT_SFX_PITCH, &"player_land")
		if is_dead:
			return

	# Apply wear based on movement and nearby surfaces
	if is_in_wall_jump_area:
		deteriorate_amount_mult = 0.5 if movement_distance > 0.1 else 0.0
	elif is_zero_approx(direction):
		deteriorate_amount_mult = 0.0
	elif is_on_floor():
		if sprinting and crouching:
			deteriorate_amount_mult = 1.4
		elif sprinting:
			deteriorate_amount_mult = 1.5
		elif crouching:
			deteriorate_amount_mult = 0.9
		else:
			deteriorate_amount_mult = 1.0
	else:
		deteriorate_amount_mult = 0.0
	
	# 4. Smooth Rolling Rotation
	apply_roll_rotation(delta)
	
	if deteriorate_amount_mult > 0.0:
		hp -= (10.0 * delta) * deteriorate_amount_mult
		if hp <= 0.0:
			die(delta)

	_record_replay_state(delta)


func _record_replay_state(simulation_delta: float = 0.0) -> void:
	ReplayManager.record_sample(_get_replay_state(), Engine.get_physics_frames(), simulation_delta)


func _get_replay_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"velocity": [velocity.x, velocity.y],
		"sprite_parent_position": [player_sprite_parent.position.x, player_sprite_parent.position.y],
		"sprite_parent_scale": [player_sprite_parent.scale.x, player_sprite_parent.scale.y],
		"circle_mask_rotation_radians": player_sprite.rotation,
		"circle_mask_2_rotation_radians": player_sprite_child.rotation,
		"rolling_particles_emitting": roll_particles.emitting,
		"rolling_particles_amount_ratio": roll_particles.amount_ratio,
		"wall_left_particles_emitting": wall_left_particles.emitting,
		"wall_left_particles_amount_ratio": wall_left_particles.amount_ratio,
		"wall_right_particles_emitting": wall_right_particles.emitting,
		"wall_right_particles_amount_ratio": wall_right_particles.amount_ratio,
		"health": hp,
		"max_health": MAX_HEALTH,
		"direction": direction,
		"crouching": crouching,
		"sprinting": sprinting,
		"can_wall_jump": can_wall_jump,
		"times_jumped": times_jumped,
		"times_charged_jumped": times_charged_jumped,
		"times_wall_jumped": times_wall_jumped,
		"times_charged_wall_jumped": times_charged_wall_jumped,
		"simulation_gravity": [gravity.x, gravity.y]
	}
	

func _update_roll_particles() -> void:
	if not SettingsManager.is_vfx_enabled("rolling_particles"):
		roll_particles.emitting = false
		return

	var particle_count := 16.0
	if sprinting and crouching:
		particle_count = 20.0
	elif sprinting:
		particle_count = 24.0
	elif crouching:
		particle_count = 12.0

	roll_particles.amount_ratio = particle_count / float(roll_particles.amount)
	roll_particles.emitting = is_on_floor() and absf(velocity.x) > 5.0


func stop_wall_particle_emission() -> void:
	wall_left_particles.emitting = false
	wall_right_particles.emitting = false


func _update_wall_particles(movement_distance: float) -> void:
	var should_emit := (
		SettingsManager.is_vfx_enabled("wall_rolling_particles")
		and is_in_wall_jump_area
		and movement_distance > 0.1
	)
	wall_left_particles.emitting = should_emit and wall_jump_direction > 0.0
	wall_right_particles.emitting = should_emit and wall_jump_direction < 0.0


func _spawn_surface_jump_burst(charged: bool) -> void:
	if not SettingsManager.is_vfx_enabled("jump_burst"):
		return

	var effect := PARTICLE_BURST_SCENE.instantiate() as ParticleBurst
	if effect == null:
		push_error("Could not instantiate surface jump particle effect.")
		return

	effect.particle_color = Color(0.7, 0.9, 1.0, 1.0) if not charged else Color(1.0, 0.83, 0.42, 1.0)
	effect.emission_direction = Vector3(0.0, -1.0, 0.0)
	effect.particle_amount = 18 if not charged else 28
	effect.particle_speed_min = 90.0 if not charged else 140.0
	effect.particle_speed_max = 190.0 if not charged else 280.0
	var effect_position: Vector2 = $sprite_parent/roll_particles_pos.global_position
	get_tree().current_scene.add_child(effect)
	effect.global_position = effect_position


func _spawn_wall_jump_burst() -> void:
	if not SettingsManager.is_vfx_enabled("wall_jump_burst"):
		return
	if not is_instance_valid(current_wall_jump_area):
		return

	var effect_position := global_position - Vector2(wall_jump_direction * ball_radius, 0.0)
	current_wall_jump_area.call("spawn_wall_jump_effect", effect_position, wall_jump_direction)


func _activate_crouch_buffer() -> void:
	if not crouch_buffered or not (is_on_floor() or can_wall_jump):
		return

	# Consume one crouch press on contact
	crouch_buffered = false
	crouching = true
	crouch_buffer_used = Input.is_action_pressed("crouch")
	crouch_anim()



func _record_jump(charged: bool = false, wall: bool = false) -> void:
	times_jumped += 1
	if charged:
		times_charged_jumped += 1
	if wall:
		times_wall_jumped += 1
	if charged and wall:
		times_charged_wall_jumped += 1


func _apply_fall_damage(impact_velocity_y: float, simulation_delta: float = 0.0) -> float:
	var damage_amount: float
	if impact_velocity_y >= FATAL_FALL_SPEED:
		damage_amount = 100.0
	elif impact_velocity_y > FALL_DAMAGE_THRESHOLD and max_vertical_velocity_y > FALL_DAMAGE_THRESHOLD:
		var damage_fraction := clampf(
			(impact_velocity_y - FALL_DAMAGE_THRESHOLD) / (max_vertical_velocity_y - FALL_DAMAGE_THRESHOLD),
			0.0,
			1.0
		)
		damage_amount = MAX_FALL_DAMAGE * damage_fraction
	else:
		return 0.0

	var damage_dealt := minf(hp, damage_amount)
	hp -= damage_dealt
	if hp <= 0.0:
		die(simulation_delta)
	return damage_dealt


func apply_roll_rotation(delta: float) -> void:
	if not SettingsManager.is_vfx_enabled("movement_rotation"):
		return

	# Angular velocity (radians/sec) = linear velocity / radius
	var angular_velocity: float = velocity.x / ball_radius
	if not is_on_floor() and velocity.y > 0.0:
		var horizontal_speed_ratio := clampf(absf(velocity.x) / max_speed, 0.0, 1.0)
		angular_velocity += signf(velocity.x) * FALLING_ROLL_ROTATION_SPEED * horizontal_speed_ratio
	player_sprite.rotation += angular_velocity * delta


func _on_vfx_setting_changed(setting: String, enabled: bool) -> void:
	if setting == "rolling_particles" and not enabled:
		roll_particles.emitting = false
	elif setting == "wall_rolling_particles" and not enabled:
		stop_wall_particle_emission()
	elif setting == "crouch_squish" and not enabled:
		if crouching_tween and crouching_tween.is_running():
			crouching_tween.kill()
		player_sprite_parent.scale.y = sprite_scale_y
		player_sprite_parent.position.y = 0.0
	elif setting == "wall_squish" and not enabled:
		if hit_wall_tween and hit_wall_tween.is_running():
			hit_wall_tween.kill()
		player_sprite_parent.scale.x = sprite_scale_y
		player_sprite_parent.position.x = 0.0
	elif setting == "land_squish" and not enabled:
		if hit_floor_tween and hit_floor_tween.is_running():
			hit_floor_tween.kill()
		var visually_crouching := crouching and SettingsManager.is_vfx_enabled("crouch_squish")
		var restore_scale_y := crouching_sprite_scale_y if visually_crouching else sprite_scale_y
		var restore_position_y := crouching_sprite_y_pos if visually_crouching else 0.0
		player_sprite_parent.scale.y = restore_scale_y
		player_sprite_parent.position.y = restore_position_y

func collect(collectible_type: int, debug: bool = false) -> void:
	# Apply collectible effects and record run totals
	var collectible_name: String
	match collectible_type:
		0:
			SFX.play(SFX.Coin, 0.25, &"player_coin")
			if not debug:
				coins += 1
				Constants.total_coins += 1
			collectible_name = "Coins"
		1:
			SFX.play(SFX.Boost, 0.0, &"player_boost")
			helium_time_remaining = helium_duration
			collectible_name = "Helium"
		2:
			SFX.play(SFX.HealthGain, 0.0, &"player_health_gain")
			hp += Constants.health_potion_amount
			collectible_name = "Health Potion"
		3:
			SFX.play(SFX.HealthGain, 0.0, &"player_health_gain")
			hp = 100.0
			collectible_name = "Health Barrel"
		_:
			return

	if not debug:
		collectible_stats[collectible_name] = collectible_stats.get(collectible_name, 0) + 1
		Constants.record_level_stats(Constants.current_level, collectible_stats, false)

func die(simulation_delta: float = 0.0) -> void:
	if is_dead:
		return

	# Stop play and show the collected run totals
	is_dead = true
	ReplayManager.finalize_recording(
		ReplayManager.OUTCOME_FAILED,
		_get_replay_state(),
		Engine.get_physics_frames(),
		simulation_delta
	)
	set_process(false)
	set_physics_process(false)
	Constants.deaths += 1
	Constants.record_level_stats(Constants.current_level, collectible_stats, false, 1)
	_begin_end_flow()

func complete(simulation_delta: float = 0.0) -> void:
	print("completing %s" % str(can_complete_with_orb))
	if is_dead or not can_complete_with_orb: return

	ReplayManager.finalize_recording(
		ReplayManager.OUTCOME_COMPLETED,
		_get_replay_state(),
		Engine.get_physics_frames(),
		simulation_delta
	)
	Constants.record_level_stats(Constants.current_level, collectible_stats, true)
	
	set_process(false)
	set_physics_process(false)
	_begin_end_flow()


func _begin_end_flow() -> void:
	if _end_flow_started:
		return
	_end_flow_started = true
	if not ReplayManager.has_pending_recording():
		_show_normal_end_screen()
		return

	_replay_save_prompt = REPLAY_SAVE_PROMPT_SCENE.instantiate() as ReplaySavePrompt
	if _replay_save_prompt == null:
		push_error("Could not instantiate the replay save prompt.")
		_show_normal_end_screen()
		return
	$CanvasLayer.add_child(_replay_save_prompt)
	_replay_save_prompt.save_confirmed.connect(_on_replay_save_confirmed)
	_replay_save_prompt.discard_requested.connect(_on_replay_discard_requested)


func _on_replay_save_confirmed(replay_name: String) -> void:
	var save_error := ReplayManager.save_pending_recording(replay_name)
	if save_error != OK:
		_replay_save_prompt.show_save_error(error_string(save_error))
		return
	_replay_save_prompt.queue_free()
	_replay_save_prompt = null
	_show_normal_end_screen()


func _on_replay_discard_requested() -> void:
	ReplayManager.discard_pending_recording()
	_replay_save_prompt.queue_free()
	_replay_save_prompt = null
	_show_normal_end_screen()


func _show_normal_end_screen() -> void:
	if is_dead:
		$CanvasLayer/death_ui.show_death_screen(collectible_stats)
		return

	$CanvasLayer/complete.show()
	$CanvasLayer/complete/stats.text = "Stats:
	Coins: %d | Helium cans collected: %d | Deaths: %d" % [
		collectible_stats["Coins"],
		collectible_stats["Helium"],
		Constants.deaths
	]

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_back_to_lvl_select_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")
