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

	var first_food_offer: Dictionary = {}
	for offer in run_state.current_market_offers:
		if offer.get("kind", &"") == &"food":
			first_food_offer = offer
			break
	_assert(not first_food_offer.is_empty(), "Initial market should include at least one food offer")
	if first_food_offer.is_empty():
		_finish()
		return

	var market_entries: Array[Dictionary] = run_state.get_market_package_entries()
	_assert(not market_entries.is_empty(), "Market package entries should exist")
	var target_market_entry: Dictionary = {}
	for entry in market_entries:
		if entry.get("offer_id", &"") == first_food_offer["offer_id"]:
			target_market_entry = entry
			break
	_assert(not target_market_entry.is_empty(), "Market package entries should include the first food offer")

	var gold_before_buy: int = run_state.current_gold
	var inventory_count_before_buy: int = run_state.shared_inventory.size()
	var offers_before_buy: int = run_state.current_market_offers.size()
	var bought_package: Array[Dictionary] = run_state.purchase_market_offer_package(target_market_entry.get("offer_id", &""))
	_assert(not bought_package.is_empty(), "Purchasing one market package should succeed")
	_assert(run_state.shared_inventory.size() == inventory_count_before_buy + int(first_food_offer["quantity"]), "Purchasing one market package should add the full package quantity")
	_assert(run_state.current_gold == gold_before_buy - int(first_food_offer["price"]), "Purchasing one market package should spend the package price")
	_assert(run_state.current_market_offers.size() == offers_before_buy - 1, "Buying one market package should remove that package without auto-refilling the market")

	var grouped_inventory: Array[Dictionary] = run_state.get_grouped_inventory_entries()
	_assert(not grouped_inventory.is_empty(), "Grouped inventory entries should exist after buying one package")
	var inventory_group: Dictionary = {}
	for entry in grouped_inventory:
		if entry.get("definition_id", &"") == first_food_offer["definition_id"]:
			inventory_group = entry
			break
	_assert(not inventory_group.is_empty(), "Grouped inventory should include the bought food definition")
	_assert(int(inventory_group.get("count", 0)) == int(first_food_offer["quantity"]), "Grouped inventory should stack the full purchased package quantity")

	var picked_inventory: Dictionary = run_state.pick_inventory_instance(inventory_group.get("group_key", &""))
	_assert(not picked_inventory.is_empty(), "Picking one inventory instance should succeed")
	run_state.selected_item = picked_inventory
	var placed: bool = false
	var placed_anchor := Vector2i.ZERO
	for y in range(run_state.GRID_HEIGHT):
		for x in range(run_state.GRID_WIDTH):
			if run_state.try_place_selected_item(Vector2i(x, y)):
				placed = true
				placed_anchor = Vector2i(x, y)
				break
		if placed:
			break
	_assert(placed, "Dragged inventory instance should place onto the board")
	_assert(run_state.get_selected_character_state()["placed_foods"].size() == 1, "Board should contain exactly one placed food after placement")

	var rotatable_inventory: Dictionary = run_state.generate_item_instance(&"lettuce_leaf")
	run_state.shared_inventory.append(rotatable_inventory)
	run_state.select_inventory_item(rotatable_inventory["instance_id"])
	var before_rotation_cells: Array[Vector2i] = run_state.get_selected_item_cells()
	run_state.rotate_selected_item()
	var after_rotation_cells: Array[Vector2i] = run_state.get_selected_item_cells()
	_assert(before_rotation_cells != after_rotation_cells, "Rotating a selected inventory food should change its placement cells")
	var rotated_inventory_anchor: Vector2i = _find_valid_anchor_for_selected_item(run_state)
	_assert(rotated_inventory_anchor != Vector2i(-1, -1), "Rotated selected inventory food should still have a valid anchor on the board")
	_assert(run_state.try_place_selected_item(rotated_inventory_anchor), "Rotated selected inventory food should place successfully")
	var rotated_inventory_food: Dictionary = run_state.get_item_at_cell(rotated_inventory_anchor)
	_assert(int(rotated_inventory_food.get("rotation", 0)) == 1, "Placed inventory food should keep the rotated state")

	var market_offer_id: StringName = &"rotation_offer_test"
	run_state.current_market_offers.append({
		"offer_id": market_offer_id,
		"slot_index": 98,
		"kind": &"food",
		"definition_id": &"lettuce_leaf",
		"quantity": 2,
		"rarity": &"common",
		"discount": 1.0,
		"price": 4,
	})
	run_state.begin_market_offer_action(market_offer_id)
	var market_before_rotation: Array[Vector2i] = run_state.get_selected_item_cells()
	run_state.rotate_selected_item()
	var market_after_rotation: Array[Vector2i] = run_state.get_selected_item_cells()
	_assert(market_before_rotation != market_after_rotation, "Rotating a market drag action should change its placement cells")
	var market_gold_before_place: int = run_state.current_gold
	var market_anchor: Vector2i = _find_valid_anchor_for_selected_item(run_state)
	_assert(market_anchor != Vector2i(-1, -1), "Rotated market food should still have a valid anchor on the board")
	_assert(run_state.try_place_selected_item(market_anchor), "Rotated market food should place directly from the market onto the board")
	var market_food_on_board: Dictionary = run_state.get_item_at_cell(market_anchor)
	_assert(int(market_food_on_board.get("rotation", 0)) == 1, "Placed market food should keep the rotated state")
	_assert(run_state.current_gold == market_gold_before_place - 4, "Direct market placement should still spend the package price once")

	var moved_food_anchor: Vector2i = placed_anchor + Vector2i(1, 0)
	var move_success: bool = run_state.move_placed_food(placed_anchor, moved_food_anchor)
	_assert(move_success, "Placed food should move to a new valid anchor")
	_assert(run_state.get_selected_character_state()["placed_foods"].size() == 1, "Moving a placed food should preserve a single placed-food entry")
	_assert(run_state.begin_board_food_action(rotated_inventory_anchor), "Placed food should enter a board action when grabbed from the board")
	var board_before_rotation: Array[Vector2i] = run_state.get_selected_item_cells()
	run_state.rotate_selected_item()
	var board_after_rotation: Array[Vector2i] = run_state.get_selected_item_cells()
	_assert(board_before_rotation != board_after_rotation, "Rotating a grabbed board food should change its placement cells")
	var board_reanchor: Vector2i = _find_valid_anchor_for_selected_item(run_state)
	_assert(board_reanchor != Vector2i(-1, -1), "Grabbed board food should still have a legal anchor after rotation")
	_assert(run_state.try_place_selected_item(board_reanchor), "Grabbed board food should rotate and re-place legally")
	var rotated_board_food: Dictionary = run_state.get_item_at_cell(board_reanchor)
	_assert(int(rotated_board_food.get("rotation", 0)) == 2, "Re-placed board food should persist its updated rotation")
	var moved_base: bool = run_state.move_base_board(Vector2i(2, 1))
	_assert(moved_base, "Base bento body should move to a new valid anchor inside the 8x6 workspace")
	_assert(run_state.get_selected_character_state().get("base_anchor", Vector2i.ZERO) == Vector2i(2, 1), "Base bento body should record its new anchor after moving")

	run_state.get_character_state(&"warrior")["pending_expansions"].append({
		"instance_id": &"drag_expansion",
		"label": "1x1",
		"shape_cells": [Vector2i(0, 0)],
		"rotation": 0,
		"target_character_id": &"warrior",
	})
	var grouped_inventory_with_expansion: Array[Dictionary] = run_state.get_grouped_inventory_entries()
	var saw_expansion_entry: bool = false
	for entry_with_expansion in grouped_inventory_with_expansion:
		if entry_with_expansion.get("entry_kind", &"food") == &"expansion":
			saw_expansion_entry = true
			break
	_assert(saw_expansion_entry, "Pending character expansions should appear in the shared inventory strip data")
	run_state.select_pending_expansion(&"drag_expansion")
	var expansion_placed: bool = run_state.try_place_selected_item(Vector2i(5, 1))
	_assert(expansion_placed, "Pending expansion should place on a valid edge anchor")
	var move_expansion_success: bool = run_state.move_placed_expansion(Vector2i(5, 1), Vector2i(5, 2))
	_assert(move_expansion_success, "Placed expansion should move to a new valid edge anchor")
	var placed_foods_after_moves: Array = run_state.get_selected_character_state()["placed_foods"]
	var current_food_cell: Vector2i = placed_foods_after_moves[0]["cells"][0]
	_assert(run_state.remove_item_at_cell(current_food_cell), "Right-click return path should still be backed by state-side item return")

	var next_monster: Dictionary = run_state.get_next_monster_summary()
	_assert(not next_monster.is_empty(), "Next monster summary should exist on active route")
	var synergy_summary: Dictionary = run_state.get_synergy_summary(&"warrior")
	_assert(synergy_summary.has("entries"), "Synergy summary should expose entries")

	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _find_valid_anchor_for_selected_item(run_state: Node) -> Vector2i:
	for y in range(run_state.GRID_HEIGHT):
		for x in range(run_state.GRID_WIDTH):
			var anchor := Vector2i(x, y)
			if run_state.can_place_selected_item(anchor):
				return anchor
	return Vector2i(-1, -1)

func _finish() -> void:
	if _failures.is_empty():
		print("EDITOR_DRAGDROP_TEST_PASS")
		quit(0)
	else:
		printerr("EDITOR_DRAGDROP_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
