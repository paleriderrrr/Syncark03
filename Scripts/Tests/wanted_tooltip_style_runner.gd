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

	var stats_label: Label = editor.get_node("RightPanel/MonsterTooltipPanel/MonsterTooltipVBox/NextMonsterStatsLabel")
	var skill_label: Label = editor.get_node("RightPanel/MonsterTooltipPanel/MonsterTooltipVBox/NextMonsterSkillLabel")
	var monster_tooltip_panel: PanelContainer = editor.get_node("RightPanel/MonsterTooltipPanel")
	var bottom_inventory_panel: Control = editor.get_node("BottomInventoryPanel")
	var wanted_poster_rect: TextureRect = editor.get_node("RightPanel/NextMonsterPanel/WantedPosterRect")

	_assert(stats_label.get_theme_color("font_color") == Color.WHITE, "Wanted tooltip stats text should stay white")
	_assert(skill_label.get_theme_color("font_color") == Color.WHITE, "Wanted tooltip skill text should stay white")
	_assert(stats_label.get_theme_font_size("font_size") == 28, "Wanted tooltip stats font should stay at 28")
	_assert(skill_label.get_theme_font_size("font_size") == 27, "Wanted tooltip skill font should stay at 27")
	_assert(monster_tooltip_panel.z_index > bottom_inventory_panel.z_index, "Wanted tooltip should stay above the bottom inventory panel")

	run_state.normal_monster_order = [&"fruit_tree_king", &"spice_wizard"]
	run_state.battle_reports.clear()
	editor.call("_refresh_next_monster_panel")
	await process_frame
	_assert(
		wanted_poster_rect.texture != null and wanted_poster_rect.texture.resource_path.ends_with("Art/Wanted/tree.png"),
		"Wanted poster should use the tree art for the fruit monster"
	)

	run_state.battle_reports = [{"result": "win"}]
	editor.call("_refresh_next_monster_panel")
	await process_frame
	_assert(
		wanted_poster_rect.texture != null and wanted_poster_rect.texture.resource_path.ends_with("Art/Wanted/mushroom.png"),
		"Wanted poster should switch with the upcoming monster id"
	)

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
