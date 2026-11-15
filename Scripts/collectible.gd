extends Area2D

@export_enum("Coins", "Helium", "Health Potion", "Health Barrel") var collectible_type: int = 0

var collected: bool = false


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.has_method("collect"):
		return

	# Apply one collectible effect and remove the item
	body.call("collect", collectible_type)
	collected = true
	queue_free()
