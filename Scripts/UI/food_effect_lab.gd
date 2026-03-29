extends Control

const CATEGORY_OPTIONS: Array[Dictionary] = [
	{"id": &"all", "label": "All"},
	{"id": &"fruit", "label": "Fruit"},
	{"id": &"dessert", "label": "Dessert"},
	{"id": &"meat", "label": "Meat"},
	{"id": &"drink", "label": "Drink"},
	{"id": &"staple", "label": "Staple"},
	{"id": &"spice", "label": "Spice"},
]

const PRESETS: Array[Dictionary] = [
	{"id": &"selected_single", "label": "Selected Food Solo"},
	{"id": &"fruit_distinct", "label": "3 Distinct Fruit"},
	{"id": &"fruit_duplicate", "label": "3 Same Fruit"},
	{"id": &"lettuce_stack", "label": "Lettuce Under Food"},
	{"id": &"rosemary_spice", "label": "Rosemary + Spice"},
	{"id": &"mixed_category", "label": "Mixed Category Board"},
]

const METRIC_DEFS: Array[Dictionary] = [
	{"key": "current_hp", "label": "Current HP", "decimals": 1},
	{"key": "max_hp", "label": "Max HP", "decimals": 1},
	{"key": "base_hp", "label": "Base HP", "decimals": 1},
	{"key": "base_attack", "label": "Base ATK", "decimals": 1},
	{"key": "attack_bonus", "label": "ATK Bonus", "decimals": 1},
	{"key": "bonus_damage", "label": "Bonus Damage", "decimals": 1},
	{"key": "attack_speed_bonus", "label": "ATK Speed %", "decimals": 1},
	{"key": "effective_interval", "label": "Atk Interval", "decimals": 3},
	{"key": "heal_per_second", "label": "HPS", "decimals": 1},
	{"key": "execute_threshold", "label": "Execute %", "decimals": 1},
	{"key": "retaliate_damage", "label": "Retaliate", "decimals": 1},
	{"key": "enemy_attack_slow", "label": "Enemy Slow %", "decimals": 1},
	{"key": "first_hit_reduction", "label": "First Hit Reduct", "decimals": 2},
	{"key": "crit_chance", "label": "Crit Chance", "decimals": 2},
	{"key": "revive_pct", "label": "Revive %", "decimals": 2},
	{"key": "amber_cancel_chance", "label": "Cancel Chance", "decimals": 2},
	{"key": "frozen_extra_slow_chance", "label": "Extra Slow Chance", "decimals": 2},
	{"key": "forbidden_attack_reduction", "label": "Atk Down Chance", "decimals": 2},
	{"key": "economy_gold_bonus", "label": "Economy Gold", "decimals": 1},
	{"key": "active_bonds", "label": "Active Bonds", "decimals": 0},
	{"key": "fruit_count", "label": "Fruit Types", "decimals": 0},
	{"key": "dessert_count", "label": "Dessert Types", "decimals": 0},
	{"key": "meat_count", "label": "Meat Types", "decimals": 0},
	{"key": "drink_count", "label": "Drink Types", "decimals": 0},
	{"key": "staple_count", "label": "Staple Types", "decimals": 0},
	{"key": "spice_count", "label": "Spice Types", "decimals": 0},
]

@onready var character_option: OptionButton = %CharacterOption
@onready var monster_option: OptionButton = %MonsterOption
@onready var hp_ratio_spin: SpinBox = %HpRatioSpin
@onready var preset_option: OptionButton = %PresetOption
@onready var load_preset_button: Button = %LoadPresetButton
@onready var clear_board_button: Button = %ClearBoardButton
@onready var category_filter_option: OptionButton = %CategoryFilterOption
@onready var search_edit: LineEdit = %SearchEdit
@onready var selected_food_label: Label = %SelectedFoodLabel
@onready var selected_rotation_label: Label = %SelectedRotationLabel
@onready var passive_text_label: RichTextLabel = %PassiveTextLabel
@onready var food_catalog_strip: ItemStrip = %FoodCatalogStrip
@onready var board_view: BentoBoardView = %BentoBoardView
@onready var actual_summary: RichTextLabel = %ActualSummary
@onready var battle_preview_button: Button = %BattlePreviewButton
@onready var battle_summary: RichTextLabel = %BattleSummary
@onready var fill_expected_button: Button = %FillExpectedButton
@onready var clear_expected_button: Button = %ClearExpectedButton
@onready var compare_grid: GridContainer = %CompareGrid

