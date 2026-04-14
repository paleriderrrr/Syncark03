@tool
extends RefCounted
class_name NumericEditorMarketTableAdapter


const SCALAR_COLUMNS: Array[Dictionary] = [
	{"key": "slot_count", "title": "Slot Count", "kind": "int"},
	{"key": "expansion_slot_chance", "title": "Expansion Slot Chance", "kind": "float"},
	{"key": "food_slot_chance", "title": "Food Slot Chance", "kind": "float"},
	{"key": "discount_min", "title": "Discount Min", "kind": "float"},
	{"key": "discount_max", "title": "Discount Max", "kind": "float"},
]

const REROLL_COLUMNS: Array[Dictionary] = [
	{"key": "index", "title": "Index", "kind": "int", "editable": false},
	{"key": "value", "title": "Cost", "kind": "int"},
]

const RARITY_COLUMNS: Array[Dictionary] = [
	{"key": "market", "title": "Market", "kind": "int"},
	{"key": "common", "title": "Common", "kind": "int"},
	{"key": "rare", "title": "Rare", "kind": "int"},
	{"key": "epic", "title": "Epic", "kind": "int"},
]

const QUANTITY_COLUMNS: Array[Dictionary] = [
	{"key": "rarity", "title": "Rarity", "kind": "string_name"},
	{"key": "min", "title": "Min", "kind": "int"},
	{"key": "max", "title": "Max", "kind": "int"},
]

const EXPANSION_COLUMNS: Array[Dictionary] = [
	{"key": "label", "title": "Label", "kind": "string"},
	{"key": "price", "title": "Price", "kind": "int"},
	{"key": "weight", "title": "Weight", "kind": "float"},
	{"key": "shape", "title": "Shape", "kind": "vector2i_array"},
]

var _parser := NumericEditorTypedValueParser.new()


func build_scalar_table(config: MarketConfig) -> NumericEditorTableModel:
	return NumericEditorTableModel.new().setup("Market/Scalars", "Market/Scalars", SCALAR_COLUMNS, [{
		"slot_count": str(config.slot_count),
		"expansion_slot_chance": str(config.expansion_slot_chance),
		"food_slot_chance": str(config.food_slot_chance),
		"discount_min": str(config.discount_min),
		"discount_max": str(config.discount_max),
	}])


func build_reroll_table(config: MarketConfig) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for index in config.reroll_cost_curve.size():
		rows.append({"index": str(index), "value": str(config.reroll_cost_curve[index])})
	return NumericEditorTableModel.new().setup("Market/Reroll Curve", "Market/Reroll Curve", REROLL_COLUMNS, rows)


func build_rarity_weights_table(config: MarketConfig) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for entry in config.rarity_weights_by_market:
		rows.append({
			"market": str(int(entry.get("market", 0))),
			"common": str(int(entry.get("common", 0))),
			"rare": str(int(entry.get("rare", 0))),
			"epic": str(int(entry.get("epic", 0))),
		})
	return NumericEditorTableModel.new().setup("Market/Rarity Weights", "Market/Rarity Weights", RARITY_COLUMNS, rows)


func build_quantity_ranges_table(config: MarketConfig) -> NumericEditorTableModel:
	var keys: Array = config.quantity_ranges.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var rows: Array[Dictionary] = []
	for key in keys:
		var range: Vector2i = config.quantity_ranges[key]
		rows.append({"rarity": String(key), "min": str(range.x), "max": str(range.y)})
	return NumericEditorTableModel.new().setup("Market/Quantity Ranges", "Market/Quantity Ranges", QUANTITY_COLUMNS, rows)


func build_expansion_offers_table(config: MarketConfig) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for entry in config.expansion_offers:
		rows.append({
			"label": str(entry.get("label", "")),
			"price": str(int(entry.get("price", 0))),
			"weight": str(float(entry.get("weight", 0.0))),
			"shape": _parser.format_vector2i_array(entry.get("shape", [])),
		})
	return NumericEditorTableModel.new().setup("Market/Expansion Offers", "Market/Expansion Offers", EXPANSION_COLUMNS, rows)


