extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://Scenes/loading_screen.tscn")
	var screen: Control = scene.instantiate()
	screen.set("auto_transition_to_target", false)
	screen.set("frame_interval", 0.01)
	root.add_child(screen)
	await process_frame
	var loading_knight: TextureRect = screen.get_node("%LoadingKnight")
	var first_texture: Texture2D = loading_knight.texture
	_assert(first_texture != null, "Loading knight should have an initial frame texture")
	await process_frame
	var second_texture: Texture2D = loading_knight.texture
	_assert(second_texture != null, "Loading knight should keep a frame texture after advancing")
	_assert(second_texture != first_texture, "Loading knight frame animation should advance between process frames")
	screen.queue_free()
	await process_frame
	if _failures.is_empty():
		print("LOADING_SCREEN_TEST_PASS")
		quit(0)
	else:
		printerr("LOADING_SCREEN_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
