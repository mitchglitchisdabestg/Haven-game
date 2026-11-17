extends Node

const Tap1: AudioStream = preload("res://Resources/Sound/SFX/tap1.wav")
const Jump: AudioStream = preload("res://Resources/Sound/SFX/jump1.wav")
const ChargedJump: AudioStream = preload("res://Resources/Sound/SFX/jump1.wav")
const WallJump: AudioStream = preload("res://Resources/Sound/SFX/retroroll1.wav")
const ChargedWallJump: AudioStream = preload("res://Resources/Sound/SFX/jump1.wav")
const Coin: AudioStream = preload("res://Resources/Sound/SFX/coinbag1.wav")
const HealthGain: AudioStream = preload("res://Resources/Sound/SFX/health_gain1.wav")
const Boost: AudioStream = preload("res://Resources/Sound/SFX/boost1.wav")
const Roll: AudioStream = preload("res://Resources/Sound/SFX/retroroll1.wav")
const Land: AudioStream = preload("res://Resources/Sound/SFX/fall_regular.wav")
const LandDamaging: AudioStream = preload("res://Resources/Sound/SFX/fall_regular.wav")
const LandCritical: AudioStream = preload("res://Resources/Sound/SFX/hard_glass_break1.wav")

const DEFAULT_SFX_PITCH: float = 0.2

var active_players: Array[AudioStreamPlayer] = []
var pitch_variations: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_register_buttons(get_tree().root)

func _process(_delta: float) -> void:
	for player in active_players:
		if is_instance_valid(player):
			player.pitch_scale = _get_pitch_scale(pitch_variations.get(player, 0.0))

func play(stream: AudioStream, pitch_variation: float = 0.0) -> void:
	if stream == null:
		push_error("Cannot play a null sound effect.")
		return

	var variation := randf_range(-pitch_variation, pitch_variation) if pitch_variation > 0.0 else 0.0
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	pitch_variations[player] = variation
	player.pitch_scale = _get_pitch_scale(variation)
	get_tree().root.add_child(player)
	active_players.append(player)
	player.finished.connect(_on_player_finished.bind(player))
	player.play()

func _get_pitch_scale(variation: float) -> float:
	var base_pitch := Engine.time_scale if SettingsManager.sfx_pitch_scales_with_time_scale else 1.0
	return maxf(base_pitch * (1.0 + variation), 0.01)

func _on_player_finished(player: AudioStreamPlayer) -> void:
	active_players.erase(player)
	pitch_variations.erase(player)
	player.queue_free()

func _on_node_added(node: Node) -> void:
	_register_buttons(node)

func _register_buttons(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)

	for child in node.get_children():
		_register_buttons(child)

func _on_button_pressed() -> void:
	play(Tap1)
