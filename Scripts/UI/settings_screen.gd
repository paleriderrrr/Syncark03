extends Control

@onready var volume_slider: HSlider = %VolumeSlider
@onready var restart_button: Button = %RestartButton
@onready var back_button: Button = %BackButton

func _run_state() -> Node:
	return get_node("/root/RunState")

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	back_button.pressed.connect(_on_back_pressed)
	volume_slider.value = 100.0

func _on_restart_pressed() -> void:
	_run_state().start_new_run()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")
