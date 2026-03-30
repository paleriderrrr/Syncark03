extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FoodVisuals.clear_runtime_cache()
	var lookup: Dictionary = FoodVisuals.build_food_texture_lookup()
	var second_lookup: Dictionary = FoodVisuals.build_food_texture_lookup()
	var catalog: FoodCatalog = load("res://Data/Foods/food_catalog.tres") as FoodCatalog
	_assert(catalog != null, "Food catalog should load for texture coverage validation")
	if catalog != null:
		for definition_variant in catalog.foods:
			var definition: FoodDefinition = definition_variant
			_assert(lookup.has(definition.id), "Food visuals should expose a texture for %s" % String(definition.id))
	_assert(lookup.has(&"red_berry"), "Food visuals should load red_berry by catalog id")
	_assert(lookup.has(&"travel_bento"), "Food visuals should load travel_bento by catalog id")
	_assert(lookup.has(&"matcha"), "Food visuals should load matcha by catalog id")
	_assert(lookup.has(&"monster_tartare"), "Food visuals should load monster_tartare by catalog id")
	_assert(lookup.has(&"sesame"), "Food visuals should load uppercase-extension textures like sesame.PNG")
	_assert(lookup.has(&"baguette"), "Food visuals should load uppercase-extension textures like baguette.PNG")
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