func apply_scalar_rows(config: MarketConfig, rows: Array[Dictionary]) -> Dictionary:
	if rows.size() != 1:
		return {"ok": false, "error": "Market scalar table must have exactly one row"}
	var row: Dictionary = rows[0]
	var result := _parser.parse_typed_value(str(row.get("slot_count", "")), "int")
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": "slot_count: %s" % result.get("error", "")}
	config.slot_count = result.get("value")
	for field in ["expansion_slot_chance", "food_slot_chance", "discount_min", "discount_max"]:
		result = _parser.parse_typed_value(str(row.get(field, "")), "float")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "%s: %s" % [field, result.get("error", "")]}
		config.set(field, result.get("value"))
	return {"ok": true}


func apply_reroll_rows(config: MarketConfig, rows: Array[Dictionary]) -> Dictionary:
	var next_curve: Array[int] = []
	for index in rows.size():
		var result := _parser.parse_typed_value(str(rows[index].get("value", "")), "int")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "Reroll row %d: %s" % [index + 1, result.get("error", "")]}
		next_curve.append(result.get("value"))
	config.reroll_cost_curve = next_curve
	return {"ok": true}


func apply_rarity_weights_rows(config: MarketConfig, rows: Array[Dictionary]) -> Dictionary:
	var next_rows: Array[Dictionary] = []
	for index in rows.size():
		var next_row: Dictionary = {}
		for key in ["market", "common", "rare", "epic"]:
			var result := _parser.parse_typed_value(str(rows[index].get(key, "")), "int")
			if not bool(result.get("ok", false)):
				return {"ok": false, "error": "Rarity row %d: %s %s" % [index + 1, key, result.get("error", "")]}
			next_row[key] = result.get("value")
		next_rows.append(next_row)
	config.rarity_weights_by_market = next_rows
	return {"ok": true}


func apply_quantity_ranges_rows(config: MarketConfig, rows: Array[Dictionary]) -> Dictionary:
	var next_ranges: Dictionary = {}
	for index in rows.size():
		var row: Dictionary = rows[index]
		var rarity_result := _parser.parse_typed_value(str(row.get("rarity", "")), "string_name")
		var min_result := _parser.parse_typed_value(str(row.get("min", "")), "int")
		var max_result := _parser.parse_typed_value(str(row.get("max", "")), "int")
		if not bool(rarity_result.get("ok", false)):
			return {"ok": false, "error": "Quantity row %d: rarity %s" % [index + 1, rarity_result.get("error", "")]}
		if not bool(min_result.get("ok", false)) or not bool(max_result.get("ok", false)):
			return {"ok": false, "error": "Quantity row %d: min/max must be ints" % [index + 1]}
		next_ranges[rarity_result.get("value")] = Vector2i(min_result.get("value"), max_result.get("value"))
	config.quantity_ranges = next_ranges
	return {"ok": true}


func apply_expansion_offer_rows(config: MarketConfig, rows: Array[Dictionary]) -> Dictionary:
	var next_offers: Array[Dictionary] = []
	for index in rows.size():
		var row: Dictionary = rows[index]
		var price_result := _parser.parse_typed_value(str(row.get("price", "")), "int")
		var weight_result := _parser.parse_typed_value(str(row.get("weight", "")), "float")
		var shape_result := _parser.parse_vector2i_array(str(row.get("shape", "")))
		if not bool(price_result.get("ok", false)):
			return {"ok": false, "error": "Expansion row %d: price %s" % [index + 1, price_result.get("error", "")]}
		if not bool(weight_result.get("ok", false)):
			return {"ok": false, "error": "Expansion row %d: weight %s" % [index + 1, weight_result.get("error", "")]}
		if not bool(shape_result.get("ok", false)):
			return {"ok": false, "error": "Expansion row %d: shape %s" % [index + 1, shape_result.get("error", "")]}
		next_offers.append({
			"label": str(row.get("label", "")),
			"price": price_result.get("value"),
			"weight": weight_result.get("value"),
			"shape": shape_result.get("value", []),
		})
	config.expansion_offers = next_offers
	return {"ok": true}
