extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state: Node = get_root().get_node_or_null("/root/RunState")
	_assert(run_state != null, "RunState autoload should exist")
	if run_state == null:
		_finish()
		return

	run_state.delete_saved_run()
	run_state.start_new_run()
	await process_frame

	run_state.current_gold = 77
	run_state.current_route_index = 4
	run_state.current_market_index = 2
	run_state.current_reroll_count = 3
	run_state.selected_character_id = &"mage"
	run_state.tutorial_completed = true
	run_state.shared_inventory = [
		run_state.generate_item_instance(&"red_berry"),
		run_state.generate_item_instance(&"soy_sauce"),
	]
	run_state.character_states[&"warrior"]["hp_ratio"] = 0.6
	run_state.character_states[&"warrior"]["placed_foods"] = [{
		"instance_id": &"placed_food_1",
		"definition_id": &"red_berry",
		"rotation": 1,
		"anchor": Vector2i(2, 1),
		"cells": [Vector2i(2, 1)],
		"reroll_bonus_count": 0,
	}]
	run_state.character_states[&"mage"]["pending_expansions"] = [{
		"instance_id": &"pending_exp_1",
		"label": "1x1",
		"shape_cells": [Vector2i.ZERO],
		"target_character_id": &"mage",
	}]
	run_state.current_market_offers = [{
		"offer_id": &"offer_1",
		"slot_index": 0,
		"kind": &"food",
		"definition_id": &"red_berry",
		"quantity": 2,
		"rarity": &"common",
		"discount": 0.75,
		"price": 2,
	}]
	run_state.normal_monster_order = [&"fruit_tree_king", &"water_giant", &"bread_knight"]
	run_state.free_food_purchase_count = 1
	run_state.spice_purchase_refund = 2
	run_state.battle_reports = [{
		"result": "win",
		"monster_id": &"fruit_tree_king",
	}]
	run_state.pre_battle_snapshot = {
		"character_food_layouts": {
			&"warrior": [{
				"definition_id": &"red_berry",
				"anchor": Vector2i(2, 1),
				"rotation": 1,
				"cells": [Vector2i(2, 1)],
			}],
		},
	}
	run_state.run_finished = false

	_assert(run_state.save_run(), "RunState should save the active run")
	_assert(run_state.has_saved_run(), "RunState should report the save after writing it")

	run_state.start_new_run(false)
	await process_frame
	_assert(run_state.load_run(), "Saved run should remain loadable after resetting runtime state")

	_assert(run_state.current_gold == 77, "Saved gold should be restored")
	_assert(run_state.current_route_index == 4, "Saved route index should be restored")
	_assert(run_state.current_market_index == 2, "Saved market index should be restored")
	_assert(run_state.current_reroll_count == 3, "Saved reroll count should be restored")
	_assert(run_state.selected_character_id == &"mage", "Saved selected character should be restored")
	_assert(run_state.is_tutorial_completed(), "Saved tutorial completion flag should be restored")
	_assert(run_state.shared_inventory.size() == 2, "Saved shared inventory should be restored")
	_assert(absf(float(run_state.character_states[&"warrior"]["hp_ratio"]) - 0.6) < 0.001, "Saved character hp ratio should be restored")
	_assert(run_state.character_states[&"warrior"]["placed_foods"].size() == 1, "Saved placed foods should be restored")
	_assert(run_state.character_states[&"mage"]["pending_expansions"].size() == 1, "Saved pending expansions should be restored")
	_assert(run_state.current_market_offers.size() == 1, "Saved market offers should be restored")
	_assert(run_state.normal_monster_order.size() == 3, "Saved monster order should be restored")
	_assert(run_state.free_food_purchase_count == 1, "Saved free food purchase count should be restored")
	_assert(run_state.spice_purchase_refund == 2, "Saved spice refund count should be restored")
	_assert(run_state.battle_reports.size() == 1, "Saved battle reports should be restored")
	_assert(not run_state.pre_battle_snapshot.is_empty(), "Saved pre-battle snapshot should be restored")

	run_state.delete_saved_run()
	_assert(not run_state.has_saved_run(), "Deleting the save should remove the resumable run")
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("SAVE_LOAD_TEST_PASS")
		quit(0)
	else:
		printerr("SAVE_LOAD_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
