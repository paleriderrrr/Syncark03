extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://Scenes/loading_screen.tscn")
	_assert(scene != null, "Loading screen scene should load")
	if scene == null:
		_finish()
		return
	var loading_screen: Control = scene.instantiate()
	root.add_child(loading_screen)
	await process_frame
	var knight: TextureRect = loading_screen.get_node_or_null("CenterContainer/Knight") as TextureRect
	var animation_player: AnimationPlayer = loading_screen.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_assert(knight != null, "Loading screen should expose the knight frame view")
	if knight != null:
		_assert(knight.texture != null, "Loading screen knight should start with a texture")
	_assert(animation_player != null, "Loading screen should expose an AnimationPlayer")
	if animation_player != null:
		_assert(animation_player.has_animation("run"), "Loading screen should contain the run animation")
		_assert(animation_player.autoplay == &"run", "Loading screen should autoplay the run animation")
	var wait_frames: int = 0
	while not bool(loading_screen.get("_scene_transition_started")) and wait_frames < 180:
		await process_frame
		wait_frames += 1
	_assert(bool(loading_screen.get("_scene_transition_started")), "Loading screen should complete the threaded main-editor load")
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("LOADING_SCREEN_TEST_PASS")
		quit(0)
	else:
		printerr("LOADING_SCREEN_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
