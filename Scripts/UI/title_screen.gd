extends Control

const TRANSITION_STEP := 0.12
const TRANSITION_DURATION := 0.34
const LAYER_ALPHA_END := 0.0
const START_GLOW_IDLE_ALPHA := 0.42
const START_GLOW_PULSE_ALPHA := 0.78
const START_BUTTON_IDLE_ALPHA := 1.0
const START_BUTTON_PULSE_ALPHA := 0.96
const LOADING_SCENE_PATH := "res://Scenes/loading_screen.tscn"
const MAIN_EDITOR_SCENE_PATH := "res://Scenes/main_editor_screen.tscn"
const CONTINUE_BUTTON_TEXT := "\u7EE7\u7EED\u5192\u9669"

@onready var cover_base_1: TextureRect = %CoverBase1
@onready var cover_base_2: TextureRect = %CoverBase2
@onready var cover_base_3: TextureRect = %CoverBase3
@onready var cover_base_4: TextureRect = %CoverBase4
@onready var center_fog: ColorRect = %CenterFog
@onready var cover_glow_1: TextureRect = %CoverGlow1
@onready var cover_glow_2: TextureRect = %CoverGlow2
@onready var cover_glow_3: TextureRect = %CoverGlow3
@onready var cover_glow_4: TextureRect = %CoverGlow4
@onready var title_art: TextureRect = %TitleArt
@onready var floating_art: TextureRect = %FloatingArt
@onready var floating_art_b: TextureRect = %FloatingArtB
@onready var edge_fog: ColorRect = %EdgeFog
@onready var start_glow: TextureRect = %StartGlow
@onready var start_button: TextureButton = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _transition_started: bool = false
var _ambient_tweens: Array[Tween] = []
var _title_base_y: float = 0.0
var _floating_scroll_active: bool = false
var _floating_scroll_speed: float = 12.0
var _floating_scroll_height: float = 1080.0
var _floating_a_base_y: float = 0.0
var _floating_b_base_y: float = 0.0

func _run_state() -> Node:
	return get_node("/root/RunState")

func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _ready() -> void:
	_bgm_player().play_non_battle()
	_configure_cover_pivots()
	_cache_ambient_bases()
	_start_ambient_effects()
	_refresh_continue_button()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _exit_tree() -> void:
	_stop_ambient_effects()

func _process(delta: float) -> void:
	if not _floating_scroll_active:
		return
	_advance_floating_scroll(floating_art, delta)
	_advance_floating_scroll(floating_art_b, delta)

func _on_start_pressed() -> void:
	if _transition_started:
		return
	_ui_sfx().play_button()
	_transition_started = true
	_stop_ambient_effects()
	start_button.disabled = true
	continue_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	_play_start_transition()

func _play_start_transition() -> void:
	var layers: Array[Dictionary] = [
		{"node": floating_art, "scale": Vector2(1.16, 1.16), "delay": 0.00},
		{"node": floating_art_b, "scale": Vector2(1.16, 1.16), "delay": 0.00},
		{"node": edge_fog, "scale": Vector2(1.08, 1.08), "delay": 0.00},
		{"node": title_art, "scale": Vector2(1.13, 1.13), "delay": TRANSITION_STEP},
		{"node": cover_base_4, "scale": Vector2(1.10, 1.10), "delay": TRANSITION_STEP * 2.0},
		{"node": cover_base_3, "scale": Vector2(1.09, 1.09), "delay": TRANSITION_STEP * 3.0},
		{"node": cover_base_2, "scale": Vector2(1.08, 1.08), "delay": TRANSITION_STEP * 4.0},
		{"node": cover_base_1, "scale": Vector2(1.07, 1.07), "delay": TRANSITION_STEP * 5.0},
		{"node": center_fog, "scale": Vector2(1.04, 1.04), "delay": TRANSITION_STEP * 5.0},
	]
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for layer_variant in layers:
		var layer: Dictionary = layer_variant
		_queue_layer_transition(
			tween,
			layer["node"],
			layer["delay"],
			layer["scale"]
		)
	await tween.finished
	_run_state().start_new_run()
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

func _refresh_continue_button() -> void:
	var has_save: bool = _run_state().has_saved_run()
	continue_button.text = CONTINUE_BUTTON_TEXT
	continue_button.visible = has_save
	continue_button.disabled = not has_save

