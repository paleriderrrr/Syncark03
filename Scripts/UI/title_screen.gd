extends Control

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

func _run_state() -> Node:
	return get_node("/root/RunState")

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	_run_state().start_new_run()
	get_tree().change_scene_to_file("res://Scenes/main_editor_screen.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/settings_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
