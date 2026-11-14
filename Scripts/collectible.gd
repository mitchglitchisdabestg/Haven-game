extends Area2D

@export_enum("Coins", "Helium") var collectible_type: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crouch_anim"):
		match collectible_type:
			0: body.coins +=1
			1: body.apply_helium()
		queue_free()
