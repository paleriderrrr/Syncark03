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
	var main_backdrop: TextureRect = screen.get_node("MainBackdrop")
	var cover_base_1: TextureRect = screen.get_node("CoverBase1")
	var floating_art_b: TextureRect = screen.get_node("FloatingArtB")
	var cover_glow_1: TextureRect = screen.get_node("CoverGlow1")
	var center_fog: ColorRect = screen.get_node_or_null("CenterFog")
	var edge_fog: ColorRect = screen.get_node_or_null("EdgeFog")
	_assert(center_fog != null, "Center fog should exist")
	if center_fog != null:
		_assert(center_fog.get_index() > main_backdrop.get_index(), "Center fog should render above the main backdrop")
		_assert(center_fog.get_index() < cover_base_1.get_index(), "Center fog should render behind the cover stack")
		var center_material: ShaderMaterial = center_fog.material as ShaderMaterial
		_assert(center_material != null, "Center fog should use a shader material")
	_assert(edge_fog != null, "Edge fog should exist")
	if edge_fog != null:
		_assert(edge_fog.get_index() > floating_art_b.get_index(), "Edge fog should render in front of the decorative art stack")
		_assert(edge_fog.get_index() < start_glow.get_index(), "Edge fog should stay below the start button glow")
		var edge_material: ShaderMaterial = edge_fog.material as ShaderMaterial
		_assert(edge_material != null, "Edge fog should use a shader material")
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
