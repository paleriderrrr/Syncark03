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
	_assert(run_state.should_auto_open_tutorial_on_editor_entry(), "Fresh runs started without an existing save should auto-open the tutorial on editor entry")

	run_state.current_gold = 77
	run_state.current_route_index = 4
	run_state.current_market_index = 2
	run_state.current_reroll_count = 3
	run_state.selected_character_id = &"mage"
	run_state.tutorial_completed = true
	var saved_inventory: Array[Dictionary] = [
		run_state.generate_item_instance(&"red_berry"),
		run_state.generate_item_instance(&"soy_sauce"),
	]
	run_state.shared_inventory = saved_inventory
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
	var saved_market_offers: Array[Dictionary] = [{
		"offer_id": &"offer_1",
		"slot_index": 0,
		"kind": &"food",
		"definition_id": &"red_berry",
		"quantity": 2,
		"rarity": &"common",
		"discount": 0.75,
		"price": 2,
	}]
	run_state.current_market_offers = saved_market_offers
	var saved_monster_order: Array[StringName] = [&"fruit_tree_king", &"water_giant", &"bread_knight"]
	run_state.normal_monster_order = saved_monster_order
	run_state.free_food_purchase_count = 1
	run_state.spice_purchase_refund = 2
	var saved_battle_reports: Array[Dictionary] = [{
		"result": "win",
		"monster_id": &"fruit_tree_king",
	}]
	run_state.battle_reports = saved_battle_reports
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
	_assert(not run_state.should_auto_open_tutorial_on_editor_entry(), "Loaded runs should not be treated as no-save tutorial entries")

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
	_assert(run_state.should_auto_open_tutorial_on_editor_entry(), "Deleting the resumable save should restore no-save tutorial entry behavior")

	var valid_snapshot: Dictionary = run_state.call("_build_run_snapshot")
	_run_invalid_snapshot_cases(run_state, valid_snapshot)

	run_state.master_volume_percent = 37.0
	run_state.tutorial_completed = true
	run_state.start_new_run()
	_assert(run_state.save_run(), "RunState should save metadata alongside a run before delete testing")
	run_state.delete_saved_run()
	_assert(not run_state.has_saved_run(), "Deleting a save should still remove only the resumable run data")
	run_state.master_volume_percent = 100.0
	run_state.tutorial_completed = false
	run_state.call("_load_persistent_metadata")
	_assert(is_equal_approx(run_state.get_master_volume_percent(), 37.0), "Deleting a save should preserve persisted volume settings")
	_assert(run_state.is_tutorial_completed(), "Deleting a save should preserve persisted tutorial metadata")
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _run_invalid_snapshot_cases(run_state: Node, valid_snapshot: Dictionary) -> void:
	var route_count: int = run_state.stage_flow_config.route_nodes.size()
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "selected_character_id", &"missing_role"), "Loading a snapshot with an unknown selected character should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_route_index", -1), "Loading a snapshot with a negative route index should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_route_index", route_count), "Loading a snapshot past the route should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_index", 0), "Loading a snapshot with market index below tier range should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_index", 5), "Loading a snapshot with market index above tier range should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "instance_counter", 0), "Loading a snapshot with a non-positive instance counter should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "pre_battle_snapshot", "bad_snapshot"), "Loading a snapshot with a non-dictionary pre-battle snapshot should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "normal_monster_order", [&"missing_monster"]), "Loading a snapshot with an unknown normal monster should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "normal_monster_order", [&"nc2_auto_cooker"]), "Loading a snapshot with a boss inside normal monster order should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "shared_inventory", "bad_inventory"), "Loading a snapshot with a non-array inventory should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "shared_inventory", [{"definition_id": &"red_berry"}]), "Loading an inventory item without an instance id should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "shared_inventory", [{"instance_id": &"bad_food", "definition_id": &"missing_food"}]), "Loading an inventory item with an unknown food definition should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "shared_inventory", [
		{"instance_id": &"dup_food", "definition_id": &"red_berry"},
		{"instance_id": &"dup_food", "definition_id": &"soy_sauce"},
	]), "Loading duplicate inventory instance ids should fail explicitly")
	var missing_character_snapshot: Dictionary = valid_snapshot.duplicate(true)
	missing_character_snapshot["character_states"].erase(&"hunter")
	_assert_rejected_snapshot(run_state, missing_character_snapshot, "Loading a snapshot missing a roster character state should fail explicitly")
	var bad_character_snapshot: Dictionary = valid_snapshot.duplicate(true)
	bad_character_snapshot["character_states"][&"warrior"] = "bad_state"
	_assert_rejected_snapshot(run_state, bad_character_snapshot, "Loading a non-dictionary character state should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "base_shape", []), "Loading a character state with an empty base shape should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "active_cells", "bad_cells"), "Loading a character state with non-array active cells should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "placed_foods", [{
		"instance_id": &"bad_placed",
		"definition_id": &"missing_food",
		"rotation": 0,
		"anchor": Vector2i.ZERO,
		"cells": [Vector2i.ZERO],
	}]), "Loading placed food with an unknown definition should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "placed_foods", [{
		"instance_id": &"empty_placed",
		"definition_id": &"red_berry",
		"rotation": 0,
		"anchor": Vector2i.ZERO,
		"cells": [],
	}]), "Loading placed food with empty cells should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "placed_foods", [{
		"instance_id": &"outside_placed",
		"definition_id": &"red_berry",
		"rotation": 0,
		"anchor": Vector2i(7, 5),
		"cells": [Vector2i(7, 5)],
	}]), "Loading placed food outside active cells should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "placed_foods", [
		{"instance_id": &"placed_a", "definition_id": &"red_berry", "rotation": 0, "anchor": Vector2i.ZERO, "cells": [Vector2i.ZERO]},
		{"instance_id": &"placed_b", "definition_id": &"soy_sauce", "rotation": 0, "anchor": Vector2i.ZERO, "cells": [Vector2i.ZERO]},
	]), "Loading overlapping placed foods should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "placed_expansions", [{
		"instance_id": &"base_overlap_expansion",
		"label": "1x1",
		"shape_cells": [Vector2i.ZERO],
		"rotation": 0,
		"anchor": Vector2i.ZERO,
		"cells": [Vector2i.ZERO],
	}]), "Loading expansion cells overlapping the base should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "placed_expansions", [{
		"instance_id": &"disconnected_expansion",
		"label": "1x1",
		"shape_cells": [Vector2i.ZERO],
		"rotation": 0,
		"anchor": Vector2i(7, 5),
		"cells": [Vector2i(7, 5)],
	}]), "Loading disconnected placed expansions should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with_character_field(valid_snapshot, &"warrior", "pending_expansions", [{
		"instance_id": &"bad_pending",
		"label": "1x1",
		"shape_cells": [Vector2i.ZERO],
		"rotation": 0,
		"target_character_id": &"missing_role",
	}]), "Loading pending expansion for an unknown character should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_offers", "bad_offers"), "Loading non-array market offers should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_offers", [{
		"offer_id": &"bad_offer",
		"slot_index": 0,
		"kind": &"food",
		"definition_id": &"missing_food",
		"quantity": 1,
		"rarity": &"common",
		"discount": 1.0,
		"price": 1,
	}]), "Loading a market food offer with an unknown definition should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_offers", [{
		"offer_id": &"bad_offer",
		"slot_index": 0,
		"kind": &"food",
		"definition_id": &"red_berry",
		"quantity": 0,
		"rarity": &"common",
		"discount": 1.0,
		"price": 1,
	}]), "Loading a market food offer with zero quantity should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_offers", [{
		"offer_id": &"bad_offer",
		"slot_index": 0,
		"kind": &"food",
		"definition_id": &"red_berry",
		"quantity": 1,
		"rarity": &"common",
		"discount": 1.0,
		"price": -1,
	}]), "Loading a market offer with a negative price should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_offers", [{
		"offer_id": &"bad_expansion_offer",
		"slot_index": 0,
		"kind": &"expansion",
		"target_character_id": &"missing_role",
		"shape_cells": [Vector2i.ZERO],
		"price": 1,
		"label": "1x1",
	}]), "Loading an expansion offer for an unknown character should fail explicitly")
	_assert_rejected_snapshot(run_state, _snapshot_with(valid_snapshot, "current_market_offers", [{
		"offer_id": &"bad_expansion_offer",
		"slot_index": 0,
		"kind": &"expansion",
		"target_character_id": &"warrior",
		"shape_cells": [],
		"price": 1,
		"label": "1x1",
	}]), "Loading an expansion offer with an empty shape should fail explicitly")

func _snapshot_with(valid_snapshot: Dictionary, key: String, value: Variant) -> Dictionary:
	var snapshot: Dictionary = valid_snapshot.duplicate(true)
	snapshot[key] = value
	return snapshot

func _snapshot_with_character_field(valid_snapshot: Dictionary, character_id: StringName, key: String, value: Variant) -> Dictionary:
	var snapshot: Dictionary = valid_snapshot.duplicate(true)
	var character_state: Dictionary = snapshot["character_states"][character_id]
	character_state[key] = value
	snapshot["character_states"][character_id] = character_state
	return snapshot

func _assert_rejected_snapshot(run_state: Node, snapshot: Dictionary, message: String) -> void:
	_assert(not run_state.call("_apply_run_snapshot", snapshot), message)

func _finish() -> void:
	if _failures.is_empty():
		print("SAVE_LOAD_TEST_PASS")
		quit(0)
	else:
		printerr("SAVE_LOAD_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
