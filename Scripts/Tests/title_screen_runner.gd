extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://Scenes/title_screen.tscn")
	var screen: Control = scene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	var start_glow: TextureRect = screen.get_node("StartGlow")
	_assert(start_glow != null, "Start glow overlay should exist")
	if start_glow != null:
		_assert(start_glow.modulate.a >= 0.15, "Start glow should be visibly present while idle")
		var material: ShaderMaterial = start_glow.material as ShaderMaterial
		_assert(material != null, "Start glow should use a shader material")
		if material != null:
			var glow_color: Color = material.get_shader_parameter("glow_color")
			_assert(glow_color.r == 1.0 and glow_color.g == 1.0 and glow_color.b == 1.0, "Start glow should use a white outline color")
			var glow_size: float = float(material.get_shader_parameter("glow_size"))
			_assert(glow_size <= 12.0, "Start glow outline should stay in a tight edge range")

	screen.queue_free()
	if _failures.is_empty():
		print("TITLE_SCREEN_TEST_PASS")
		quit(0)
	else:
		printerr("TITLE_SCREEN_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
