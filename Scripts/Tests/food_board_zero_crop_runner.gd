extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cache := FoodBoardRenderCache.new()
	var wide_rect: Rect2 = cache.compute_zero_crop_dest_rect(Vector2(100.0, 50.0), Vector2(60.0, 60.0))
	_assert(_approx_vec2(wide_rect.size, Vector2(60.0, 45.0)), "Wide source should fit square target without cropping and with bounded stretch")
	_assert(_approx_vec2(wide_rect.position, Vector2(0.0, 7.5)), "Wide source should be vertically centered inside the square target")

	var tall_rect: Rect2 = cache.compute_zero_crop_dest_rect(Vector2(50.0, 100.0), Vector2(60.0, 60.0))
	_assert(_approx_vec2(tall_rect.size, Vector2(45.0, 60.0)), "Tall source should fit square target without cropping and with bounded stretch")
	_assert(_approx_vec2(tall_rect.position, Vector2(7.5, 0.0)), "Tall source should be horizontally centered inside the square target")

	var square_rect: Rect2 = cache.compute_zero_crop_dest_rect(Vector2(100.0, 100.0), Vector2(120.0, 60.0))
	_assert(_approx_vec2(square_rect.size, Vector2(90.0, 60.0)), "Square source should use bounded stretch to maximize coverage in a wide target without cropping")
	_assert(_approx_vec2(square_rect.position, Vector2(15.0, 0.0)), "Wide target fit should remain centered on the x axis")

	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _approx_vec2(left: Vector2, right: Vector2, tolerance: float = 0.02) -> bool:
	return absf(left.x - right.x) <= tolerance and absf(left.y - right.y) <= tolerance

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_BOARD_ZERO_CROP_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_BOARD_ZERO_CROP_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
