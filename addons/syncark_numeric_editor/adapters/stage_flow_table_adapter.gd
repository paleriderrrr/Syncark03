@tool
extends RefCounted
class_name NumericEditorStageFlowTableAdapter


const SCALAR_COLUMNS: Array[Dictionary] = [
	{"key": "initial_gold", "title": "Initial Gold", "kind": "int"},
]

const ROUTE_COLUMNS: Array[Dictionary] = [
	{"key": "index", "title": "Index", "kind": "int", "editable": false},
	{"key": "node_type", "title": "Node Type", "kind": "string_name"},
]

const DIFFICULTY_COLUMNS: Array[Dictionary] = [
	{"key": "battle_index", "title": "Battle Index", "kind": "int", "editable": false},
	{"key": "normal_battle_reward_gold", "title": "Gold Reward", "kind": "int"},
	{"key": "normal_drop_value_curve", "title": "Drop Value", "kind": "int"},
	{"key": "monster_hp_multiplier_curve", "title": "Monster HP Mult", "kind": "float"},
	{"key": "monster_attack_multiplier_curve", "title": "Monster ATK Mult", "kind": "float"},
]

var _parser := NumericEditorTypedValueParser.new()


func build_scalar_table(config: StageFlowConfig) -> NumericEditorTableModel:
	return NumericEditorTableModel.new().setup("StageFlow/Scalars", "StageFlow/Scalars", SCALAR_COLUMNS, [{"initial_gold": str(config.initial_gold)}])


func build_route_table(config: StageFlowConfig) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for index in config.route_nodes.size():
		rows.append({"index": str(index), "node_type": String(config.route_nodes[index])})
	return NumericEditorTableModel.new().setup("StageFlow/Route Nodes", "StageFlow/Route Nodes", ROUTE_COLUMNS, rows)


func build_difficulty_table(config: StageFlowConfig) -> NumericEditorTableModel:
	var max_count := maxi(
		config.normal_battle_reward_gold.size(),
		maxi(config.normal_drop_value_curve.size(), maxi(config.monster_hp_multiplier_curve.size(), config.monster_attack_multiplier_curve.size()))
	)
	var rows: Array[Dictionary] = []
	for index in max_count:
		rows.append({
			"battle_index": str(index),
			"normal_battle_reward_gold": _get_or_blank(config.normal_battle_reward_gold, index),
			"normal_drop_value_curve": _get_or_blank(config.normal_drop_value_curve, index),
			"monster_hp_multiplier_curve": _get_or_blank(config.monster_hp_multiplier_curve, index),
			"monster_attack_multiplier_curve": _get_or_blank(config.monster_attack_multiplier_curve, index),
		})
	return NumericEditorTableModel.new().setup("StageFlow/Difficulty Curves", "StageFlow/Difficulty Curves", DIFFICULTY_COLUMNS, rows)


func apply_scalar_rows(config: StageFlowConfig, rows: Array[Dictionary]) -> Dictionary:
	if rows.size() != 1:
		return {"ok": false, "error": "Stage scalar table must have exactly one row"}
	var result := _parser.parse_typed_value(str(rows[0].get("initial_gold", "")), "int")
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": "initial_gold: %s" % result.get("error", "")}
	config.initial_gold = result.get("value")
	return {"ok": true}


func apply_route_rows(config: StageFlowConfig, rows: Array[Dictionary]) -> Dictionary:
	var next_nodes: Array[StringName] = []
	for index in rows.size():
		var result := _parser.parse_typed_value(str(rows[index].get("node_type", "")), "string_name")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "Route row %d: %s" % [index + 1, result.get("error", "")]}
		next_nodes.append(result.get("value"))
	config.route_nodes = next_nodes
	return {"ok": true}


func apply_difficulty_rows(config: StageFlowConfig, rows: Array[Dictionary]) -> Dictionary:
	var gold_curve: Array[int] = []
	var drop_curve: Array[int] = []
	var hp_curve: Array[float] = []
	var attack_curve: Array[float] = []
	for index in rows.size():
		var row: Dictionary = rows[index]
		var gold_result := _parser.parse_typed_value(str(row.get("normal_battle_reward_gold", "")), "int")
		var drop_result := _parser.parse_typed_value(str(row.get("normal_drop_value_curve", "")), "int")
		var hp_result := _parser.parse_typed_value(str(row.get("monster_hp_multiplier_curve", "")), "float")
		var attack_result := _parser.parse_typed_value(str(row.get("monster_attack_multiplier_curve", "")), "float")
		if not bool(gold_result.get("ok", false)) or not bool(drop_result.get("ok", false)) or not bool(hp_result.get("ok", false)) or not bool(attack_result.get("ok", false)):
			return {"ok": false, "error": "Difficulty row %d contains invalid numeric data" % [index + 1]}
		gold_curve.append(gold_result.get("value"))
		drop_curve.append(drop_result.get("value"))
		hp_curve.append(hp_result.get("value"))
		attack_curve.append(attack_result.get("value"))
	config.normal_battle_reward_gold = gold_curve
	config.normal_drop_value_curve = drop_curve
	config.monster_hp_multiplier_curve = hp_curve
	config.monster_attack_multiplier_curve = attack_curve
	return {"ok": true}


func _get_or_blank(values: Array, index: int) -> String:
	if index >= 0 and index < values.size():
		return str(values[index])
	return ""
