extends Control

const TEX_BUY := preload("res://Art/UI/Slices/ui2_buy_button.png")
const TEX_SELL := preload("res://Art/UI/Slices/ui2_sell_button.png")

const TRANSITION_STEP := 0.12
const TRANSITION_DURATION := 0.34
const LAYER_ALPHA_END := 0.0

@onready var cover_base_1: TextureRect = %CoverBase1
@onready var cover_base_2: TextureRect = %CoverBase2
@onready var cover_base_3: TextureRect = %CoverBase3
@onready var cover_base_4: TextureRect = %CoverBase4
@onready var title_art: TextureRect = %TitleArt
@onready var floating_art: TextureRect = %FloatingArt
@onready var start_button: TextureButton = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

var _transition_started: bool = false
var _ambient_tweens: Array[Tween] = []
var _ambient_float_base_y: float = 0.0
var _title_base_y: float = 0.0

func _run_state() -> Node:
	return get_node("/root/RunState")

func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")

func _ready() -> void:
	_bgm_player().play_non_battle()
	_apply_surface_art()
	_configure_cover_pivots()
	_cache_ambient_bases()
	_start_ambient_effects()
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _exit_tree() -> void:
	_stop_ambient_effects()

func _apply_surface_art() -> void:
	_apply_button_texture(settings_button, TEX_BUY, 20)
	_apply_button_texture(quit_button, TEX_SELL, 20)
	_apply_button_font_color(settings_button, Color(0.94, 0.94, 0.94))
	_apply_button_font_color(quit_button, Color(0.2, 0.2, 0.2))

func _apply_button_texture(button: Button, texture: Texture2D, margin: int) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = margin
		style.texture_margin_top = margin
		style.texture_margin_right = margin
		style.texture_margin_bottom = margin
		button.add_theme_stylebox_override(state_name, style)

func _apply_button_font_color(button: Button, color: Color) -> void:
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, color)

func _on_start_pressed() -> void:
	if _transition_started:
		return
	_transition_started = true
	_stop_ambient_effects()
	start_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	_play_start_transition()

func _play_start_transition() -> void:
	var layers: Array[Dictionary] = [
		{"node": floating_art, "scale": Vector2(1.16, 1.16), "delay": 0.00},
		{"node": title_art, "scale": Vector2(1.13, 1.13), "delay": TRANSITION_STEP},
		{"node": cover_base_4, "scale": Vector2(1.10, 1.10), "delay": TRANSITION_STEP * 2.0},
		{"node": cover_base_3, "scale": Vector2(1.09, 1.09), "delay": TRANSITION_STEP * 3.0},
		{"node": cover_base_2, "scale": Vector2(1.08, 1.08), "delay": TRANSITION_STEP * 4.0},
		{"node": cover_base_1, "scale": Vector2(1.07, 1.07), "delay": TRANSITION_STEP * 5.0},
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
	get_tree().change_scene_to_file("res://Scenes/main_editor_screen.tscn")

func _configure_cover_pivots() -> void:
	for node in [cover_base_1, cover_base_2, cover_base_3, cover_base_4, title_art, floating_art]:
		node.pivot_offset = node.size * 0.5
	start_button.pivot_offset = start_button.size * 0.5

func _cache_ambient_bases() -> void:
	_ambient_float_base_y = floating_art.position.y
	_title_base_y = title_art.position.y

func _start_ambient_effects() -> void:
	_start_layer_fade(cover_base_1, 0.985, 8.0)
	_start_layer_fade(cover_base_2, 0.978, 9.0)
	_start_layer_fade(cover_base_3, 0.972, 10.0)
	_start_layer_fade(cover_base_4, 0.966, 12.0)
	_start_title_glow()
	_start_floating_glow()
	_start_button_pulse()

func _stop_ambient_effects() -> void:
	for tween in _ambient_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_ambient_tweens.clear()
	for layer in [cover_base_1, cover_base_2, cover_base_3, cover_base_4, title_art, floating_art]:
		layer.modulate = Color.WHITE
	start_button.scale = Vector2.ONE
	start_button.modulate = Color.WHITE

func _start_layer_fade(node: TextureRect, low_alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", low_alpha, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration)\
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

func _start_floating_glow() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(floating_art, "modulate", Color(1.0, 1.0, 1.0, 0.92), 2.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(floating_art, "modulate", Color.WHITE, 2.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_ambient_tweens.append(tween)

func _start_button_pulse() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(start_button, "scale", Vector2(1.026, 1.026), 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(start_button, "modulate", Color(1.0, 1.0, 1.0, 0.94), 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(start_button, "scale", Vector2.ONE, 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(start_button, "modulate", Color.WHITE, 1.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_ambient_tweens.append(tween)

func _queue_layer_transition(tween: Tween, node: TextureRect, delay: float, scale_target: Vector2) -> void:
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
	get_tree().change_scene_to_file("res://Scenes/settings_screen.tscn")

func _on_quit_pressed() -> void:
	if _transition_started:
		return
	get_tree().quit()
