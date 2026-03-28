extends Control

const TEX_BOARD := preload("res://Art/UI/Slices/ui1_board_wood.png")
const TEX_DEPART := preload("res://Art/UI/Slices/ui1_depart_sign.png")
const TEX_BUY := preload("res://Art/UI/Slices/ui2_buy_button.png")
const TEX_SELL := preload("res://Art/UI/Slices/ui2_sell_button.png")

@onready var hero_card: PanelContainer = %HeroCard
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var hint_label: Label = %HintLabel

func _run_state() -> Node:
	return get_node("/root/RunState")

func _ready() -> void:
	_apply_surface_art()
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _apply_surface_art() -> void:
	_apply_panel_texture(hero_card, TEX_BOARD, 56)
	_apply_button_texture(start_button, TEX_DEPART, 32)
	_apply_button_texture(settings_button, TEX_BUY, 20)
	_apply_button_texture(quit_button, TEX_SELL, 20)
	_apply_button_font_color(start_button, Color(0.46, 0.11, 0.08))
	_apply_button_font_color(settings_button, Color(0.94, 0.94, 0.94))
	_apply_button_font_color(quit_button, Color(0.2, 0.2, 0.2))
	title_label.add_theme_color_override("font_color", Color(0.35, 0.12, 0.08))
	subtitle_label.add_theme_color_override("font_color", Color(0.23, 0.17, 0.1))
	summary_label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.12))
	hint_label.add_theme_color_override("font_color", Color(0.3, 0.21, 0.16))

func _apply_panel_texture(panel: PanelContainer, texture: Texture2D, margin: int) -> void:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	panel.add_theme_stylebox_override("panel", style)

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
	_run_state().start_new_run()
	get_tree().change_scene_to_file("res://Scenes/main_editor_screen.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/settings_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
