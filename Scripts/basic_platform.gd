@tool
extends StaticBody2D

const SPRITE_BASE_SIZE := 1024.0

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var size_x: int = 64:
	set(value):
		size_x = maxi(value, 0)
		_update_shapes()

@export var size_y: int = 64:
	set(value):
		size_y = maxi(value, 1) # Kept at min 1 so wall_jump_area (size_y - 1) never goes negative
		_update_shapes()

func _ready() -> void:
	var main_col: CollisionShape2D = $CollisionShape2D
	var wall_col: CollisionShape2D = $wall_jump_area/CollisionShape2D
	
	# Give this instance its own unique copy of each shape resource
	if main_col and main_col.shape:
		main_col.shape = main_col.shape.duplicate()
	if wall_col and wall_col.shape:
		wall_col.shape = wall_col.shape.duplicate()
		
	_update_shapes()


func _update_shapes() -> void:
	if not is_node_ready():
		return
	
	var main_col: CollisionShape2D = $CollisionShape2D
	var wall_col: CollisionShape2D = $wall_jump_area/CollisionShape2D
	
	if main_col and main_col.shape:
		main_col.shape.size.x = size_x
		main_col.shape.size.y = size_y
	
	if wall_col and wall_col.shape:
		wall_col.shape.size.x = size_x + 15.0
		wall_col.shape.size.y = maxf(size_y - 1.0, 0.0)
		wall_col.position.y = main_col.position.y
	
	if sprite_2d:
		sprite_2d.scale = Vector2(size_x / SPRITE_BASE_SIZE, size_y / SPRITE_BASE_SIZE)
		sprite_2d.position = main_col.position
