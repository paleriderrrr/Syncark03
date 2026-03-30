extends Control

const TITLE_SCENE_PATH := "res://Scenes/title_screen.tscn"
const MAIN_EDITOR_SCENE_PATH := "res://Scenes/main_editor_screen.tscn"

@onready var volume_slider: HSlider = %VolumeSlider
@onready var restart_button: TextureButton = %RestartButton
@onready var editor_button: TextureButton = %EditorButton
@onready var back_button: TextureButton = %BackButton
@onready var close_button: TextureButton = %CloseButton

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
	close_button.pressed.connect(_on_close_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.set_value_no_signal(_run_state().get_master_volume_percent())

func _on_restart_pressed() -> void:
	_ui_sfx().play_button()
	_run_state().start_new_run()
	get_tree().change_scene_to_file(MAIN_EDITOR_SCENE_PATH)

func _on_back_pressed() -> void:
	_ui_sfx().play_button()
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)

func _on_editor_pressed() -> void:
	_ui_sfx().play_button()
	get_tree().change_scene_to_file(MAIN_EDITOR_SCENE_PATH)

func _on_close_pressed() -> void:
	_ui_sfx().play_button()
	var return_path: String = _run_state().consume_settings_return_scene(TITLE_SCENE_PATH)
	get_tree().change_scene_to_file(return_path)

func _on_volume_changed(value: float) -> void:
	_run_state().set_master_volume_percent(value)
