@tool
extends RefCounted
class_name NumericEditorTypedValueParser


var _vector_pattern: RegEx


func _init() -> void:
	_vector_pattern = RegEx.new()
	_vector_pattern.compile("\\((-?\\d+)\\s*,\\s*(-?\\d+)\\)")


func parse_typed_value(raw: String, kind: String) -> Dictionary:
	var trimmed := raw.strip_edges()
	match kind:
		"int":
			if not trimmed.is_valid_int():
				return {"ok": false, "error": "Expected int"}
			return {"ok": true, "value": int(trimmed)}
		"float":
			if not trimmed.is_valid_float():
				return {"ok": false, "error": "Expected float"}
			return {"ok": true, "value": float(trimmed)}
		"string_name":
			return {"ok": true, "value": StringName(trimmed)}
		"string":
			return {"ok": true, "value": raw}
		_:
			return {"ok": false, "error": "Unsupported parse kind: %s" % kind}


func parse_string_name_list(raw: String) -> Dictionary:
	var trimmed := raw.strip_edges()
	if trimmed.is_empty():
		return {"ok": true, "value": []}
	var values: Array[StringName] = []
	for part in trimmed.split(",", false):
		values.append(StringName(part.strip_edges()))
	return {"ok": true, "value": values}


func parse_vector2i(raw: String) -> Dictionary:
	var match := _vector_pattern.search(raw.strip_edges())
	if match == null:
		return {"ok": false, "error": "Expected (x,y)"}
	return {
		"ok": true,
		"value": Vector2i(int(match.get_string(1)), int(match.get_string(2)))
	}


func parse_vector2i_array(raw: String) -> Dictionary:
	var trimmed := raw.strip_edges()
	if not trimmed.begins_with("[") or not trimmed.ends_with("]"):
		return {"ok": false, "error": "Expected [..]"}
	var body := trimmed.substr(1, trimmed.length() - 2)
	if body.strip_edges().is_empty():
		return {"ok": true, "value": []}
	var matches := _vector_pattern.search_all(body)
	var values: Array[Vector2i] = []
	for match in matches:
		values.append(Vector2i(int(match.get_string(1)), int(match.get_string(2))))
	if values.is_empty():
		return {"ok": false, "error": "Expected Vector2i tuple list"}
	return {"ok": true, "value": values}


func format_string_name_list(values: Array[StringName]) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(String(value))
	return ",".join(parts)


func format_vector2i(value: Vector2i) -> String:
	return "(%d,%d)" % [value.x, value.y]


func format_vector2i_array(values: Array[Vector2i]) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(format_vector2i(value))
	return "[%s]" % ",".join(parts)
