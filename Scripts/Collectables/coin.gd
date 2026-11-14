extends Area2D
var coins_collected = 0

	
func _on_body_entered(body: Node2D) -> void:
	print("+1 Coin")
	coins_collected = +1
	print(coins_collected)
	queue_free()
