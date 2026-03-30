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

	_assert(stats_label.get_theme_color("font_color") == Color.WHITE, "Wanted悬停弹窗属性文字应为白色")
	_assert(skill_label.get_theme_color("font_color") == Color.WHITE, "Wanted悬停弹窗技能文字应为白色")
	_assert(stats_label.get_theme_font_size("font_size") == 28, "Wanted悬停弹窗属性文字字号应为 28")
	_assert(skill_label.get_theme_font_size("font_size") == 27, "Wanted悬停弹窗技能文字字号应为 27")
	_assert(monster_tooltip_panel.z_index > bottom_inventory_panel.z_index, "Wanted悬停弹窗层级应高于底部仓库栏")

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
