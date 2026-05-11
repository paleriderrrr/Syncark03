extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Node = editor_scene.instantiate()
	root.add_child(editor)
	await process_frame

	_assert(editor.get_node_or_null("RightPanel/ActionButton/ActionButtonText") != null, "Action button should expose a dedicated text texture node")
	_assert(run_state.has_method("get_action_button_visual_key"), "RunState should expose a visual key for the action button")
	if run_state.has_method("get_action_button_visual_key"):
		_assert(run_state.call("get_action_button_visual_key") == &"continue", "Market node should map to continue visual")
		run_state.current_route_index = 1
		_assert(run_state.call("get_action_button_visual_key") == &"depart", "Battle node should map to depart visual")
		run_state.current_route_index = 2
		_assert(run_state.call("get_action_button_visual_key") == &"continue", "Rest node should map to continue visual")
		run_state.pre_battle_snapshot = {"character_food_layouts": {}}
		editor.call("_refresh")
		var restore_button: Button = editor.get_node("RightPanel/RestoreButton")
		_assert(restore_button.visible, "Rest restore button should be visible when a snapshot exists")
		_assert(restore_button.text == "恢复", "Rest restore button should be localized")
		_assert(not restore_button.disabled, "Rest restore button should be enabled when a snapshot exists")
		run_state.current_route_index = 13
		_assert(run_state.call("get_action_button_visual_key") == &"depart", "Boss node should map to depart visual")
		run_state.run_finished = true
		_assert(run_state.call("get_action_button_visual_key") == &"restart", "Finished runs should map to restart visual")

	run_state.start_new_run()
	run_state.current_route_index = 1
	run_state.pre_battle_snapshot.clear()
	var requested: Dictionary = {"count": 0}
	run_state.battle_requested.connect(func() -> void:
		requested["count"] = int(requested["count"]) + 1
	)
	_assert(run_state.perform_primary_action(), "Battle primary action should request battle entry")
	_assert(int(requested["count"]) == 1, "Battle primary action should emit one battle request")
	_assert(run_state.pre_battle_snapshot.is_empty(), "Battle request should not capture the restorable snapshot until the actual battle starts")

	editor.queue_free()
	if _failures.is_empty():
		print("ACTION_BUTTON_TEST_PASS")
		quit(0)
	else:
		printerr("ACTION_BUTTON_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
