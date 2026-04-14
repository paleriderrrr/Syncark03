extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parser_script := load("res://addons/syncark_numeric_editor/typed_value_parser.gd")
	var table_model_script := load("res://addons/syncark_numeric_editor/table_model.gd")
	if parser_script == null or table_model_script == null:
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: missing core scripts")
		quit(1)
		return

	var parser = parser_script.new()
	var int_result: Dictionary = parser.parse_typed_value("12", "int")
	if not bool(int_result.get("ok", false)) or int(int_result.get("value", -1)) != 12:
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: int parse")
		quit(1)
		return

	var float_result: Dictionary = parser.parse_typed_value("1.25", "float")
	if not bool(float_result.get("ok", false)) or abs(float(float_result.get("value", 0.0)) - 1.25) > 0.001:
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: float parse")
		quit(1)
		return

	var vector_result: Dictionary = parser.parse_vector2i_array("[(0,0),(1,0)]")
	if not bool(vector_result.get("ok", false)) or (vector_result.get("value", []) as Array).size() != 2:
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: vector parse")
		quit(1)
		return

	var invalid_result: Dictionary = parser.parse_vector2i_array("[broken]")
	if bool(invalid_result.get("ok", true)):
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: invalid vector accepted")
		quit(1)
		return

	var food_adapter_script := load("res://addons/syncark_numeric_editor/adapters/food_table_adapter.gd")
	var market_adapter_script := load("res://addons/syncark_numeric_editor/adapters/market_table_adapter.gd")
	var stage_adapter_script := load("res://addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd")
	if food_adapter_script == null or market_adapter_script == null or stage_adapter_script == null:
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: missing adapter scripts")
		quit(1)
		return

	var food_catalog := load("res://Data/Foods/food_catalog.tres")
	var food_adapter = food_adapter_script.new()
	var food_table = food_adapter.build_table(food_catalog)
	if food_table.rows.is_empty():
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: empty food table")
		quit(1)
		return

	var changed_food_rows: Array[Dictionary] = food_table.duplicate_rows()
	changed_food_rows[0]["gold_value"] = "99"
	var food_apply: Dictionary = food_adapter.apply_rows(food_catalog, changed_food_rows)
	if not bool(food_apply.get("ok", false)) or food_catalog.foods[0].gold_value != 99:
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: food apply")
		quit(1)
		return

	var market_adapter = market_adapter_script.new()
	var market_config := load("res://Data/Configs/market_config.tres")
	var quantity_table = market_adapter.build_quantity_ranges_table(market_config)
	if quantity_table.rows.is_empty():
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: empty quantity table")
		quit(1)
		return

	var bad_quantity_rows: Array[Dictionary] = quantity_table.duplicate_rows()
	bad_quantity_rows[0]["min"] = "bad"
	var bad_quantity_apply: Dictionary = market_adapter.apply_quantity_ranges_rows(market_config, bad_quantity_rows)
	if bool(bad_quantity_apply.get("ok", true)):
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: invalid quantity row accepted")
		quit(1)
		return

	var stage_adapter = stage_adapter_script.new()
	var stage_config := load("res://Data/Configs/stage_flow_config.tres")
	var difficulty_table = stage_adapter.build_difficulty_table(stage_config)
	if difficulty_table.rows.is_empty():
		printerr("NUMERIC_EDITOR_ADAPTER_FAIL: empty stage difficulty table")
		quit(1)
		return

	print("NUMERIC_EDITOR_ADAPTER_PASS")
	quit(0)