func _configure_cover_pivots() -> void:
	for node in [cover_base_1, cover_base_2, cover_base_3, cover_base_4, center_fog, cover_glow_1, cover_glow_2, cover_glow_3, cover_glow_4, title_art, floating_art, floating_art_b, edge_fog, start_glow]:
		node.pivot_offset = node.size * 0.5
	start_button.pivot_offset = start_button.size * 0.5
	continue_button.pivot_offset = continue_button.size * 0.5

func _cache_ambient_bases() -> void:
	_title_base_y = title_art.position.y
	_floating_a_base_y = floating_art.position.y
	_floating_b_base_y = floating_art.position.y - _floating_scroll_height
	floating_art_b.position.y = _floating_b_base_y

func _start_ambient_effects() -> void:
	_start_glow_overlay(cover_glow_1, 0.46, 3.1)
	_start_glow_overlay(cover_glow_2, 0.40, 3.7)
	_start_glow_overlay(cover_glow_3, 0.64, 4.3)
	_start_glow_overlay(cover_glow_4, 0.60, 4.9)
	_start_title_glow()
	_start_floating_glow(floating_art, 0.92, 2.8)
	_start_floating_glow(floating_art_b, 0.92, 2.8)
	_floating_scroll_active = true
	_start_button_pulse()

func _stop_ambient_effects() -> void:
	_floating_scroll_active = false
	for tween in _ambient_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_ambient_tweens.clear()
	for layer in [cover_base_1, cover_base_2, cover_base_3, cover_base_4, center_fog, title_art, floating_art, floating_art_b, edge_fog]:
		layer.modulate = Color.WHITE
	for glow in [cover_glow_1, cover_glow_2, cover_glow_3, cover_glow_4]:
		glow.modulate.a = 0.0
	start_glow.modulate = Color(1.0, 1.0, 1.0, START_GLOW_IDLE_ALPHA)
	start_button.modulate = Color(1.0, 1.0, 1.0, START_BUTTON_IDLE_ALPHA)
	floating_art.position.y = _floating_a_base_y
	floating_art_b.position.y = _floating_b_base_y

func _start_glow_overlay(node: TextureRect, peak_alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", peak_alpha, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_ambient_tweens.append(tween)

func _start_title_glow() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_art, "modulate", Color(1.0, 1.0, 1.0, 0.95), 3.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_art, "modulate", Color.WHITE, 3.6)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_ambient_tweens.append(tween)

func _start_floating_glow(node: TextureRect, low_alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, low_alpha), duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate", Color.WHITE, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_ambient_tweens.append(tween)

func _advance_floating_scroll(node: TextureRect, delta: float) -> void:
	node.position.y += _floating_scroll_speed * delta
	if node.position.y >= _floating_scroll_height:
		node.position.y -= _floating_scroll_height * 2.0

func _start_button_pulse() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(start_glow, "modulate:a", START_GLOW_PULSE_ALPHA, 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(start_button, "modulate", Color(1.0, 1.0, 1.0, START_BUTTON_PULSE_ALPHA), 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(start_glow, "modulate:a", START_GLOW_IDLE_ALPHA, 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(start_button, "modulate", Color(1.0, 1.0, 1.0, START_BUTTON_IDLE_ALPHA), 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_ambient_tweens.append(tween)

func _queue_layer_transition(tween: Tween, node: CanvasItem, delay: float, scale_target: Vector2) -> void:
	tween.tween_property(node, "scale", scale_target, TRANSITION_DURATION)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", LAYER_ALPHA_END, TRANSITION_DURATION)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

func _on_settings_pressed() -> void:
	if _transition_started:
		return
	_ui_sfx().play_button()
	_run_state().set_settings_return_scene("res://Scenes/title_screen.tscn")
	get_tree().change_scene_to_file("res://Scenes/settings_screen.tscn")

func _on_continue_pressed() -> void:
	if _transition_started:
		return
	_ui_sfx().play_button()
	if not _run_state().load_run():
		_run_state().delete_saved_run()
		_refresh_continue_button()
		return
	_transition_started = true
	start_button.disabled = true
	continue_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

func _on_quit_pressed() -> void:
	if _transition_started:
		return
	_ui_sfx().play_button()
	get_tree().quit()
