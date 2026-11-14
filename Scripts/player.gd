extends CharacterBody2D


const SPEED: float = 1000.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
const JUMP_VELOCITY: float = -600.0
const CHARGED_JUMP_MULT: float = 1.3

@export var gravity: Vector2 = Vector2(0.0, Constants.Gravity.EARTH)

@onready var player_sprite_parent: Node2D = $sprite_parent
@onready var player_sprite: Sprite2D = $sprite_parent/circle_mask

@onready var ball_radius: float = $CollisionShape2D.shape.radius

var crouching: bool = false
var crouching_sprite_scale_y: float = 0.1
var sprite_scale_y: float = 0.159
var crouching_sprite_y_pos: float = 19.0
var crouching_tween: Tween

func _ready() -> void:
	$CanvasLayer/player_ui.player_parent = self # set the ui player reference to this so it can get values to display

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("crouch"): 
		crouching = true
		crouch_anim()
	
	if Input.is_action_just_released("crouch"): 
		crouching = false
		crouch_anim()


func crouch_anim() -> void:
	if not is_on_floor():
		crouching = false
		return
	
	if crouching_tween and crouching_tween.is_running():
		crouching_tween.kill()
	
	crouching_tween = create_tween()
	crouching_tween.tween_property(player_sprite_parent, "scale:y", crouching_sprite_scale_y if crouching else sprite_scale_y, 0.2).set_ease(Tween.EASE_OUT)
	crouching_tween.parallel().tween_property(player_sprite_parent, "position:y", crouching_sprite_y_pos if crouching else 0.0, 0.2).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += gravity * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if crouching:
			velocity.y = JUMP_VELOCITY * CHARGED_JUMP_MULT #if holding crouch and jump do charged
			crouching = false
			crouch_anim()
			return
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, acceleration * delta)
		#if direction > 0.1: player_sprite.flip_h = true
		#else: player_sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
	
	# 4. Smooth Rolling Rotation
	apply_roll_rotation(delta)

func apply_roll_rotation(delta: float) -> void:
	# Angular velocity (radians/sec) = linear velocity / radius
	var angular_velocity: float = velocity.x / ball_radius
	player_sprite.rotation += angular_velocity * delta
