extends Control

@onready var volume_slider: HSlider = %VolumeSlider
@onready var restart_button: Button = %RestartButton
@onready var editor_button: Button = %EditorButton
@onready var back_button: Button = %BackButton

func _run_state() -> Node:
	return get_node("/root/RunState")

func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _ready() -> void:
	_bgm_player().play_non_battle()
	restart_button.pressed.connect(_on_restart_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	back_button.pressed.connect(_on_back_pressed)
	volume_slider.value = 100.0

func _on_restart_pressed() -> void:
	_ui_sfx().play_button()
	_run_state().start_new_run()

func _on_back_pressed() -> void:
	_ui_sfx().play_button()
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")

func _on_editor_pressed() -> void:
	_ui_sfx().play_button()
	get_tree().change_scene_to_file("res://Scenes/main_editor_screen.tscn")
