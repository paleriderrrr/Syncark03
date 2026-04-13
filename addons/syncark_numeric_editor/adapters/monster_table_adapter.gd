@tool
extends RefCounted
class_name NumericEditorMonsterTableAdapter


const COLUMNS: Array[Dictionary] = [
	{"key": "id", "title": "ID", "kind": "string_name"},
	{"key": "display_name", "title": "Name", "kind": "string"},
	{"key": "category", "title": "Category", "kind": "string_name"},
	{"key": "base_hp", "title": "Base HP", "kind": "int"},
	{"key": "base_attack", "title": "Base Attack", "kind": "float"},
	{"key": "attack_interval", "title": "Attack Interval", "kind": "float"},
	{"key": "skill_summary", "title": "Skill Summary", "kind": "string"},
	{"key": "target_rule", "title": "Target Rule", "kind": "string_name"},
]

var _parser := NumericEditorTypedValueParser.new()


func build_table(roster: MonsterRoster) -> NumericEditorTableModel:
	var rows: Array[Dictionary] = []
	for monster in roster.monsters:
		rows.append({
			"id": String(monster.id),
			"display_name": monster.display_name,
			"category": String(monster.category),
			"base_hp": str(monster.base_hp),
			"base_attack": str(monster.base_attack),
			"attack_interval": str(monster.attack_interval),
			"skill_summary": monster.skill_summary,
			"target_rule": String(monster.target_rule),
		})
	return NumericEditorTableModel.new().setup("Monster", "Monster", COLUMNS, rows)


func apply_rows(roster: MonsterRoster, rows: Array[Dictionary]) -> Dictionary:
	if rows.size() != roster.monsters.size():
		return {"ok": false, "error": "Monster row count mismatch"}
	for index in rows.size():
		var row: Dictionary = rows[index]
		var monster: MonsterDefinition = roster.monsters[index]
		for field in ["id", "category", "target_rule"]:
			var result := _parser.parse_typed_value(str(row.get(field, "")), "string_name")
			if not bool(result.get("ok", false)):
				return {"ok": false, "error": "Monster row %d: %s %s" % [index + 1, field, result.get("error", "")]}
			monster.set(field, result.get("value"))
		monster.display_name = str(row.get("display_name", ""))
		monster.skill_summary = str(row.get("skill_summary", ""))

		var hp_result := _parser.parse_typed_value(str(row.get("base_hp", "")), "int")
		if not bool(hp_result.get("ok", false)):
			return {"ok": false, "error": "Monster row %d: base_hp %s" % [index + 1, hp_result.get("error", "")]}
		monster.base_hp = hp_result.get("value")

		for field in ["base_attack", "attack_interval"]:
			var result := _parser.parse_typed_value(str(row.get(field, "")), "float")
			if not bool(result.get("ok", false)):
				return {"ok": false, "error": "Monster row %d: %s %s" % [index + 1, field, result.get("error", "")]}
			monster.set(field, result.get("value"))
	return {"ok": true}
