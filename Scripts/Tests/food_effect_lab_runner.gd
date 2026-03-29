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
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/LeftPanel/LeftMargin/LeftVBox/FoodCatalogStrip") != null, "Food catalog strip should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/CenterPanel/CenterMargin/CenterVBox/BoardCenter/BentoBoardView") != null, "Lab board should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/RightPanel/RightMargin/RightVBox/ActualSummary") != null, "Actual summary should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/ExpectedPanel/ExpectedMargin/ExpectedVBox/ExpectedScroll/CompareGrid") != null, "Compare grid should exist")
	if lab.has_method("get_catalog_entry_count"):
		_assert(int(lab.call("get_catalog_entry_count")) == 54, "Food effect lab should expose all 54 foods in the catalog")
	lab.queue_free()
	_finish()

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
