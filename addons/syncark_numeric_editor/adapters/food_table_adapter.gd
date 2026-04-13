@tool
extends RefCounted
class_name NumericEditorFoodTableAdapter


const COLUMNS: Array[Dictionary] = [
	{"key": "id", "title": "ID", "kind": "string_name"},
	{"key": "display_name", "title": "Name", "kind": "string"},
	{"key": "category", "title": "Category", "kind": "string_name"},
	{"key": "hybrid_categories", "title": "Hybrid Categories", "kind": "string_name_list"},
	{"key": "rarity", "title": "Rarity", "kind": "string_name"},
	{"key": "gold_value", "title": "Gold", "kind": "int"},
	{"key": "hp_bonus", "title": "HP", "kind": "int"},
	{"key": "attack_bonus", "title": "Attack", "kind": "float"},
	{"key": "bonus_damage", "title": "Bonus Damage", "kind": "float"},
	{"key": "attack_speed_percent", "title": "Attack Speed %", "kind": "float"},
	{"key": "heal_per_second", "title": "Heal / Sec", "kind": "float"},
	{"key": "execute_threshold_percent", "title": "Execute %", "kind": "float"},
	{"key": "passive_text", "title": "Passive Text", "kind": "string"},
	{"key": "shape_cells", "title": "Shape", "kind": "vector2i_array"},
]

var _parser := NumericEditorTypedValueParser.new()


func build_table(catalog: FoodCatalog) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for food in catalog.foods:
		rows.append({
			"id": String(food.id),
			"display_name": food.display_name,
			"category": String(food.category),
			"hybrid_categories": _parser.format_string_name_list(food.hybrid_categories),
			"rarity": String(food.rarity),
			"gold_value": str(food.gold_value),
			"hp_bonus": str(food.hp_bonus),
			"attack_bonus": str(food.attack_bonus),
			"bonus_damage": str(food.bonus_damage),
			"attack_speed_percent": str(food.attack_speed_percent),
			"heal_per_second": str(food.heal_per_second),
			"execute_threshold_percent": str(food.execute_threshold_percent),
			"passive_text": food.passive_text,
			"shape_cells": _parser.format_vector2i_array(food.shape_cells),
		})
	return NumericEditorTableModel.new().setup("Food", "Food", COLUMNS, rows)


func apply_rows(catalog: FoodCatalog, rows: Array[Dictionary]) -> Dictionary:
	if rows.size() != catalog.foods.size():
		return {"ok": false, "error": "Food row count mismatch"}
	for index in rows.size():
		var row: Dictionary = rows[index]
		var food: FoodDefinition = catalog.foods[index]
		var result := _apply_food(food, row)
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "Food row %d: %s" % [index + 1, str(result.get("error", "unknown error"))]}
	return {"ok": true}


func _apply_food(food: FoodDefinition, row: Dictionary) -> Dictionary:
	var result := _parser.parse_typed_value(str(row.get("id", "")), "string_name")
	if not bool(result.get("ok", false)):
		return result
	food.id = result.get("value")
	food.display_name = str(row.get("display_name", ""))

	result = _parser.parse_typed_value(str(row.get("category", "")), "string_name")
	if not bool(result.get("ok", false)):
		return result
	food.category = result.get("value")

	result = _parser.parse_string_name_list(str(row.get("hybrid_categories", "")))
	if not bool(result.get("ok", false)):
		return result
	food.hybrid_categories = result.get("value", [])

	result = _parser.parse_typed_value(str(row.get("rarity", "")), "string_name")
	if not bool(result.get("ok", false)):
		return result
	food.rarity = result.get("value")

	for field in ["gold_value", "hp_bonus"]:
		result = _parser.parse_typed_value(str(row.get(field, "")), "int")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "%s: %s" % [field, result.get("error", "")]}
		food.set(field, result.get("value"))

	for field in ["attack_bonus", "bonus_damage", "attack_speed_percent", "heal_per_second", "execute_threshold_percent"]:
		result = _parser.parse_typed_value(str(row.get(field, "")), "float")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "%s: %s" % [field, result.get("error", "")]}
		food.set(field, result.get("value"))

	food.passive_text = str(row.get("passive_text", ""))

	result = _parser.parse_vector2i_array(str(row.get("shape_cells", "")))
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": "shape_cells: %s" % result.get("error", "")}
	food.shape_cells = result.get("value", [])
	return {"ok": true}
