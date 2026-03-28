extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	run_state.shared_inventory.append(run_state.generate_item_instance(&"red_berry"))
	var item: Dictionary = run_state.shared_inventory[0]
	run_state.select_inventory_item(item["instance_id"])
	_assert(run_state.try_place_selected_item(Vector2i.ZERO), "Playback test setup should place a food item")
	run_state.advance_to_next_node()
	run_state.prepare_battle()

	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Node = editor_scene.instantiate()
	root.add_child(editor)
	await process_frame

	var popup: BattlePopup = editor.get_node("BattlePopup") as BattlePopup
	popup.open_battle()
	_assert(popup._is_playing, "Battle popup should enter playback instead of finishing instantly")
	_assert(run_state.battle_reports.is_empty(), "Battle result should not be committed before playback finishes")
	while popup._is_playing:
		await process_frame
	_assert(run_state.battle_reports.size() == 1, "Battle result should be committed after playback finishes")

	editor.queue_free()
	if _failures.is_empty():
		print("BATTLE_PLAYBACK_TEST_PASS")
		quit(0)
	else:
		printerr("BATTLE_PLAYBACK_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
