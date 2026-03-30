extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = root.get_node_or_null("/root/RunState")
	_assert(run_state != null, "RunState autoload should exist")
	if run_state == null:
		_finish()
		return

	run_state.start_new_run()
	run_state.normal_monster_order = [&"fruit_tree_king", &"spice_wizard"]
	run_state.shared_inventory.clear()
	run_state.current_route_index = 1

	var report := {
		"result": "win",
		"bonus_gold": 0,
		"monster_id": &"fruit_tree_king",
		"characters": [],
	}
	run_state.apply_battle_report(report)

	_assert(not run_state.shared_inventory.is_empty(), "Winning a battle should grant at least one drop")
	for item_variant in run_state.shared_inventory:
		var item: Dictionary = item_variant
		var definition: FoodDefinition = run_state.get_food_definition(item.get("definition_id", &"")) as FoodDefinition
		_assert(definition != null, "Granted drop should resolve to a food definition")
		if definition == null:
			continue
		_assert(
			definition.category == &"fruit",
			"Reported fruit_tree_king victory should grant fruit drops, but got %s (%s)" % [
				definition.display_name,
				String(definition.category),
			]
		)

	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("BATTLE_DROP_SOURCE_TEST_PASS")
		quit(0)
	else:
		printerr("BATTLE_DROP_SOURCE_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
