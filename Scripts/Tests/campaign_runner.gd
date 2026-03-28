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
	await process_frame

	_assert(run_state.current_route_index == 0, "New run should start at route index 0")
	_assert(run_state.current_gold == 30, "New run should start with 30 gold")
	run_state.apply_battle_report({
		"result": "win",
		"bonus_gold": 0,
		"log": PackedStringArray(),
		"characters": [
			{"id": &"warrior", "current_hp": 90.0, "max_hp": 180.0, "alive": true},
			{"id": &"hunter", "current_hp": 45.0, "max_hp": 90.0, "alive": true},
			{"id": &"mage", "current_hp": 35.0, "max_hp": 70.0, "alive": true},
		],
	})
	_assert(absf(float(run_state.get_character_state(&"warrior").get("hp_ratio", 0.0)) - 0.5) < 0.001, "Battle report should persist warrior HP ratio")
	var warrior_health: Dictionary = run_state.get_character_health_display(&"warrior")
	_assert(int(warrior_health.get("current_hp", 0)) == 90, "Health display should reflect inherited warrior HP")
	run_state.start_new_run()
	await process_frame

	run_state.shared_inventory.append(run_state.generate_item_instance(&"red_berry"))
	var inventory_item: Dictionary = run_state.shared_inventory[run_state.shared_inventory.size() - 1]
	run_state.select_inventory_item(inventory_item["instance_id"])
	_assert(run_state.try_place_selected_item(Vector2i.ZERO), "Should place a smoke-test food on the warrior board")
	run_state.prepare_battle()
	_assert(not run_state.pre_battle_snapshot.is_empty(), "Preparing battle should capture a snapshot")
	_assert(run_state.remove_item_at_cell(Vector2i.ZERO), "Placed food should be removable")
	_assert(run_state.try_restore_snapshot(), "Snapshot restore should rebuild the pre-battle layout")

	var expansion_id: StringName = &"test_expansion"
	run_state.get_character_state(&"warrior")["pending_expansions"].append({
		"instance_id": expansion_id,
		"label": "1x1",
		"shape_cells": [Vector2i(0, 0)],
		"rotation": 0,
		"target_character_id": &"warrior",
	})
	run_state.select_pending_expansion(expansion_id)
	_assert(run_state.try_place_selected_item(Vector2i(3, 0)), "Expansion should place adjacent to the base board")

	while not run_state.run_finished:
		var route_index: int = run_state.current_route_index
		if route_index in [0, 4, 8, 12]:
			var left_market: bool = run_state.perform_primary_action()
			_assert(left_market, "Market node should advance through the primary action")
		elif route_index in [2, 6, 10]:
			var left_rest: bool = run_state.perform_primary_action()
			_assert(left_rest, "Rest node should advance through the primary action")
		else:
			run_state.prepare_battle()
			run_state.apply_battle_report({
				"result": "win",
				"bonus_gold": 0,
				"log": PackedStringArray(),
				"characters": [
					{"id": &"warrior", "current_hp": 80.0, "max_hp": 160.0, "alive": true},
					{"id": &"hunter", "current_hp": 30.0, "max_hp": 60.0, "alive": true},
					{"id": &"mage", "current_hp": 20.0, "max_hp": 40.0, "alive": true},
				],
			})
		await process_frame

	_assert(run_state.run_finished, "Winning through the full route should finish the run")
	_assert(run_state.current_route_index == run_state.stage_flow_config.route_nodes.size() - 1, "Finished run should end on the last route node")
	_assert(run_state.battle_reports.size() == 7, "Full route should record 7 battle reports")
	_assert(run_state.get_completed_battle_count() == 7, "Full route should count 7 wins")
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CAMPAIGN_TEST_PASS")
		quit(0)
	else:
		printerr("CAMPAIGN_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
