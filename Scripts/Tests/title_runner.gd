extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://Scenes/title_screen.tscn")
	var title: Node = scene.instantiate()
	root.add_child(title)
	await process_frame
	var start_button: TextureButton = title.get_node("StartButton")
	var settings_button: Button = title.get_node("SettingsButton")
	var quit_button: Button = title.get_node("QuitButton")
	if start_button.texture_normal == null:
		failures.append("Start button texture missing")
	if settings_button.icon == null:
		failures.append("Settings button icon missing")
	if quit_button.icon == null:
		failures.append("Quit button icon missing")
	if not settings_button.flat:
		failures.append("Settings button should remain flat")
	if not quit_button.flat:
		failures.append("Quit button should remain flat")
	if failures.is_empty():
		print("TITLE_TEST_PASS")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		quit(1)
