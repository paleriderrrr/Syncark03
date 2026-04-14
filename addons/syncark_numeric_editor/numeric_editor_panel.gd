@tool
extends VBoxContainer


const PATHS := preload("res://addons/syncark_numeric_editor/resource_paths.gd")
const FOOD_ADAPTER_SCRIPT := preload("res://addons/syncark_numeric_editor/adapters/food_table_adapter.gd")
const CHARACTER_ADAPTER_SCRIPT := preload("res://addons/syncark_numeric_editor/adapters/character_table_adapter.gd")
const MONSTER_ADAPTER_SCRIPT := preload("res://addons/syncark_numeric_editor/adapters/monster_table_adapter.gd")
const MARKET_ADAPTER_SCRIPT := preload("res://addons/syncark_numeric_editor/adapters/market_table_adapter.gd")
const STAGE_FLOW_ADAPTER_SCRIPT := preload("res://addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd")


@onready var _dirty_label: Label = %DirtyLabel
@onready var _status_label: Label = %StatusLabel
@onready var _tab_container: TabContainer = %TabContainer
@onready var _refresh_button: Button = %RefreshButton
@onready var _save_current_button: Button = %SaveCurrentButton
@onready var _save_all_button: Button = %SaveAllButton

var _food_adapter := FOOD_ADAPTER_SCRIPT.new()
var _character_adapter := CHARACTER_ADAPTER_SCRIPT.new()
var _monster_adapter := MONSTER_ADAPTER_SCRIPT.new()
var _market_adapter := MARKET_ADAPTER_SCRIPT.new()
var _stage_flow_adapter := STAGE_FLOW_ADAPTER_SCRIPT.new()

var _resources: Dictionary = {}
var _table_entries: Dictionary = {}
var _tree_to_key: Dictionary = {}


func _ready() -> void:
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_save_current_button.pressed.connect(_on_save_current_pressed)
	_save_all_button.pressed.connect(_on_save_all_pressed)
	refresh_all_tables()


func refresh_all_tables() -> void:
	var load_result := _load_resources()
	if not bool(load_result.get("ok", false)):
		_set_status(str(load_result.get("error", "Resource load failed")), true)
		return
	_rebuild_tabs()
	_set_status("Tables loaded.", false)
	_update_dirty_label()


func save_current_tab() -> Dictionary:
	var key := _current_table_key()
	if key.is_empty():
		return {"ok": false, "error": "No active table"}
	return _save_table(key)


func save_all_tabs() -> Dictionary:
	for key in _table_entries.keys():
		var entry: Dictionary = _table_entries[key]
		if bool(entry.get("dirty", false)):
			var result := _save_table(key)
			if not bool(result.get("ok", false)):
				return result
	_set_status("All dirty tables saved.", false)
	return {"ok": true}


func debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in _table_entries.keys():
		snapshot[key] = (_table_entries[key] as Dictionary).get("rows", []).duplicate(true)
	return snapshot


func _load_resources() -> Dictionary:
	_resources.clear()
	var path_map := {
		"food": PATHS.FOOD_CATALOG,
		"character": PATHS.CHARACTER_ROSTER,
		"monster": PATHS.MONSTER_ROSTER,
		"market": PATHS.MARKET_CONFIG,
		"stage_flow": PATHS.STAGE_FLOW_CONFIG,
	}
	for key in path_map.keys():
		var resource := load(path_map[key])
		if resource == null:
			return {"ok": false, "error": "Failed to load %s" % path_map[key]}
		_resources[key] = resource
	return {"ok": true}


func _rebuild_tabs() -> void:
	_table_entries.clear()
	_tree_to_key.clear()
	for child in _tab_container.get_children():
		child.queue_free()
	_add_table(_food_adapter.build_table(_resources["food"]), _save_food_table)
	_add_table(_character_adapter.build_table(_resources["character"]), _save_character_table)
	_add_table(_monster_adapter.build_table(_resources["monster"]), _save_monster_table)
	_add_table(_market_adapter.build_scalar_table(_resources["market"]), _save_market_scalar_table)
	_add_table(_market_adapter.build_reroll_table(_resources["market"]), _save_market_reroll_table)
	_add_table(_market_adapter.build_rarity_weights_table(_resources["market"]), _save_market_rarity_table)
	_add_table(_market_adapter.build_quantity_ranges_table(_resources["market"]), _save_market_quantity_table)
	_add_table(_market_adapter.build_expansion_offers_table(_resources["market"]), _save_market_expansion_table)
	_add_table(_stage_flow_adapter.build_scalar_table(_resources["stage_flow"]), _save_stage_scalar_table)
	_add_table(_stage_flow_adapter.build_route_table(_resources["stage_flow"]), _save_stage_route_table)
	_add_table(_stage_flow_adapter.build_difficulty_table(_resources["stage_flow"]), _save_stage_difficulty_table)


