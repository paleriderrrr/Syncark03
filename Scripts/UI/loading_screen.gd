extends Control

const MAIN_EDITOR_SCENE_PATH := "res://Scenes/main_editor_screen.tscn"
const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://Art/Loading/frame_00001.png"),
	preload("res://Art/Loading/frame_00002.png"),
	preload("res://Art/Loading/frame_00003.png"),
	preload("res://Art/Loading/frame_00004.png"),
	preload("res://Art/Loading/frame_00005.png"),
	preload("res://Art/Loading/frame_00006.png"),
	preload("res://Art/Loading/frame_00007.png"),
	preload("res://Art/Loading/frame_00008.png"),
]

@export var auto_transition_to_target: bool = true
@export var target_scene_path: String = MAIN_EDITOR_SCENE_PATH
@export var frame_interval: float = 0.085

@onready var loading_knight: TextureRect = %LoadingKnight

var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _load_requested: bool = false
var _cache_warmup_started: bool = false
var _cache_warmup_finished: bool = false
var _scene_transition_started: bool = false

func _ready() -> void:
	_apply_frame(0)
	if auto_transition_to_target:
		_request_target_scene_load()
		_warm_main_editor_caches()

func _process(delta: float) -> void:
	_advance_frame(delta)
	if auto_transition_to_target:
		_try_complete_transition()

func _request_target_scene_load() -> void:
	if _load_requested or target_scene_path.is_empty():
		return
	var request_result: Error = ResourceLoader.load_threaded_request(target_scene_path)
	if request_result != OK:
		push_error("Loading screen could not start threaded load for %s (error %d)" % [target_scene_path, request_result])
		return
	_load_requested = true

func _advance_frame(delta: float) -> void:
	if FRAME_TEXTURES.is_empty() or frame_interval <= 0.0:
		return
	_frame_elapsed += delta
	while _frame_elapsed >= frame_interval:
		_frame_elapsed -= frame_interval
		_frame_index = (_frame_index + 1) % FRAME_TEXTURES.size()
		_apply_frame(_frame_index)

func _apply_frame(index: int) -> void:
	if FRAME_TEXTURES.is_empty():
		return
	var clamped_index: int = posmod(index, FRAME_TEXTURES.size())
	loading_knight.texture = FRAME_TEXTURES[clamped_index]

func _try_complete_transition() -> void:
	if not _load_requested or not _cache_warmup_finished or _scene_transition_started:
		return
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_scene_path)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene: PackedScene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
			if packed_scene == null:
				push_error("Loading screen could not retrieve a PackedScene for %s" % target_scene_path)
				return
			_scene_transition_started = true
			get_tree().call_deferred("change_scene_to_packed", packed_scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_scene_transition_started = true
			push_error("Loading screen failed while loading %s" % target_scene_path)

func _warm_main_editor_caches() -> void:
	if _cache_warmup_started:
		return
	_cache_warmup_started = true
	await get_tree().process_frame
	FoodVisuals.build_food_texture_lookup()
	await get_tree().process_frame
	FoodVisuals.build_food_board_texture_lookup()
	await get_tree().process_frame
	LunchboxVisuals.build_role_base_texture_lookup()
	await get_tree().process_frame
	LunchboxVisuals.build_role_expansion_texture_lookup()
	_cache_warmup_finished = true
