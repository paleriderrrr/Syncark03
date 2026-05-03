extends Control

const TARGET_SCENE_PATH := "res://Scenes/main_editor_screen.tscn"

var _load_requested: bool = false
var _scene_transition_started: bool = false

func _ready() -> void:
	_request_target_scene_load()

func _process(_delta: float) -> void:
	_try_complete_transition()

func _request_target_scene_load() -> void:
	if _load_requested:
		return
	var request_result: Error = ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)
	if request_result != OK:
		push_error("Loading screen could not start threaded load for %s (error %d)" % [TARGET_SCENE_PATH, request_result])
		return
	_load_requested = true

func _try_complete_transition() -> void:
	if not _load_requested or _scene_transition_started:
		return
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(TARGET_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Loading screen could not retrieve a PackedScene for %s" % TARGET_SCENE_PATH)
		return
	_scene_transition_started = true
	get_tree().call_deferred("change_scene_to_packed", packed_scene)
