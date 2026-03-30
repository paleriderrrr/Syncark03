extends SceneTree

const CACHE_SCRIPT := preload("res://Scripts/UI/food_board_render_cache.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_cache_reuses_baked_texture()
	_test_rotation_uses_distinct_baked_texture()
	_test_baked_texture_matches_shape_bounds()
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

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_BOARD_RENDER_CACHE_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_BOARD_RENDER_CACHE_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
