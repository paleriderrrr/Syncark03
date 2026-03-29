extends Node

const MODE_NON_BATTLE := &"non_battle"
const MODE_BATTLE := &"battle"

const NON_BATTLE_TRACKS: Array[AudioStream] = [
	preload("res://Audio/Music/rest_bgm.mp3"),
	preload("res://Audio/Music/rest_bgm_2.mp3"),
]

const BATTLE_TRACKS: Array[AudioStream] = [
	preload("res://Audio/Music/battle_bgm.mp3"),
	preload("res://Audio/Music/battle_bgm2.mp3"),
]

var _player: AudioStreamPlayer
var _current_mode: StringName = &""
var _track_indices: Dictionary = {
	MODE_NON_BATTLE: 0,
	MODE_BATTLE: 0,
}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = &"Master"
	_player.finished.connect(_on_track_finished)
	add_child(_player)

func play_non_battle() -> void:
	_play_mode(MODE_NON_BATTLE, false)

func play_battle() -> void:
	_play_mode(MODE_BATTLE, false)

func _play_mode(mode: StringName, force_restart: bool) -> void:
	var tracks: Array[AudioStream] = _tracks_for_mode(mode)
	if tracks.is_empty():
		return
	if not force_restart and _current_mode == mode and _player.playing:
		return
	_current_mode = mode
	var index: int = int(_track_indices.get(mode, 0)) % tracks.size()
	_player.stream = tracks[index]
	_player.play()

func _on_track_finished() -> void:
	if _current_mode == &"":
		return
	var tracks: Array[AudioStream] = _tracks_for_mode(_current_mode)
	if tracks.is_empty():
		return
	var next_index: int = (int(_track_indices.get(_current_mode, 0)) + 1) % tracks.size()
	_track_indices[_current_mode] = next_index
	_player.stream = tracks[next_index]
	_player.play()

func _tracks_for_mode(mode: StringName) -> Array[AudioStream]:
	match mode:
		MODE_NON_BATTLE:
			return NON_BATTLE_TRACKS
		MODE_BATTLE:
			return BATTLE_TRACKS
		_:
			return []
