extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://Scenes/food_effect_lab.tscn")
	_assert(scene != null, "Food effect lab scene should load")
	if scene == null:
		_finish()
		return
	var lab: Node = scene.instantiate()
	root.add_child(lab)
	await process_frame
	var lab_state := FoodEffectLabState.new()
	_assert(lab_state.CATEGORY_DISPLAY_NAMES[&"fruit"] == "蔬果", "Food effect lab category labels should stay localized")
	_assert(lab_state.CATEGORY_SYNERGY_NAMES[&"meat"] == "血怒", "Food effect lab synergy labels should stay localized")
	lab_state.set_selected_monster(&"nc2_auto_cooker")
	var boss_multipliers: Dictionary = lab_state.get_current_monster_multipliers()
	_assert(is_equal_approx(float(boss_multipliers.get("hp", 0.0)), 1.0), "Food effect lab boss preview should use the boss-stage HP multiplier")
	_assert(lab_state.place_food(&"demon_durian", Vector2i(0, 0)), "Lab should place demon_durian for synergy parity test")
	_assert(lab_state.place_food(&"red_berry", Vector2i(3, 0)), "Lab should place red_berry next to demon_durian")
	_assert(lab_state.place_food(&"lemon", Vector2i(4, 0)), "Lab should place lemon outside demon_durian disable range")
	var durian_summary: Dictionary = lab_state.get_synergy_summary(&"warrior")
	_assert(not bool(_find_synergy_entry(durian_summary, &"fruit").get("active", true)), "Lab synergy summary should ignore demon_durian-disabled foods")
	lab_state.clear_selected_board()
	_assert(lab_state.place_food(&"sausage_skewer", Vector2i(0, 0)), "Lab should place sausage_skewer for bonus-layer test")
	_assert(lab_state.place_food(&"mashed_potato", Vector2i(1, 1)), "Lab should place adjacent mashed_potato")
	_assert(lab_state.place_food(&"ramen", Vector2i(1, 2)), "Lab should place adjacent ramen")
	var sausage_summary: Dictionary = lab_state.get_synergy_summary(&"warrior")
	_assert(int(_find_synergy_entry(sausage_summary, &"meat").get("count", 0)) == 3, "Lab synergy summary should include sausage_skewer bonus meat layers")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/LeftPanel/LeftMargin/LeftVBox/FoodCatalogStrip") != null, "Food catalog strip should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/CenterPanel/CenterMargin/CenterVBox/BoardCenter/BentoBoardView") != null, "Lab board should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/RightPanel/RightMargin/RightVBox/ActualSummary") != null, "Actual summary should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/ExpectedPanel/ExpectedMargin/ExpectedVBox/ExpectedScroll/CompareGrid") != null, "Compare grid should exist")
	if lab.has_method("get_catalog_entry_count"):
		_assert(int(lab.call("get_catalog_entry_count")) == 54, "Food effect lab should expose all 54 foods in the catalog")
	var category_filter: OptionButton = lab.get_node("%CategoryFilterOption")
	var preset_option: OptionButton = lab.get_node("%PresetOption")
	var compare_grid: GridContainer = lab.get_node("Margin/RootVBox/ExpectedPanel/ExpectedMargin/ExpectedVBox/ExpectedScroll/CompareGrid")
	_assert(category_filter.get_item_text(0) == "全部" and category_filter.get_item_text(1) == "蔬果", "Food effect lab category filter should be localized")
	_assert(preset_option.get_item_text(0) == "选中食物单测", "Food effect lab preset labels should be localized")
	_assert((compare_grid.get_child(0) as Label).text == "指标", "Food effect lab compare headers should be localized")
	if lab.has_method("_on_catalog_entry_clicked") and lab.has_method("_on_board_cell_clicked") and lab.has_method("_on_battle_preview_pressed"):
		lab.call("_on_catalog_entry_clicked", {"definition_id": &"pudding_cup"})
		lab.call("_on_board_cell_clicked", Vector2i.ZERO)
		var selected_food_label: Label = lab.get_node("%SelectedFoodLabel")
		_assert(selected_food_label.text.begins_with("选中食物:"), "Food effect lab selected food label should be localized")
		var actual_summary: RichTextLabel = lab.get_node("Margin/RootVBox/TopHBox/RightPanel/RightMargin/RightVBox/ActualSummary")
		_assert(actual_summary.text.contains("角色预览") and actual_summary.text.contains("羁绊"), "Food effect lab actual summary should be localized")
		lab.call("_on_battle_preview_pressed")
		var battle_summary: RichTextLabel = lab.get_node("Margin/RootVBox/TopHBox/RightPanel/RightMargin/RightVBox/BattleSummary")
		_assert(battle_summary.text.contains("怪物:"), "Previewing pudding_cup should complete a localized battle preview instead of crashing")
		lab.call("_on_catalog_entry_clicked", {"definition_id": &"monster_tartare"})
		var rotate_event := InputEventKey.new()
		rotate_event.keycode = KEY_R
		rotate_event.pressed = true
		lab.call("_unhandled_input", rotate_event)
		await process_frame
		var catalog_strip: ItemStrip = lab.get_node("Margin/RootVBox/TopHBox/LeftPanel/LeftMargin/LeftVBox/FoodCatalogStrip")
		var rotated_payload: Dictionary = _find_catalog_drag_payload(catalog_strip, &"monster_tartare")
		_assert(int(rotated_payload.get("rotation", 0)) == 1, "Food effect lab drag payload should reflect the selected rotation")
	lab.queue_free()
	_finish()

func _find_catalog_drag_payload(catalog_strip: ItemStrip, definition_id: StringName) -> Dictionary:
	for card_variant in catalog_strip.get("_cards"):
		var card: ItemIconCard = card_variant
		if card.entry.get("definition_id", &"") == definition_id:
			return card.drag_payload
	return {}

func _find_synergy_entry(summary: Dictionary, category_id: StringName) -> Dictionary:
	for entry_variant in summary.get("entries", []):
		var entry: Dictionary = entry_variant
		if entry.get("category_id", &"") == category_id:
			return entry
	return {}

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_EFFECT_LAB_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_EFFECT_LAB_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
