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
	_assert(warrior_tab.text.contains("HP "), "Role tab should show inherited HP text")
	_assert(editor.get_node_or_null("RightPanel/NextMonsterPanel") != null, "Next monster panel should exist")
	_assert(editor.get_node_or_null("RightPanel/MonsterTooltipPanel") != null, "Monster tooltip panel should exist")
	_assert(editor.get_node_or_null("RightPanel/SynergyPanel") != null, "Synergy panel should exist")
	_assert(editor.get_node_or_null("RightPanel/ActionButton") != null, "Action button should exist inside the right panel")
	var market_strip: Node = editor.get_node("TopMarketPanel/TopMarketVBox/TopMarketStrip")
	_assert(market_strip.has_method("get_entry_count"), "Top market strip should expose grouped entries")
	if market_strip.has_method("get_entry_count"):
		_assert(int(market_strip.call("get_entry_count")) > 0, "Top market strip should render at least one grouped market entry")
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
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, editor.get_viewport().get_visible_rect().size)
	_assert(_rect_inside_viewport(editor.get_node("StatusPanel").get_global_rect(), viewport_rect), "Status panel should remain inside the viewport")
	_assert(_rect_inside_viewport(editor.get_node("TopMarketPanel").get_global_rect(), viewport_rect), "Top market panel should remain inside the viewport")
	_assert(_rect_inside_viewport(editor.get_node("BottomInventoryPanel").get_global_rect(), viewport_rect), "Bottom inventory panel should remain inside the viewport")
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