var _lab_state: FoodEffectLabState
var _food_textures: Dictionary = {}
var _selected_food_id: StringName = &""
var _selected_rotation: int = 0
var _metric_rows: Dictionary = {}
var _latest_actual_metrics: Dictionary = {}

func _ready() -> void:
	_lab_state = FoodEffectLabState.new()
	_food_textures = FoodVisuals.build_food_texture_lookup()
	_setup_controls()
	_build_compare_rows()
	_refresh_catalog()
	_refresh_board()
	_refresh_results()

func get_catalog_entry_count() -> int:
	return food_catalog_strip.get_entry_count()

func _setup_controls() -> void:
	for definition_variant in _lab_state.get_character_entries():
		var definition: CharacterDefinition = definition_variant
		character_option.add_item(definition.display_name)
		character_option.set_item_metadata(character_option.item_count - 1, definition.id)
		if definition.id == _lab_state.selected_character_id:
			character_option.select(character_option.item_count - 1)
	for definition_variant in _lab_state.get_monster_entries():
		var definition: MonsterDefinition = definition_variant
		monster_option.add_item(definition.display_name)
		monster_option.set_item_metadata(monster_option.item_count - 1, definition.id)
		if definition.id == _lab_state.selected_monster_id:
			monster_option.select(monster_option.item_count - 1)
	for entry_variant in CATEGORY_OPTIONS:
		var entry: Dictionary = entry_variant
		category_filter_option.add_item(String(entry["label"]))
		category_filter_option.set_item_metadata(category_filter_option.item_count - 1, entry["id"])
	for entry_variant in PRESETS:
		var entry: Dictionary = entry_variant
		preset_option.add_item(String(entry["label"]))
		preset_option.set_item_metadata(preset_option.item_count - 1, entry["id"])
	hp_ratio_spin.value = _lab_state.get_hp_ratio() * 100.0
	character_option.item_selected.connect(_on_character_selected)
	monster_option.item_selected.connect(_on_monster_selected)
	hp_ratio_spin.value_changed.connect(_on_hp_ratio_changed)
	load_preset_button.pressed.connect(_on_load_preset_pressed)
	clear_board_button.pressed.connect(_on_clear_board_pressed)
	category_filter_option.item_selected.connect(func(_index: int) -> void: _refresh_catalog())
	search_edit.text_changed.connect(func(_text: String) -> void: _refresh_catalog())
	food_catalog_strip.entry_clicked.connect(_on_catalog_entry_clicked)
	board_view.cell_clicked.connect(_on_board_cell_clicked)
	board_view.cell_right_clicked.connect(_on_board_cell_right_clicked)
	board_view.board_drop_requested.connect(_on_board_drop_requested)
	battle_preview_button.pressed.connect(_on_battle_preview_pressed)
	fill_expected_button.pressed.connect(_fill_expected_from_actual)
	clear_expected_button.pressed.connect(_clear_expected_values)
	board_view.allow_base_drag = false
	board_view.set_food_textures(_food_textures)
	_update_selected_food_info()

func _build_compare_rows() -> void:
	for child in compare_grid.get_children():
		child.queue_free()
	_metric_rows.clear()
	var headers: Array[String] = ["Metric", "Actual", "Expected", "Delta", "Match"]
	for header in headers:
		var label := Label.new()
		label.text = header
		compare_grid.add_child(label)
	for metric_variant in METRIC_DEFS:
		var metric: Dictionary = metric_variant
		var name_label := Label.new()
		name_label.text = String(metric["label"])
		var actual_label := Label.new()
		actual_label.text = "-"
		var expected_spin := SpinBox.new()
		expected_spin.min_value = -99999.0
		expected_spin.max_value = 99999.0
		expected_spin.step = pow(10.0, -int(metric["decimals"]))
		expected_spin.rounded = false
		expected_spin.value_changed.connect(func(_value: float) -> void: _refresh_compare_grid())
		var delta_label := Label.new()
		delta_label.text = "-"
		var match_label := Label.new()
		match_label.text = "-"
		compare_grid.add_child(name_label)
		compare_grid.add_child(actual_label)
		compare_grid.add_child(expected_spin)
		compare_grid.add_child(delta_label)
		compare_grid.add_child(match_label)
		_metric_rows[metric["key"]] = {
			"actual": actual_label,
			"expected": expected_spin,
			"delta": delta_label,
			"match": match_label,
			"decimals": int(metric["decimals"]),
		}

