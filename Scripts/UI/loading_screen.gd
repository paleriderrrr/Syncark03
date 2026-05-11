extends Control

const TARGET_SCENE_PATH := "res://Scenes/main_editor_screen.tscn"

var _load_requested: bool = false
var _scene_transition_started: bool = false
var _frames_before_load: int = 1

func _ready() -> void:
	_request_target_scene_load()

func _process(_delta: float) -> void:
	_try_complete_transition()

func _request_target_scene_load() -> void:
	if _load_requested:
		return
	_load_requested = true

func _try_complete_transition() -> void:
	if not _load_requested or _scene_transition_started:
		return
	if _frames_before_load > 0:
		_frames_before_load -= 1
		return
	var packed_scene: PackedScene = load(TARGET_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Loading screen could not load a PackedScene for %s" % TARGET_SCENE_PATH)
		return
	_scene_transition_started = true
	get_tree().call_deferred("change_scene_to_packed", packed_scene)
