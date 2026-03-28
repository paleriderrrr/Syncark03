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
	_assert(editor.get_node_or_null("Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/warriorPreviewBoard") != null, "Warrior bento preview should be visible")
	_assert(editor.get_node_or_null("Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/hunterPreviewBoard") != null, "Hunter bento preview should be visible")
	_assert(editor.get_node_or_null("Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/magePreviewBoard") != null, "Mage bento preview should be visible")
	_assert(not (editor.get_node("Margin/RootVBox/MainHBox/RightPanel/RightVBox/MarketButtons/BuyButton") as Button).disabled, "Buy button should be enabled on market nodes")
	_assert(not (editor.get_node("Margin/RootVBox/MainHBox/RightPanel/RightVBox/MarketButtons/RerollButton") as Button).disabled, "Reroll button should be enabled on market nodes")

	var bought_offer: bool = false
	for index in range(run_state.current_market_offers.size()):
		var offer: Dictionary = run_state.current_market_offers[index]
		if offer["kind"] == &"food" and int(offer["price"]) <= run_state.current_gold:
			bought_offer = run_state.buy_market_offer(index)
			break
	_assert(bought_offer, "Smoke test should be able to buy at least one food offer")
	_assert(not run_state.shared_inventory.is_empty(), "Inventory should contain purchased food")

	var first_item: Dictionary = run_state.shared_inventory[0]
	run_state.select_inventory_item(first_item["instance_id"])
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
