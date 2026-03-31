extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var board_lookup: Dictionary = FoodVisuals.build_food_board_texture_lookup()
	_assert(not board_lookup.is_empty(), "FoodBoard texture lookup should not be empty")
	_assert(board_lookup.has(&"red_berry"), "FoodBoard textures should include red_berry")
	_assert(board_lookup.has(&"broccoli"), "FoodBoard textures should include broccoli")
	_assert(board_lookup.has(&"tree_fruit"), "FoodBoard textures should include tree_fruit")
	if board_lookup.has(&"broccoli"):
		var broccoli_lookup: Dictionary = board_lookup[&"broccoli"]
		for rotation in range(4):
			_assert(broccoli_lookup.has(rotation), "Broccoli should provide four rotated board textures")
		_assert((broccoli_lookup[0] as Texture2D).get_size() == Vector2(216, 144), "Broccoli board texture should match its 3x2 occupied bounds at 72px cells")
		_assert(_has_no_pixels_in_empty_shape_cells(broccoli_lookup[0] as Texture2D, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], 72), "Irregular broccoli r0 should not leak visible pixels into empty bbox cells")
		_assert(_is_rotated_png_copy("broccoli", 1), "Raw broccoli_r1.png should be a strict 90-degree rotation of broccoli_r0.png")
		_assert(_is_rotated_png_copy("broccoli", 2), "Raw broccoli_r2.png should be a strict 180-degree rotation of broccoli_r0.png")
		_assert(_is_rotated_png_copy("broccoli", 3), "Raw broccoli_r3.png should be a strict 270-degree rotation of broccoli_r0.png")
	if board_lookup.has(&"tree_fruit"):
		var tree_lookup: Dictionary = board_lookup[&"tree_fruit"]
		_assert((tree_lookup[0] as Texture2D).get_size() == Vector2(216, 216), "Cross-shaped food should match a 3x3 occupied bounds texture")
		_assert(_has_no_pixels_in_empty_shape_cells(tree_lookup[0] as Texture2D, [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)], 72), "Irregular tree_fruit r0 should not leak visible pixels into empty bbox cells")
	_finish()

func _is_rotated_png_copy(food_id: String, quarter_turns: int) -> bool:
	var base_image := Image.new()
	var rotated_image := Image.new()
	var base_path: String = ProjectSettings.globalize_path("res://Art/FoodBoard/%s_r0.png" % food_id)
	var rotated_path: String = ProjectSettings.globalize_path("res://Art/FoodBoard/%s_r%d.png" % [food_id, quarter_turns])
	if base_image.load(base_path) != OK or rotated_image.load(rotated_path) != OK:
		return false
	var expected: Image = base_image.duplicate()
	match posmod(quarter_turns, 4):
		1:
			expected.rotate_90(CLOCKWISE)
		2:
			expected.rotate_180()
		3:
			expected.rotate_90(COUNTERCLOCKWISE)
		_:
			pass
	if expected.get_width() != rotated_image.get_width() or expected.get_height() != rotated_image.get_height():
		return false
	for y in range(expected.get_height()):
		for x in range(expected.get_width()):
			if expected.get_pixel(x, y) != rotated_image.get_pixel(x, y):
				return false
	return true

func _has_no_pixels_in_empty_shape_cells(texture: Texture2D, shape_cells: Array[Vector2i], cell_size: int) -> bool:
	if texture == null:
		return false
	var image: Image = texture.get_image()
	if image == null:
		return false
	var occupied_lookup := {}
	var max_x := 0
	var max_y := 0
	for cell in shape_cells:
		occupied_lookup["%d:%d" % [cell.x, cell.y]] = true
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	for cell_y in range(max_y + 1):
		for cell_x in range(max_x + 1):
			if occupied_lookup.has("%d:%d" % [cell_x, cell_y]):
				continue
			for local_y in range(cell_size):
				for local_x in range(cell_size):
					if image.get_pixel(cell_x * cell_size + local_x, cell_y * cell_size + local_y).a > 0.02:
						return false
	return true

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_BOARD_ASSETS_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_BOARD_ASSETS_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
