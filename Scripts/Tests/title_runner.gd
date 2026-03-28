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
	var start_button: Button = title.get_node("Margin/Root/Center/HeroCard/HeroMargin/HeroVBox/StartButton")
	var settings_button: Button = title.get_node("Margin/Root/TopBar/SettingsButton")
	var quit_button: Button = title.get_node("Margin/Root/TopBar/QuitButton")
	if start_button.text != "Start Adventure":
		failures.append("Start button text mismatch")
	if settings_button.text != "Settings":
		failures.append("Settings button text mismatch")
	if quit_button.text != "Quit":
		failures.append("Quit button text mismatch")
	if failures.is_empty():
		print("TITLE_TEST_PASS")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		quit(1)
