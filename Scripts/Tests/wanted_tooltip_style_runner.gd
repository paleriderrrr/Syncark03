extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Control = editor_scene.instantiate() as Control
	root.add_child(editor)
	await process_frame

	var right_info_board: Control = editor.get_node("RightPanel/RightInfoBoard")
	var stats_label: Label = editor.get_node("RightPanel/RightInfoBoard/BoardScale/BackFace/BackStatsLabel")
	var skill_label: Label = editor.get_node("RightPanel/RightInfoBoard/BoardScale/BackFace/BackSkillLabel")
	var bottom_inventory_panel: Control = editor.get_node("BottomInventoryPanel")
	var front_wanted_poster_rect: TextureRect = editor.get_node("RightPanel/RightInfoBoard/BoardScale/FrontFace/FrontWantedPosterRect")
	var back_wanted_poster_rect: TextureRect = editor.get_node("RightPanel/RightInfoBoard/BoardScale/BackFace/BackWantedPosterRect")

	_assert(stats_label.get_theme_font_size("font_size") == 17, "Right info board back stats font should stay at 17")
	_assert(skill_label.get_theme_font_size("font_size") == 16, "Right info board back skill font should stay at 16")
	_assert(right_info_board.get_global_rect().end.y <= bottom_inventory_panel.get_global_rect().position.y, "Right info board should stay above the bottom inventory panel")

	run_state.normal_monster_order = [&"fruit_tree_king", &"spice_wizard"]
	run_state.battle_reports.clear()
	editor.call("_refresh_next_monster_panel")
	await process_frame
	_assert(
		front_wanted_poster_rect.texture != null and front_wanted_poster_rect.texture.resource_path.ends_with("Art/Wanted/tree.png"),
		"Wanted poster should use the tree art for the fruit monster"
	)
	_assert(
		back_wanted_poster_rect.texture != null and back_wanted_poster_rect.texture.resource_path.ends_with("Art/Wanted/tree.png"),
		"Back-face poster should stay in sync with the front face"
	)

	run_state.battle_reports = [{"result": "win"}]
	editor.call("_refresh_next_monster_panel")
	await process_frame
	_assert(
		front_wanted_poster_rect.texture != null and front_wanted_poster_rect.texture.resource_path.ends_with("Art/Wanted/mushroom.png"),
		"Wanted poster should switch with the upcoming monster id"
	)
	right_info_board.call("flip_to_back")
	await create_timer(0.35).timeout
	_assert(not bool(right_info_board.call("is_showing_front")), "Right info board should be able to flip to the back face")

	editor.queue_free()
	if _failures.is_empty():
		print("WANTED_TOOLTIP_STYLE_TEST_PASS")
		quit(0)
	else:
		printerr("WANTED_TOOLTIP_STYLE_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