func _refresh_catalog() -> void:
	var category_filter: StringName = category_filter_option.get_item_metadata(max(category_filter_option.selected, 0))
	var entries: Array[Dictionary] = []
	for entry_variant in _lab_state.get_food_entries(category_filter, search_edit.text):
		var entry: Dictionary = entry_variant.duplicate(true)
		var definition: FoodDefinition = _lab_state.get_food_definition(entry["definition_id"])
		entry["drag_payload"] = {
			"source": &"lab_catalog",
			"definition_id": definition.id,
			"shape_cells": ShapeUtils.rotate_cells(definition.shape_cells, 0),
			"rotation": 0,
		}
		entries.append(entry)
	food_catalog_strip.set_entries(entries, _food_textures)

func _refresh_board() -> void:
	board_view.refresh_board(_lab_state.get_selected_character_state(), [], _lab_state.food_lookup, _food_textures)

func _refresh_results() -> void:
	var actor: Dictionary = CombatEngine.preview_character_actor(_lab_state, _lab_state.selected_character_id)
	var synergy: Dictionary = _lab_state.get_synergy_summary(_lab_state.selected_character_id)
	_latest_actual_metrics = _build_actual_metrics(actor, synergy)
	actual_summary.text = _build_actual_summary_text(actor, synergy)
	_refresh_compare_grid()

