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

	_assert(editor.get_node_or_null("TopMarketPanel/TopMarketVBox/TopMarketStrip") != null, "Top market strip should exist")
	_assert(editor.get_node_or_null("TopMarketPanel/TopMarketVBox/TopMarketActions/MarketRefreshButton") != null, "Market refresh button should exist")
	_assert(editor.get_node_or_null("TopMarketPanel/TopMarketVBox/TopMarketStrip/VBox/Scroll") == null, "Top market strip should no longer use a ScrollContainer")
	_assert(editor.get_node_or_null("TopMarketPanel/TopMarketVBox/TopMarketStrip/VBox/StripHBox/Viewport") != null, "Top market strip should use a fixed viewport")
	_assert(editor.get_node_or_null("LeftPanel/LeftCenter/LeftVBox/WarriorTabButton") != null, "Warrior role tab should exist")
	_assert(editor.get_node_or_null("LeftPanel/LeftCenter/LeftVBox/warriorPreviewBoard") == null, "Legacy warrior preview board should be removed")
	var warrior_tab: Button = editor.get_node("LeftPanel/LeftCenter/LeftVBox/WarriorTabButton")
	_assert(warrior_tab.icon != null, "Role tab should render an icon-based tag")
	_assert(editor.get_node_or_null("RightPanel/NextMonsterPanel") != null, "Next monster panel should exist")
	_assert(editor.get_node_or_null("RightPanel/MonsterTooltipPanel") != null, "Monster tooltip panel should exist")
	_assert(editor.get_node_or_null("RightPanel/SynergyPanel") != null, "Synergy panel should exist")
	_assert(editor.get_node_or_null("RightPanel/ActionButton") != null, "Action button should exist inside the right panel")
	_assert(editor.get_node_or_null("RightPanel/ActionButton/ActionButtonText") != null, "Action button should expose a dedicated text texture node")
	var market_strip: Node = editor.get_node("TopMarketPanel/TopMarketVBox/TopMarketStrip")
	_assert(market_strip.has_method("get_entry_count"), "Top market strip should expose grouped entries")
	if market_strip.has_method("get_entry_count"):
		_assert(int(market_strip.call("get_entry_count")) > 0, "Top market strip should render at least one grouped market entry")
	var found_market_expansion_icon: bool = false
	run_state.current_gold = 999
	for _i in range(12):
		await process_frame
		var card_row: HBoxContainer = editor.get_node("TopMarketPanel/TopMarketVBox/TopMarketStrip/VBox/StripHBox/Viewport/CardRow")
		for card_variant in card_row.get_children():
			var card: ItemIconCard = card_variant
			if card.entry.get("kind", &"") != &"expansion":
				continue
			var icon_rect: TextureRect = card.find_child("IconRect", true, false) as TextureRect
			_assert(icon_rect != null, "Expansion market card should expose an icon rect")
			if icon_rect != null:
				_assert(icon_rect.texture != null, "Market expansion card should display a lunchbox texture")
				_assert(icon_rect.visible, "Market expansion card should keep its lunchbox texture visible")
			found_market_expansion_icon = true
			var gained_expansions: Array[Dictionary] = run_state.purchase_market_offer_package(card.entry.get("offer_id", &""))
			_assert(not gained_expansions.is_empty(), "Expansion purchase should succeed during icon validation")
			await process_frame
			var inventory_card_row: HBoxContainer = editor.get_node("BottomInventoryPanel/InventoryDropZone/InventoryStrip/VBox/StripHBox/Viewport/CardRow")
			var found_inventory_expansion_icon: bool = false
			for inventory_card_variant in inventory_card_row.get_children():
				var inventory_card: ItemIconCard = inventory_card_variant
				if inventory_card.entry.get("entry_kind", &"food") != &"expansion":
					continue
				var inventory_icon_rect: TextureRect = inventory_card.find_child("IconRect", true, false) as TextureRect
				_assert(inventory_icon_rect != null, "Pending expansion inventory card should expose an icon rect")
				if inventory_icon_rect != null:
					_assert(inventory_icon_rect.texture != null, "Pending expansion inventory card should display a lunchbox texture")
					_assert(inventory_icon_rect.visible, "Pending expansion inventory card should keep its lunchbox texture visible")
				_assert(not inventory_card.drag_payload.get("shape_cells", []).is_empty(), "Pending expansion inventory drag payload should include shape cells for board validation")
				_assert(inventory_card.drag_payload.get("target_character_id", &"") != &"", "Pending expansion inventory drag payload should retain its target role")
				found_inventory_expansion_icon = true
				break
			_assert(found_inventory_expansion_icon, "Buying an expansion should add a lunchbox-textured pending expansion card to inventory")
			break
		if found_market_expansion_icon:
			break
		_assert(run_state.refresh_market_offers(), "Reroll should succeed while searching for market expansion icons")
	_assert(found_market_expansion_icon, "Market should surface at least one expansion card with a lunchbox icon during validation")
	var before_offer_ids: Array[StringName] = []
	for offer in run_state.current_market_offers:
		before_offer_ids.append(offer["offer_id"])
	var rerolled: bool = run_state.refresh_market_offers()
	_assert(rerolled, "Reroll should succeed on the initial market node")
	var changed_offer_ids: bool = false
	for index in range(min(before_offer_ids.size(), run_state.current_market_offers.size())):
		if before_offer_ids[index] != run_state.current_market_offers[index]["offer_id"]:
			changed_offer_ids = true
			break
	_assert(changed_offer_ids, "Reroll should change the market offers")
	_assert(editor.get_node_or_null("BottomInventoryPanel/InventoryDropZone") != null, "Inventory drop zone should exist")
	_assert(editor.get_node_or_null("BottomInventoryPanel/InventoryDropZone/InventoryStrip") != null, "Bottom inventory strip should exist")
	_assert(editor.get_node_or_null("BottomInventoryPanel/InventoryDropZone/InventoryStrip/VBox/Scroll") == null, "Bottom inventory strip should no longer use a ScrollContainer")
	_assert(editor.get_node_or_null("BottomInventoryPanel/InventoryDropZone/InventoryStrip/VBox/StripHBox/Viewport") != null, "Bottom inventory strip should use a fixed viewport")
	_assert(editor.get_node_or_null("CenterPanel/BoardFrame/BoardCenter/BentoBoardView") != null, "Board should be centered inside the editor area")
	var board_view: Node = editor.get_node("CenterPanel/BoardFrame/BoardCenter/BentoBoardView")
	_assert(board_view.has_method("set_lunchbox_textures"), "Board view should accept lunchbox texture lookups")
	_assert(board_view.has_method("has_base_lunchbox_texture"), "Board view should expose base lunchbox texture availability")
	_assert(board_view.has_method("has_expansion_lunchbox_texture"), "Board view should expose expansion lunchbox texture availability")
	if board_view.has_method("has_base_lunchbox_texture"):
		_assert(bool(board_view.call("has_base_lunchbox_texture", &"warrior")), "Board view should load a warrior base lunchbox texture")
		_assert(bool(board_view.call("has_base_lunchbox_texture", &"hunter")), "Board view should load a hunter base lunchbox texture")
		_assert(bool(board_view.call("has_base_lunchbox_texture", &"mage")), "Board view should load a mage base lunchbox texture")
	if board_view.has_method("has_expansion_lunchbox_texture"):
		_assert(bool(board_view.call("has_expansion_lunchbox_texture", &"warrior", &"1x1")), "Board view should load warrior 1x1 expansion texture")
		_assert(bool(board_view.call("has_expansion_lunchbox_texture", &"warrior", &"2x2")), "Board view should load warrior 2x2 expansion texture")
		_assert(bool(board_view.call("has_expansion_lunchbox_texture", &"warrior", &"1x4")), "Board view should load warrior 1x4 expansion texture")
		_assert(bool(board_view.call("has_expansion_lunchbox_texture", &"warrior", &"2x4")), "Board view should load warrior 2x4 expansion texture")
	_assert(run_state.has_method("get_action_button_visual_key"), "RunState should expose a visual key for the action button")
	if run_state.has_method("get_action_button_visual_key"):
		_assert(run_state.call("get_action_button_visual_key") == &"continue", "Market node should map to continue visual")
		run_state.current_route_index = 1
		_assert(run_state.call("get_action_button_visual_key") == &"depart", "Battle node should map to depart visual")
		run_state.current_route_index = 2
		_assert(run_state.call("get_action_button_visual_key") == &"continue", "Rest node should map to continue visual")
		run_state.current_route_index = 13
		_assert(run_state.call("get_action_button_visual_key") == &"depart", "Boss node should map to depart visual")
		run_state.run_finished = true
		_assert(run_state.call("get_action_button_visual_key") == &"restart", "Finished runs should map to restart visual")
		run_state.run_finished = false
		run_state.current_route_index = 0
	await create_timer(1.0).timeout
	var viewport_rect := Rect2(Vector2.ZERO, editor.get_viewport().get_visible_rect().size)
	_assert(_rect_inside_viewport(editor.get_node("TopMarketPanel/GoldIcon").get_global_rect(), viewport_rect), "Gold icon should remain inside the viewport")
	_assert(_rect_inside_viewport(editor.get_node("RightPanel/StageInfoPanel").get_global_rect(), viewport_rect), "Stage info panel should remain inside the viewport")
	_assert(_rect_inside_viewport(editor.get_node("TopMarketPanel/TopMarketVBox/TopMarketStrip").get_global_rect(), viewport_rect), "Top market strip should remain inside the viewport")
	_assert(_rect_inside_viewport(editor.get_node("BottomInventoryPanel/InventoryDropZone/InventoryStrip").get_global_rect(), viewport_rect), "Bottom inventory strip should remain inside the viewport")
	run_state.current_gold = 999
	run_state.current_market_index = 4
	for _i in range(10):
		_assert(run_state.refresh_market_offers(), "Reroll should succeed during market validation sweep")
		var seen_food_ids: Dictionary = {}
		for offer in run_state.current_market_offers:
			if offer.get("kind", &"") != &"food":
				continue
			_assert(not seen_food_ids.has(offer["definition_id"]), "One market refresh should not contain duplicate food definitions")
			seen_food_ids[offer["definition_id"]] = true
			if offer.get("rarity", &"") == &"epic":
				_assert(int(offer.get("quantity", 0)) == 1, "Epic food packages should not refresh with quantity above 1")

	editor.queue_free()
	if _failures.is_empty():
		print("UI_TEST_PASS")
		quit(0)
	else:
		printerr("UI_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _rect_inside_viewport(rect: Rect2, viewport_rect: Rect2) -> bool:
	return rect.position.x >= viewport_rect.position.x and rect.position.y >= viewport_rect.position.y and rect.end.x <= viewport_rect.end.x and rect.end.y <= viewport_rect.end.y
