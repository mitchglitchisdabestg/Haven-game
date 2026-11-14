extends StaticBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$wall_jump_area/CollisionShape2D.shape.size.x = $CollisionShape2D.shape.size.x + 15.0
