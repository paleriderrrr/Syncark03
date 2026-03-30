extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var board := BentoBoardView.new()
	_assert(board.get_food_background_alpha() <= 0.22, "Food background alpha should stay subtle")
	_assert(board.get_grid_background_alpha() <= 0.13, "Grid background alpha should stay readable without overpowering the board")
	_assert(board.get_cell_corner_radius() >= 10.0, "Cell drawing should use rounded corners")
	_assert(board.draws_food_outline() == false, "Food cells should no longer draw square outlines")
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("BENTO_BOARD_STYLE_TEST_PASS")
		quit(0)
	else:
		printerr("BENTO_BOARD_STYLE_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