func _build_actual_metrics(actor: Dictionary, synergy: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	var active_bonds: int = 0
	for entry_variant in synergy.get("entries", []):
		var entry: Dictionary = entry_variant
		var category_id: StringName = entry.get("category_id", &"")
		counts["%s_count" % String(category_id)] = int(entry.get("count", 0))
		if bool(entry.get("active", false)):
			active_bonds += 1
	return {
		"current_hp": float(actor.get("current_hp", 0.0)),
		"max_hp": float(actor.get("max_hp", 0.0)),
		"base_hp": float(actor.get("base_hp", 0.0)),
		"base_attack": float(actor.get("base_attack", 0.0)),
		"attack_bonus": float(actor.get("attack_bonus", 0.0)),
		"bonus_damage": float(actor.get("bonus_damage", 0.0)),
		"attack_speed_bonus": float(actor.get("attack_speed_bonus", 0.0)),
		"effective_interval": CombatEngine.preview_effective_interval(float(actor.get("base_interval", 1.0)), float(actor.get("attack_speed_bonus", 0.0))),
		"heal_per_second": float(actor.get("heal_per_second", 0.0)),
		"execute_threshold": float(actor.get("execute_threshold", 0.0)),
		"retaliate_damage": float(actor.get("retaliate_damage", 0.0)),
		"enemy_attack_slow": float(actor.get("enemy_attack_slow", 0.0)),
		"first_hit_reduction": float(actor.get("first_hit_reduction", 0.0)),
		"crit_chance": float(actor.get("crit_chance", 0.0)) * 100.0,
		"revive_pct": float(actor.get("revive_pct", 0.0)) * 100.0,
		"amber_cancel_chance": float(actor.get("amber_cancel_chance", 0.0)) * 100.0,
		"frozen_extra_slow_chance": float(actor.get("frozen_extra_slow_chance", 0.0)) * 100.0,
		"forbidden_attack_reduction": float(actor.get("forbidden_attack_reduction", 0.0)) * 100.0,
		"economy_gold_bonus": float(actor.get("economy_gold_bonus", 0.0)),
		"active_bonds": active_bonds,
		"fruit_count": int(counts.get("fruit_count", 0)),
		"dessert_count": int(counts.get("dessert_count", 0)),
		"meat_count": int(counts.get("meat_count", 0)),
		"drink_count": int(counts.get("drink_count", 0)),
		"staple_count": int(counts.get("staple_count", 0)),
		"spice_count": int(counts.get("spice_count", 0)),
		"team_aura_flags": actor.get("team_aura_flags", {}),
	}

func _build_actual_summary_text(actor: Dictionary, synergy: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]Actor Preview[/b]")
	lines.append("HP %.1f / %.1f  |  Base HP %.1f" % [float(actor.get("current_hp", 0.0)), float(actor.get("max_hp", 0.0)), float(actor.get("base_hp", 0.0))])
	lines.append("ATK %.1f + %.1f  |  Interval %.3fs" % [float(actor.get("base_attack", 0.0)), float(actor.get("attack_bonus", 0.0)), float(_latest_actual_metrics.get("effective_interval", 0.0))])
	lines.append("Bonus %.1f  |  ASPD %.1f%%  |  HPS %.1f" % [float(actor.get("bonus_damage", 0.0)), float(actor.get("attack_speed_bonus", 0.0)), float(actor.get("heal_per_second", 0.0))])
	lines.append("Execute %.1f%%  |  Retaliate %.1f  |  Enemy Slow %.1f%%" % [float(actor.get("execute_threshold", 0.0)), float(actor.get("retaliate_damage", 0.0)), float(actor.get("enemy_attack_slow", 0.0))])
	lines.append("Revive %.0f%%  |  Crit %.0f%%  |  Cancel %.0f%%" % [float(actor.get("revive_pct", 0.0)) * 100.0, float(actor.get("crit_chance", 0.0)) * 100.0, float(actor.get("amber_cancel_chance", 0.0)) * 100.0])
	lines.append("")
	lines.append("[b]Synergy[/b]")
	for entry_variant in synergy.get("entries", []):
		var entry: Dictionary = entry_variant
		lines.append("%s: %d type(s)  [%s]" % [
			String(entry.get("category_name", "")),
			int(entry.get("count", 0)),
			"ON" if bool(entry.get("active", false)) else "OFF",
		])
	lines.append("")
	lines.append("[b]Team Aura Flags[/b]")
	var flags: Dictionary = actor.get("team_aura_flags", {})
	if flags.is_empty():
		lines.append("None")
	else:
		for key_variant in flags.keys():
			lines.append("%s: %s" % [String(key_variant), String(flags[key_variant])])
	return "\n".join(lines)

func _refresh_compare_grid() -> void:
	for metric_variant in METRIC_DEFS:
		var metric: Dictionary = metric_variant
		var key: String = String(metric["key"])
		var row: Dictionary = _metric_rows.get(key, {})
		if row.is_empty():
			continue
		var actual_value: float = float(_latest_actual_metrics.get(key, 0.0))
		var decimals: int = int(row["decimals"])
		var expected_spin: SpinBox = row["expected"]
		var delta_value: float = actual_value - expected_spin.value
		(row["actual"] as Label).text = _format_number(actual_value, decimals)
		(row["delta"] as Label).text = _format_number(delta_value, decimals)
		var matched: bool = is_equal_approx(actual_value, expected_spin.value)
		(row["match"] as Label).text = "OK" if matched else "DIFF"

func _on_catalog_entry_clicked(entry: Dictionary) -> void:
	_selected_food_id = entry.get("definition_id", &"")
	_selected_rotation = 0
	_update_selected_food_info()

func _on_board_cell_clicked(cell: Vector2i) -> void:
	if _selected_food_id == &"":
		return
	if _lab_state.place_food(_selected_food_id, cell, _selected_rotation):
		_refresh_board()
		_refresh_results()

func _on_board_cell_right_clicked(cell: Vector2i) -> void:
	if _lab_state.remove_food_at_cell(cell):
		_refresh_board()
		_refresh_results()

func _on_board_drop_requested(anchor_cell: Vector2i, drag_data: Dictionary) -> void:
	match drag_data.get("source", &""):
		&"lab_catalog":
			var definition_id: StringName = drag_data.get("definition_id", &"")
			var rotation: int = int(drag_data.get("rotation", 0))
			if _lab_state.place_food(definition_id, anchor_cell, rotation):
				_refresh_board()
				_refresh_results()
		&"board_food":
			if _lab_state.move_food(drag_data.get("from_cell", Vector2i.ZERO), anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)):
				_refresh_board()
				_refresh_results()

func _on_character_selected(index: int) -> void:
	_lab_state.set_selected_character(character_option.get_item_metadata(index))
	hp_ratio_spin.value = _lab_state.get_hp_ratio() * 100.0
	_refresh_board()
	_refresh_results()

func _on_monster_selected(index: int) -> void:
	_lab_state.set_selected_monster(monster_option.get_item_metadata(index))
	_refresh_results()

func _on_hp_ratio_changed(value: float) -> void:
	_lab_state.set_hp_ratio(value / 100.0)
	_refresh_results()

func _on_clear_board_pressed() -> void:
	_lab_state.clear_selected_board()
	_refresh_board()
	_refresh_results()

