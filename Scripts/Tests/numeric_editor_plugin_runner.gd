extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel_scene := load("res://addons/syncark_numeric_editor/numeric_editor_panel.tscn") as PackedScene
	var plugin_script := load("res://addons/syncark_numeric_editor/plugin.gd")
	if panel_scene == null or plugin_script == null:
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: missing plugin shell")
		quit(1)
		return

	var panel = panel_scene.instantiate()
	if panel == null:
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: panel instantiate")
		quit(1)
		return
	root.add_child(panel)
	if not panel.has_method("refresh_all_tables"):
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: panel missing refresh api")
		quit(1)
		return
	if not panel.has_method("save_current_tab"):
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: save_current_tab missing")
		quit(1)
		return
	if not panel.has_method("save_all_tabs"):
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: save_all_tabs missing")
		quit(1)
		return

	panel.refresh_all_tables()
	var snapshot: Dictionary = panel.debug_snapshot()
	if not snapshot.has("Food") or not snapshot.has("StageFlow/Difficulty Curves"):
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: missing expected table snapshots")
		quit(1)
		return
	if (snapshot.get("Food", []) as Array).is_empty():
		printerr("NUMERIC_EDITOR_PLUGIN_FAIL: empty food snapshot")
		quit(1)
		return

	print("NUMERIC_EDITOR_PLUGIN_PASS")
	quit(0)
