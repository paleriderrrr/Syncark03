@tool
extends RefCounted
class_name NumericEditorCharacterTableAdapter


const COLUMNS: Array[Dictionary] = [
	{"key": "id", "title": "ID", "kind": "string_name"},
	{"key": "display_name", "title": "Name", "kind": "string"},
	{"key": "base_hp", "title": "Base HP", "kind": "int"},
	{"key": "base_attack", "title": "Base Attack", "kind": "float"},
	{"key": "attack_interval", "title": "Attack Interval", "kind": "float"},
]

var _parser := NumericEditorTypedValueParser.new()


func build_table(roster: CharacterRoster) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for character in roster.characters:
		rows.append({
			"id": String(character.id),
			"display_name": character.display_name,
			"base_hp": str(character.base_hp),
			"base_attack": str(character.base_attack),
			"attack_interval": str(character.attack_interval),
		})
	return NumericEditorTableModel.new().setup("Character", "Character", COLUMNS, rows)


func apply_rows(roster: CharacterRoster, rows: Array[Dictionary]) -> Dictionary:
	if rows.size() != roster.characters.size():
		return {"ok": false, "error": "Character row count mismatch"}
	for index in rows.size():
		var row: Dictionary = rows[index]
		var character: CharacterDefinition = roster.characters[index]
		var result := _parser.parse_typed_value(str(row.get("id", "")), "string_name")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "Character row %d: id %s" % [index + 1, result.get("error", "")]}
		character.id = result.get("value")
		character.display_name = str(row.get("display_name", ""))

		result = _parser.parse_typed_value(str(row.get("base_hp", "")), "int")
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": "Character row %d: base_hp %s" % [index + 1, result.get("error", "")]}
		character.base_hp = result.get("value")

		for field in ["base_attack", "attack_interval"]:
			result = _parser.parse_typed_value(str(row.get(field, "")), "float")
			if not bool(result.get("ok", false)):
				return {"ok": false, "error": "Character row %d: %s %s" % [index + 1, field, result.get("error", "")]}
			character.set(field, result.get("value"))
	return {"ok": true}
