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

	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Node = editor_scene.instantiate()
	root.add_child(editor)
	await process_frame

	_assert(run_state.character_roster.characters.size() == 3, "Character roster should contain 3 roles")
	_assert(run_state.food_catalog.foods.size() == 54, "Food catalog should contain 54 foods")
	_assert(run_state.current_market_offers.size() == 5, "First market should generate 5 offers")
	_assert(editor.get_node_or_null("LeftPanel/LeftCenter/LeftVBox/WarriorTabButton") != null, "Warrior tab should be visible")
	_assert(editor.get_node_or_null("TopMarketPanel/TopMarketVBox/TopMarketStrip") != null, "Top market strip should be visible")
	_assert(editor.get_node_or_null("BottomInventoryPanel/InventoryDropZone/InventoryStrip") != null, "Bottom inventory strip should be visible")

	var bought_offer: bool = false
	for offer in run_state.current_market_offers:
		if offer["kind"] == &"food" and int(offer["price"]) <= run_state.current_gold:
			var gained_items: Array[Dictionary] = run_state.purchase_market_offer_package(offer["offer_id"])
			bought_offer = not gained_items.is_empty()
			break
	_assert(bought_offer, "Smoke test should be able to buy at least one food offer")
	_assert(not run_state.shared_inventory.is_empty(), "Inventory should contain purchased food")

	var known_item: Dictionary = run_state.generate_item_instance(&"red_berry")
	run_state.shared_inventory.append(known_item)
	run_state.select_inventory_item(known_item["instance_id"])
	var placed: bool = false
	for rotation in range(4):
		if rotation > 0:
			run_state.rotate_selected_item()
		for y in range(run_state.GRID_HEIGHT):
			for x in range(run_state.GRID_WIDTH):
				if run_state.try_place_selected_item(Vector2i(x, y)):
					placed = true
					break
			if placed:
				break
		if placed:
			break
	_assert(placed, "Purchased food should be placeable somewhere on the base board")
	await process_frame

	run_state.advance_to_next_node()
	_assert(run_state.current_route_index == 1, "Route index should advance from 0 to 1 after leaving the first market")

	run_state.prepare_battle()
	var popup: BattlePopup = editor.get_node("BattlePopup") as BattlePopup
	popup.open_battle()
	var start_button: Button = popup.get_node("%StartBattleButton") as Button
	_assert(start_button.visible, "Battle popup should expose the Start Battle button before playback")
	start_button.pressed.emit()
	await process_frame
	while popup._is_playing:
		await process_frame

	_assert(run_state.battle_reports.size() == 1, "Battle report should be recorded")
	editor.queue_free()
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_TEST_PASS")
		quit(0)
	else:
		printerr("SMOKE_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
