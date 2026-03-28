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

	_assert(editor.get_node_or_null("Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/warriorPreviewBoard") != null, "Warrior bento preview should exist")
	_assert(editor.get_node_or_null("Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/hunterPreviewBoard") != null, "Hunter bento preview should exist")
	_assert(editor.get_node_or_null("Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/magePreviewBoard") != null, "Mage bento preview should exist")
	_assert(not (editor.get_node("Margin/RootVBox/MainHBox/RightPanel/RightVBox/MarketButtons/BuyButton") as Button).disabled, "Buy button should be enabled on market nodes")
	_assert(not (editor.get_node("Margin/RootVBox/MainHBox/RightPanel/RightVBox/MarketButtons/RerollButton") as Button).disabled, "Reroll button should be enabled on market nodes")
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
