@tool
extends Area2D

# Drag your 4 textures into this array in the Inspector (in the same order as the enum)
@export var textures: Array[Texture2D] = [
	preload("res://Resources/misc/cover_mask.png"),
	preload("res://Resources/Prototype/Light/texture_02.png"),
	preload("res://Resources/Prototype/Green/texture_02.png"),
	preload("res://Resources/Prototype/Green/texture_13.png")
]

@export_enum("Coins", "Helium", "Health Potion", "Health Barrel") var collectible_type: int = 0:
	set(value):
		collectible_type = value
		_update_sprite()

var collected: bool = false


func _ready() -> void:
	# Ensures the correct texture is loaded when the scene opens or runs
	_update_sprite()


func _update_sprite() -> void:
	# Guard against the setter running before child nodes ($Sprite2D) are ready
	if not is_node_ready():
		return
		
	if collectible_type >= 0 and collectible_type < textures.size():
		$Sprite2D.texture = textures[collectible_type]


func _on_body_entered(body: Node2D) -> void:
	# Prevent @tool from running gameplay collision logic inside the editor
	if Engine.is_editor_hint():
		return

	if collected or not body.has_method("collect"):
		return

	# Apply one collectible effect and remove the item
	body.call("collect", collectible_type)
	collected = true
	queue_free()
