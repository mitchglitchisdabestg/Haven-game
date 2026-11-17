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
const FALLING_ROLL_ROTATION_SPEED := 1.0

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
		hp = clampf(value, 0.0, 100.0)

var can_complete_with_orb: bool = false

var is_dead: bool = false

func _ready() -> void:
	$CanvasLayer/player_ui.player_parent = self # set the ui player reference to this so it can get values to display
	
	var selected_skin: SkinResource = Constants.get_selected_skin_resource()
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

func _process(delta: float) -> void:
	# Heal over time and expire helium
	hp += 1.5 * delta
	helium_time_remaining = maxf(helium_time_remaining - delta, 0.0)
	if hp <= 0.0:
		die()
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
	
	crouching_tween = create_tween()
	crouching_tween.tween_property(player_sprite_parent, "scale:y", crouching_sprite_scale_y if crouching else sprite_scale_y, 0.2).set_ease(Tween.EASE_OUT)
	crouching_tween.parallel().tween_property(player_sprite_parent, "position:y", crouching_sprite_y_pos if crouching else 0.0, 0.2).set_ease(Tween.EASE_OUT)

func hit_wall_anim(dir: float = 1.0) -> void:
	hit_wall_tween = create_tween()
	
	hit_wall_tween.tween_property(player_sprite_parent, "scale:x", 0.135, 0.04).set_ease(Tween.EASE_OUT)
	hit_wall_tween.parallel().tween_property(player_sprite_parent, "position:x", -13.0 * dir, 0.04).set_ease(Tween.EASE_OUT)
	
	hit_wall_tween.tween_property(player_sprite_parent, "scale:x", sprite_scale_y, 0.1).set_ease(Tween.EASE_IN)
	hit_wall_tween.parallel().tween_property(player_sprite_parent, "position:x", 0.0, 0.04).set_ease(Tween.EASE_OUT)

func hit_floor_anim(impact_velocity_y: float) -> void:
	impact_strength = clampf(impact_velocity_y / MAX_LANDING_IMPACT_SPEED, 0.0, 1.0)
	target_scale_y = crouching_sprite_scale_y if crouching else sprite_scale_y
	target_position_y = crouching_sprite_y_pos if crouching else 0.0
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
	hit_floor_tween.tween_property(player_sprite_parent, "scale:y", target_scale_y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	hit_floor_tween.parallel().tween_property(player_sprite_parent, "position:y", target_position_y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)


var deteriorate_amount_mult: float = 1.0

func _physics_process(delta: float) -> void:
	
	var crouch_wall_jump := false
	var was_on_floor := is_on_floor()

	# Buffer jump presses until player reaches a surface or releases the keybind
	if Input.is_action_just_pressed("jump"):
		if can_complete_with_orb: 
			complete()
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
		
		jump_buffered = false
		jump_buffer_used = Input.is_action_pressed("jump")
		if jump_orb_velocity != 0.0:
			_record_jump()
			velocity.y = jump_orb_velocity
			crouching = false
			if is_on_floor():
				crouch_anim()
		elif can_wall_jump and crouching:
			_record_jump(true, true)
			# Launch away from the wall with a stronger jump
			velocity.y = jump_velocity * CHARGED_JUMP_MULT
			velocity.x = wall_jump_direction * speed
			crouching = false
			crouch_anim()
			crouch_wall_jump = true
		elif crouching:
			_record_jump(true)
			velocity.y = jump_velocity * CHARGED_JUMP_MULT #if holding crouch and jump do charged
			crouching = false
			crouch_anim()
			return
		else:
			_record_jump(false, can_wall_jump)
			velocity.y = jump_velocity
		can_wall_jump = false
		
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
	move_and_slide()
	if sprinting_on_ground:
		pixels_ran_while_sprinting += absf(global_position.x - sprint_start_x)

	_activate_crouch_buffer()
	if crouching and not (is_on_floor() or can_wall_jump):
		crouching = false
		crouch_anim()
	if not was_on_floor and is_on_floor() and impact_velocity_y > 0.0:
		hit_floor_anim(impact_velocity_y)
		_apply_fall_damage(impact_velocity_y)
		if is_dead:
			return

	# Apply wear based on movement and nearby surfaces
	if is_in_wall_jump_area:
		deteriorate_amount_mult = 0.5
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
			die()
	
	

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


func _apply_fall_damage(impact_velocity_y: float) -> void:
	if impact_velocity_y <= FALL_DAMAGE_THRESHOLD or max_vertical_velocity_y <= FALL_DAMAGE_THRESHOLD:
		return

	var damage_fraction := clampf(
		(impact_velocity_y - FALL_DAMAGE_THRESHOLD) / (max_vertical_velocity_y - FALL_DAMAGE_THRESHOLD),
		0.0,
		1.0
	)
	hp -= MAX_FALL_DAMAGE * damage_fraction
	if hp <= 0.0:
		die()


func apply_roll_rotation(delta: float) -> void:
	# Angular velocity (radians/sec) = linear velocity / radius
	var angular_velocity: float = velocity.x / ball_radius
	if not is_on_floor() and velocity.y > 0.0:
		var horizontal_speed_ratio := clampf(absf(velocity.x) / max_speed, 0.0, 1.0)
		angular_velocity += signf(velocity.x) * FALLING_ROLL_ROTATION_SPEED * horizontal_speed_ratio
	player_sprite.rotation += angular_velocity * delta

func collect(collectible_type: int) -> void:
	# Apply collectible effects and record run totals
	var collectible_name: String
	match collectible_type:
		0:
			coins += 1
			Constants.total_coins += 1
			collectible_name = "Coins"
		1:
			helium_time_remaining = helium_duration
			collectible_name = "Helium"
		2:
			hp += Constants.health_potion_amount
			collectible_name = "Health Potion"
		3:
			hp = 100.0
			collectible_name = "Health Barrel"
		_:
			return

	collectible_stats[collectible_name] = collectible_stats.get(collectible_name, 0) + 1
	Constants.record_level_stats(Constants.current_level, collectible_stats, false)

func die() -> void:
	if is_dead:
		return

	# Stop play and show the collected run totals
	is_dead = true
	set_process(false)
	set_physics_process(false)
	Constants.deaths += 1
	Constants.record_level_stats(Constants.current_level, collectible_stats, false, 1)
	$CanvasLayer/death_ui.show_death_screen(collectible_stats)

func complete() -> void:
	print("completing %s" % str(can_complete_with_orb))
	if is_dead or not can_complete_with_orb: return

	Constants.record_level_stats(Constants.current_level, collectible_stats, true)
	
	set_process(false)
	set_physics_process(false)
	
	$CanvasLayer/complete.show()
	$CanvasLayer/complete/stats.text = "Stats:
	Coins: %d | Helium cans collected: %d | Deaths: %d" % [collectible_stats["Coins"], collectible_stats["Helium"], Constants.deaths]

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/main_menu.tscn")

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_back_to_lvl_select_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main menu/LevelSelect.tscn")
