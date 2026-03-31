extends SceneTree

const CACHE_SCRIPT := preload("res://Scripts/UI/food_board_render_cache.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_cache_reuses_baked_texture()
	_test_rotation_uses_distinct_baked_texture()
	_test_baked_texture_matches_shape_bounds()
	_test_regular_shape_keeps_bbox_fit_solution()
	_test_irregular_shape_r0_stays_inside_occupied_cells()
	_finish()

func _test_cache_reuses_baked_texture() -> void:
	var cache: RefCounted = CACHE_SCRIPT.new()
	var definition := FoodDefinition.new()
	definition.id = &"shape_cache_food"
	definition.shape_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var texture: Texture2D = _make_test_texture(Vector2i(32, 24))
	cache.prime({definition.id: texture}, {definition.id: definition}, 40)
	var first: Texture2D = cache.get_texture(definition.id, 0, 40)
	var second: Texture2D = cache.get_texture(definition.id, 0, 40)
	_assert(first != null, "Cache should return a baked texture for a primed food id")
	_assert(first == second, "Repeated lookups for the same key should reuse the baked texture instance")

func _test_rotation_uses_distinct_baked_texture() -> void:
	var cache: RefCounted = CACHE_SCRIPT.new()
	var definition := FoodDefinition.new()
	definition.id = &"rotation_food"
	definition.shape_cells = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	var texture: Texture2D = _make_test_texture(Vector2i(40, 28))
	cache.prime({definition.id: texture}, {definition.id: definition}, 30)
	var rotation_zero: Texture2D = cache.get_texture(definition.id, 0, 30)
	var rotation_one: Texture2D = cache.get_texture(definition.id, 1, 30)
	_assert(rotation_zero != null and rotation_one != null, "Cache should bake all requested rotations")
	_assert(rotation_zero != rotation_one, "Different rotations should use distinct baked textures")
	_assert(rotation_zero.get_size() != rotation_one.get_size(), "Rotated baked textures should reflect rotated shape bounds when dimensions differ")

func _test_baked_texture_matches_shape_bounds() -> void:
	var cache: RefCounted = CACHE_SCRIPT.new()
	var definition := FoodDefinition.new()
	definition.id = &"cross_food"
	definition.shape_cells = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	var texture: Texture2D = _make_test_texture(Vector2i(96, 72))
	cache.prime({definition.id: texture}, {definition.id: definition}, 26)
	var baked: Texture2D = cache.get_texture(definition.id, 0, 26)
	_assert(baked != null, "Cache should bake the continuous board texture")
	_assert(baked.get_size() == Vector2(78, 78), "Cross-shaped foods should bake to their occupied bounding box size in pixels")

func _test_regular_shape_keeps_bbox_fit_solution() -> void:
	var cache: FoodBoardRenderCache = CACHE_SCRIPT.new()
	var shape_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var solution: Dictionary = cache.compute_best_solution_for_shape(Vector2(100.0, 100.0), shape_cells, 0, 30)
	var dest_rect: Rect2 = solution.get("dest_rect", Rect2())
	_assert(_approx_vec2(dest_rect.size, Vector2(60.0, 60.0)), "Regular full-rectangle shapes should keep using the outer bounding box fit")
	_assert(bool(solution.get("fits_occupied_mask", false)), "Regular full-rectangle shapes should be treated as trivially valid within the occupied mask")

func _test_irregular_shape_r0_stays_inside_occupied_cells() -> void:
	var cache: FoodBoardRenderCache = CACHE_SCRIPT.new()
	var shape_cells: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(1, 2),
	]
	var solution: Dictionary = cache.compute_best_solution_for_shape(Vector2(96.0, 72.0), shape_cells, 0, 26)
	_assert(bool(solution.get("fits_occupied_mask", false)), "Irregular shape r0 solutions should explicitly guarantee occupied-mask containment")
	_assert(not cache.solution_intersects_empty_cells(solution, shape_cells, 0, 26), "Irregular shape r0 solutions should not place the visible region into empty bbox cells")

func _make_test_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		for x in range(size.x):
			image.set_pixel(x, y, Color(float(x) / max(size.x - 1, 1), float(y) / max(size.y - 1, 1), 1.0, 1.0))
	return ImageTexture.create_from_image(image)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _approx_vec2(left: Vector2, right: Vector2, tolerance: float = 0.02) -> bool:
	return absf(left.x - right.x) <= tolerance and absf(left.y - right.y) <= tolerance

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_BOARD_RENDER_CACHE_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_BOARD_RENDER_CACHE_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
