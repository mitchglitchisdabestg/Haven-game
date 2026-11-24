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
const REPLAY_SOUND_STREAMS: Dictionary = {
	"player_jump": Jump,
	"player_charged_jump": ChargedJump,
	"player_wall_jump": WallJump,
	"player_charged_wall_jump": ChargedWallJump,
	"player_land": Land,
	"player_land_damaging": LandDamaging,
	"player_land_critical": LandCritical,
	"player_coin": Coin,
	"player_health_gain": HealthGain,
	"player_boost": Boost,
	"jump_pad": Boost
}

const DEFAULT_SFX_PITCH: float = 0.2

var active_players: Array[AudioStreamPlayer] = []
var pitch_variations: Dictionary = {}
var replay_players: Array[AudioStreamPlayer] = []
var replay_playback_speeds: Dictionary = {}
var replay_pitch_scales: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_register_buttons(get_tree().root)

func _process(_delta: float) -> void:
	for player in active_players:
		if is_instance_valid(player):
			if replay_pitch_scales.has(player):
				var playback_speed: float = float(replay_playback_speeds.get(player, 1.0))
				player.pitch_scale = maxf(float(replay_pitch_scales[player]) * playback_speed, 0.01)
			else:
				player.pitch_scale = _get_pitch_scale(pitch_variations.get(player, 0.0))

func play(
	stream: AudioStream,
	pitch_variation: float = 0.0,
	replay_sound_id: StringName = &"",
	volume_db: float = 0.0
) -> void:
	if stream == null:
		push_error("Cannot play a null sound effect.")
		return

	var variation := randf_range(-pitch_variation, pitch_variation) if pitch_variation > 0.0 else 0.0
	_create_player(stream, variation, volume_db, false, 1.0)
	if not replay_sound_id.is_empty():
		ReplayManager.record_sound_event(
			String(replay_sound_id),
			Engine.get_physics_frames(),
			_get_pitch_scale(variation),
			volume_db,
			_get_pitch_scale_without_time_scale(variation)
		)


func play_replay_event(
	sound_id: String,
	recorded_pitch_scale: float,
	volume_db: float,
	playback_speed: float = 1.0
) -> void:
	var stream: AudioStream = REPLAY_SOUND_STREAMS.get(sound_id)
	if stream == null:
		push_error("Unknown replay sound identifier: %s" % sound_id)
		return

	_create_player(stream, 0.0, volume_db, true, playback_speed, recorded_pitch_scale)


func has_replay_sound(sound_id: String) -> bool:
	return REPLAY_SOUND_STREAMS.has(sound_id)


func set_replay_playback_speed(playback_speed: float) -> void:
	for player in replay_players:
		if is_instance_valid(player):
			replay_playback_speeds[player] = maxf(playback_speed, 0.01)


func set_replay_audio_paused(paused: bool) -> void:
	for player in replay_players:
		if is_instance_valid(player):
			player.stream_paused = paused


func stop_replay_audio() -> void:
	for player in replay_players:
		if not is_instance_valid(player):
			continue
		player.stop()
		active_players.erase(player)
		pitch_variations.erase(player)
		replay_playback_speeds.erase(player)
		replay_pitch_scales.erase(player)
		player.queue_free()
	replay_players.clear()


func _create_player(
	stream: AudioStream,
	variation: float,
	volume_db: float,
	is_replay_player: bool,
	playback_speed: float,
	recorded_pitch_scale: float = -1.0
) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = volume_db
	pitch_variations[player] = variation
	replay_playback_speeds[player] = playback_speed if is_replay_player else 1.0
	if is_replay_player:
		replay_pitch_scales[player] = recorded_pitch_scale if recorded_pitch_scale > 0.0 else _get_pitch_scale(variation)
		player.pitch_scale = float(replay_pitch_scales[player]) * float(replay_playback_speeds[player])
	else:
		player.pitch_scale = _get_pitch_scale(variation)
	get_tree().root.add_child(player)
	active_players.append(player)
	if is_replay_player:
		replay_players.append(player)
	player.finished.connect(_on_player_finished.bind(player))
	player.play()

func _get_pitch_scale(variation: float) -> float:
	var base_pitch := Engine.time_scale if SettingsManager.sfx_pitch_scales_with_time_scale else 1.0
	return maxf(base_pitch * _get_pitch_scale_without_time_scale(variation), 0.01)


func _get_pitch_scale_without_time_scale(variation: float) -> float:
	return maxf(1.0 + variation, 0.01)

func _on_player_finished(player: AudioStreamPlayer) -> void:
	active_players.erase(player)
	replay_players.erase(player)
	pitch_variations.erase(player)
	replay_playback_speeds.erase(player)
	replay_pitch_scales.erase(player)
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