func _add_table(model: NumericEditorTableModel, save_callable: Callable) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.name = model.title.replace("/", " ")

	var info := Label.new()
	info.text = model.title
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrapper.add_child(info)

	var tree := Tree.new()
	tree.columns = model.columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.size_flags_horizontal = SIZE_EXPAND_FILL
	tree.item_edited.connect(_on_tree_item_edited.bind(tree))
	wrapper.add_child(tree)
	_tab_container.add_child(wrapper)

	for column_index in model.columns.size():
		var column: Dictionary = model.columns[column_index]
		var title := str(column.get("title", column.get("key", "")))
		tree.set_column_title(column_index, title)
		tree.set_column_title_alignment(column_index, HORIZONTAL_ALIGNMENT_LEFT)
		tree.set_column_expand(column_index, true)
		tree.set_column_custom_minimum_width(column_index, _preferred_column_width(column))

	var root := tree.create_item()
	for row in model.rows:
		var item := tree.create_item(root)
		for column_index in model.columns.size():
			var column: Dictionary = model.columns[column_index]
			var cell_text := str(row.get(column["key"], ""))
			item.set_text(column_index, cell_text)
			item.set_tooltip_text(column_index, cell_text)
			item.set_editable(column_index, bool(column.get("editable", true)) and model.editable)

	_table_entries[model.key] = {
		"model": model,
		"rows": model.duplicate_rows(),
		"tree": tree,
		"save": save_callable,
		"dirty": false,
	}
	_tree_to_key[tree] = model.key


func _on_tree_item_edited(tree: Tree) -> void:
	var key := str(_tree_to_key.get(tree, ""))
	if key.is_empty():
		return
	var edited: TreeItem = tree.get_edited()
	if edited == null:
		return
	var entry: Dictionary = _table_entries[key]
	var rows: Array[Dictionary] = entry["rows"]
	var row_index := _tree_item_index(edited)
	if row_index < 0 or row_index >= rows.size():
		return
	var model: NumericEditorTableModel = entry["model"]
	var column_index := tree.get_edited_column()
	var column_key := str(model.columns[column_index]["key"])
	rows[row_index][column_key] = edited.get_text(column_index)
	entry["rows"] = rows
	entry["dirty"] = true
	_table_entries[key] = entry
	_update_dirty_label()
	_set_status("Unsaved changes in %s" % key, false)


func _tree_item_index(item: TreeItem) -> int:
	var index := 0
	var cursor := item.get_prev()
	while cursor != null:
		index += 1
		cursor = cursor.get_prev()
	return index


func _current_table_key() -> String:
	var current := _tab_container.get_current_tab_control()
	if current == null:
		return ""
	for key in _table_entries.keys():
		var tree: Tree = (_table_entries[key] as Dictionary)["tree"]
		if tree.get_parent() == current:
			return key
	return ""


func _save_table(key: String) -> Dictionary:
	var entry: Dictionary = _table_entries.get(key, {})
	if entry.is_empty():
		return {"ok": false, "error": "Unknown table: %s" % key}
	var save_callable: Callable = entry["save"]
	var result: Dictionary = save_callable.call(entry["rows"])
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Save failed")), true)
		return result
	entry["dirty"] = false
	_table_entries[key] = entry
	_update_dirty_label()
	_set_status("Saved %s" % key, false)
	return {"ok": true}


func _save_food_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _food_adapter.apply_rows(_resources["food"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["food"], PATHS.FOOD_CATALOG)


func _save_character_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _character_adapter.apply_rows(_resources["character"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["character"], PATHS.CHARACTER_ROSTER)


func _save_monster_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _monster_adapter.apply_rows(_resources["monster"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["monster"], PATHS.MONSTER_ROSTER)


func _save_market_scalar_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _market_adapter.apply_scalar_rows(_resources["market"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["market"], PATHS.MARKET_CONFIG)


func _save_market_reroll_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _market_adapter.apply_reroll_rows(_resources["market"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["market"], PATHS.MARKET_CONFIG)


func _save_market_rarity_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _market_adapter.apply_rarity_weights_rows(_resources["market"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["market"], PATHS.MARKET_CONFIG)


func _save_market_quantity_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _market_adapter.apply_quantity_ranges_rows(_resources["market"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["market"], PATHS.MARKET_CONFIG)


func _save_market_expansion_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _market_adapter.apply_expansion_offer_rows(_resources["market"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["market"], PATHS.MARKET_CONFIG)


func _save_stage_scalar_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _stage_flow_adapter.apply_scalar_rows(_resources["stage_flow"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["stage_flow"], PATHS.STAGE_FLOW_CONFIG)


func _save_stage_route_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _stage_flow_adapter.apply_route_rows(_resources["stage_flow"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["stage_flow"], PATHS.STAGE_FLOW_CONFIG)


func _save_stage_difficulty_table(rows: Array[Dictionary]) -> Dictionary:
	var apply_result := _stage_flow_adapter.apply_difficulty_rows(_resources["stage_flow"], rows)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	return _save_resource(_resources["stage_flow"], PATHS.STAGE_FLOW_CONFIG)


func _save_resource(resource: Resource, path: String) -> Dictionary:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		return {"ok": false, "error": "ResourceSaver failed for %s with code %d" % [path, error]}
	return {"ok": true}


func _update_dirty_label() -> void:
	var dirty_count := 0
	for key in _table_entries.keys():
		if bool((_table_entries[key] as Dictionary).get("dirty", false)):
			dirty_count += 1
	_dirty_label.text = "Dirty tables: %d" % dirty_count


func _set_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.modulate = Color(0.85, 0.25, 0.25) if is_error else Color(0.85, 0.85, 0.85)


func _preferred_column_width(column: Dictionary) -> int:
	var key := str(column.get("key", ""))
	match key:
		"id":
			return 180
		"display_name":
			return 220
		"category", "rarity", "target_rule", "node_type":
			return 140
		"hybrid_categories":
			return 220
		"skill_summary", "passive_text":
			return 360
		"shape", "shape_cells":
			return 240
		"label":
			return 160
		_:
			return 110


func _on_refresh_pressed() -> void:
	refresh_all_tables()


func _on_save_current_pressed() -> void:
	save_current_tab()


func _on_save_all_pressed() -> void:
	save_all_tabs()
