extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FoodVisuals.clear_runtime_cache()
	var lookup: Dictionary = FoodVisuals.build_food_texture_lookup()
	var second_lookup: Dictionary = FoodVisuals.build_food_texture_lookup()
	_assert(lookup.has(&"red_berry"), "Food visuals should load red_berry by renamed file id")
	_assert(lookup.has(&"travel_bento"), "Food visuals should load travel_bento by renamed file id")
	_assert(lookup.has(&"matcha"), "Food visuals should load matcha by renamed file id")
	_assert(lookup.has(&"monster_tartare"), "Food visuals should load monster_tartare by renamed file id")
	_assert(not lookup.has(&"IMG_0120"), "Food visuals should not use raw IMG file names as ids")
	_assert(is_same(lookup, second_lookup), "Food visuals should reuse the same runtime lookup instead of rebuilding it")

	if _failures.is_empty():
		print("FOOD_VISUALS_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_VISUALS_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
