@tool
extends EditorPlugin


var _panel: Control


func _enter_tree() -> void:
	var scene := load("res://addons/syncark_numeric_editor/numeric_editor_panel.tscn") as PackedScene
	if scene == null:
		push_error("Failed to load numeric editor panel scene.")
		return
	_panel = scene.instantiate()
	add_control_to_bottom_panel(_panel, "Numeric Editor")


func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
