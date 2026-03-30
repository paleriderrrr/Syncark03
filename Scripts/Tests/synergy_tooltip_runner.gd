extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Control = editor_scene.instantiate() as Control
	root.add_child(editor)
	await process_frame
	await process_frame
	var panel: SynergyPanel = editor.get_node("%SynergyPanel")
	var overlay: ImmediateSynergyTooltipOverlay = editor.get_node("SynergyTooltipOverlay")
	assert(overlay != null, "Synergy tooltip overlay should exist")
	assert(not overlay.visible, "Synergy tooltip overlay should start hidden")
	panel.emit_signal("synergy_hover_started", {
		"category_name": "蔬果",
		"synergy_name": "果酸反伤",
		"count": 2,
		"effect_text": "腐蚀接触的敌怪",
	}, Rect2(Vector2(100, 100), Vector2(56, 56)))
	await process_frame
	assert(overlay.visible, "Synergy tooltip overlay should become visible on hover")
	var name_label: Label = overlay.get_node("%SynergyTooltipNameLabel")
	var count_label: Label = overlay.get_node("%SynergyTooltipCountLabel")
	assert(name_label.text == "果酸反伤", "Synergy tooltip should show the synergy name")
	assert(count_label.text.contains("x2"), "Synergy tooltip should show the current count")
	panel.emit_signal("synergy_hover_ended")
	await process_frame
	assert(not overlay.visible, "Synergy tooltip overlay should hide on hover end")
	print("SYNERGY_TOOLTIP_TEST_PASS")
	quit()
