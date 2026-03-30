extends SceneTree

const CACHE_SCRIPT := preload("res://Scripts/UI/food_board_render_cache.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_visible_alpha_region_trims_padding()
	_test_cover_crop_wide_texture()
	_test_cover_crop_tall_texture()
	_test_tetris_shape_cell_regions()
	_test_food_texture_draw_rect_is_inset()
	_finish()

func _test_visible_alpha_region_trims_padding() -> void:
	var cache: RefCounted = CACHE_SCRIPT.new()
	var image := Image.create(6, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(1, 4):
		for x in range(2, 5):
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	var region: Rect2 = cache._compute_visible_alpha_region(image)
	_assert(region.position == Vector2(2, 1), "Visible alpha region should start at the first non-transparent pixel")
	_assert(region.size == Vector2(3, 3), "Visible alpha region should exclude transparent texture padding")

func _test_cover_crop_wide_texture() -> void:
	var source: Rect2 = BentoBoardView.compute_food_cover_source_region(Vector2(400.0, 100.0), Vector2(80.0, 160.0))
	_assert(is_equal_approx(source.size.x, 50.0), "Wide textures should crop width to match tall targets")
	_assert(is_equal_approx(source.position.x, 175.0), "Wide texture crop should remain centered")
	_assert(is_equal_approx(source.size.y, 100.0), "Wide texture crop should keep full height")

func _test_cover_crop_tall_texture() -> void:
	var source: Rect2 = BentoBoardView.compute_food_cover_source_region(Vector2(100.0, 400.0), Vector2(240.0, 80.0))
	_assert(is_equal_approx(source.size.x, 100.0), "Tall textures should keep full width for wide targets")
	_assert(is_equal_approx(source.size.y, 33.333332), "Tall textures should crop height to match wide targets")
	_assert(is_equal_approx(source.position.y, 183.33333), "Tall texture crop should remain vertically centered")

func _test_tetris_shape_cell_regions() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(2, 1),
		Vector2i(3, 1),
		Vector2i(4, 1),
		Vector2i(2, 2),
	]
	var source_region: Rect2 = BentoBoardView.compute_food_cover_source_region(Vector2(300.0, 200.0), Vector2(216.0, 144.0))
	var top_left: Rect2 = BentoBoardView.compute_food_cell_source_region(Vector2i(2, 1), cells, source_region)
	var top_middle: Rect2 = BentoBoardView.compute_food_cell_source_region(Vector2i(3, 1), cells, source_region)
	var top_right: Rect2 = BentoBoardView.compute_food_cell_source_region(Vector2i(4, 1), cells, source_region)
	var bottom_left: Rect2 = BentoBoardView.compute_food_cell_source_region(Vector2i(2, 2), cells, source_region)
	_assert(is_equal_approx(top_left.position.x, source_region.position.x), "Leftmost occupied cell should sample from the left edge of the cropped source")
	_assert(top_middle.position.x > top_left.position.x, "Middle occupied cell should sample a later horizontal region")
	_assert(top_right.position.x > top_middle.position.x, "Rightmost occupied cell should sample the furthest horizontal region")
	_assert(is_equal_approx(bottom_left.position.y, source_region.position.y + source_region.size.y * 0.5), "Second row occupied cell should sample the lower half of the cropped source")
	_assert(is_equal_approx(top_left.size.x, source_region.size.x / 3.0), "Three-column bounds should divide the source region evenly across columns")
	_assert(is_equal_approx(top_left.size.y, source_region.size.y / 2.0), "Two-row bounds should divide the source region evenly across rows")
	_assert(not is_equal_approx(top_middle.position.y, bottom_left.position.y), "An occupied upper-row cell should not sample the same vertical slice as a lower-row occupied cell")

func _test_food_texture_draw_rect_is_inset() -> void:
	var bounds := Rect2(Vector2(0, 0), Vector2(216, 144))
	var draw_rect: Rect2 = BentoBoardView.compute_food_texture_draw_rect(bounds, 72)
	_assert(draw_rect.size.x < bounds.size.x, "Food texture draw rect should leave horizontal margin for the rounded background")
	_assert(draw_rect.size.y < bounds.size.y, "Food texture draw rect should leave vertical margin for the rounded background")
	_assert(draw_rect.position.x > bounds.position.x, "Food texture draw rect should be inset from the left edge")
	_assert(draw_rect.position.y > bounds.position.y, "Food texture draw rect should be inset from the top edge")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_SHAPE_FIT_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_SHAPE_FIT_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