func _on_load_preset_pressed() -> void:
	var preset_id: StringName = preset_option.get_item_metadata(max(preset_option.selected, 0))
	_apply_preset(preset_id)

func _apply_preset(preset_id: StringName) -> void:
	_lab_state.clear_selected_board()
	_selected_rotation = 0
	match preset_id:
		&"selected_single":
			if _selected_food_id != &"":
				_lab_state.place_food(_selected_food_id, Vector2i(0, 0), 0)
		&"fruit_distinct":
			_lab_state.place_food(&"red_berry", Vector2i(0, 0), 0)
			_lab_state.place_food(&"lettuce_leaf", Vector2i(2, 0), 0)
			_lab_state.place_food(&"lemon", Vector2i(4, 0), 0)
		&"fruit_duplicate":
			_lab_state.place_food(&"red_berry", Vector2i(0, 0), 0)
			_lab_state.place_food(&"red_berry", Vector2i(1, 0), 0)
			_lab_state.place_food(&"red_berry", Vector2i(2, 0), 0)
		&"lettuce_stack":
			_lab_state.place_food(&"red_berry", Vector2i(1, 0), 0)
			_lab_state.place_food(&"lettuce_leaf", Vector2i(1, 1), 0)
		&"rosemary_spice":
			_lab_state.place_food(&"rosemary_tomato", Vector2i(0, 0), 0)
			_lab_state.place_food(&"red_berry", Vector2i(3, 0), 0)
			_lab_state.place_food(&"lemon", Vector2i(4, 0), 0)
			_lab_state.place_food(&"sesame", Vector2i(2, 0), 0)
		&"mixed_category":
			_lab_state.place_food(&"mixed_feast", Vector2i(0, 0), 0)
			_lab_state.place_food(&"red_berry", Vector2i(4, 0), 0)
			_lab_state.place_food(&"bacon_strip", Vector2i(5, 0), 0)
			_lab_state.place_food(&"iced_black_tea", Vector2i(6, 0), 0)
	_refresh_board()
	_refresh_results()
	_update_selected_food_info()

func _on_battle_preview_pressed() -> void:
	var report: Dictionary = _lab_state.build_battle_preview()
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % String(report.get("title", "Battle Preview")))
	lines.append("Monster: %s" % String(report.get("monster_name", "Unknown")))
	lines.append("Result: %s  |  Duration: %.1fs  |  Bonus Gold: %d" % [
		String(report.get("result", "")).to_upper(),
		float(report.get("duration", 0.0)),
		int(report.get("bonus_gold", 0)),
	])
	lines.append("Monster HP: %.1f / %.1f" % [float(report.get("monster_hp", 0.0)), float(report.get("monster_max_hp", 0.0))])
	lines.append("")
	lines.append("[b]Recent Log[/b]")
	var log_lines: PackedStringArray = report.get("log", PackedStringArray())
	for line_variant in log_lines.slice(max(log_lines.size() - 8, 0), log_lines.size()):
		lines.append(String(line_variant))
	battle_summary.text = "\n".join(lines)

func _fill_expected_from_actual() -> void:
	for metric_variant in METRIC_DEFS:
		var key: String = String(metric_variant["key"])
		var row: Dictionary = _metric_rows.get(key, {})
		if row.is_empty():
			continue
		(row["expected"] as SpinBox).value = float(_latest_actual_metrics.get(key, 0.0))
	_refresh_compare_grid()

func _clear_expected_values() -> void:
	for row_variant in _metric_rows.values():
		var row: Dictionary = row_variant
		(row["expected"] as SpinBox).value = 0.0
	_refresh_compare_grid()

func _update_selected_food_info() -> void:
	if _selected_food_id == &"":
		selected_food_label.text = "Selected Food: None"
		selected_rotation_label.text = "Rotation: 0"
		passive_text_label.text = "Select a food from the catalog strip, then click or drag onto the board."
		return
	var definition: FoodDefinition = _lab_state.get_food_definition(_selected_food_id)
	selected_food_label.text = "Selected Food: %s" % definition.display_name
	selected_rotation_label.text = "Rotation: %d" % _selected_rotation
	passive_text_label.text = definition.passive_text

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if _selected_food_id != &"":
			_selected_rotation = (_selected_rotation + 1) % 4
			_update_selected_food_info()
			get_viewport().set_input_as_handled()

func _format_number(value: float, decimals: int) -> String:
	return ("%0." + str(decimals) + "f") % value
