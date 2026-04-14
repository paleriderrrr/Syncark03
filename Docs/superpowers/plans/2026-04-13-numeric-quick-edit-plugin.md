# Numeric Quick Edit Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot editor plugin that loads the project's balance resources into spreadsheet-style tables, validates edits, and saves changes back into the existing `.tres` files.

**Architecture:** The plugin is split into three layers: typed resource adapters, a reusable table/editor panel, and the `EditorPlugin` entrypoint that mounts the panel inside the Godot editor. Validation lives beside the adapters so the UI only deals with normalized table state and explicit save failures.

**Tech Stack:** Godot 4 GDScript, `EditorPlugin`, `ResourceLoader`/`ResourceSaver`, existing SceneTree test runners in `Scripts/Tests`

---

## File Structure

- Create: `addons/syncark_numeric_editor/plugin.cfg`
- Create: `addons/syncark_numeric_editor/plugin.gd`
- Create: `addons/syncark_numeric_editor/numeric_editor_panel.gd`
- Create: `addons/syncark_numeric_editor/numeric_editor_panel.tscn`
- Create: `addons/syncark_numeric_editor/table_model.gd`
- Create: `addons/syncark_numeric_editor/typed_value_parser.gd`
- Create: `addons/syncark_numeric_editor/resource_paths.gd`
- Create: `addons/syncark_numeric_editor/adapters/food_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/character_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/monster_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/market_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd`
- Create: `Scripts/Tests/numeric_editor_adapter_runner.gd`
- Create: `Scripts/Tests/numeric_editor_plugin_runner.gd`
- Modify: `project.godot`

### Task 1: Add adapter round-trip test harness

**Files:**
- Create: `Scripts/Tests/numeric_editor_adapter_runner.gd`
- Create: `addons/syncark_numeric_editor/table_model.gd`
- Create: `addons/syncark_numeric_editor/typed_value_parser.gd`
- Create: `addons/syncark_numeric_editor/resource_paths.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

func _initialize():
    call_deferred("_run")

func _run():
    var parser_script := load("res://addons/syncark_numeric_editor/typed_value_parser.gd")
    var table_model_script := load("res://addons/syncark_numeric_editor/table_model.gd")
    if parser_script == null or table_model_script == null:
        printerr("NUMERIC_EDITOR_ADAPTER_FAIL: missing core scripts")
        quit(1)
        return

    var parser = parser_script.new()
    var int_result: Dictionary = parser.parse_typed_value("12", "int")
    if not int_result.get("ok", false) or int_result.get("value", -1) != 12:
        printerr("NUMERIC_EDITOR_ADAPTER_FAIL: int parse")
        quit(1)
        return

    var float_result: Dictionary = parser.parse_typed_value("1.25", "float")
    if not float_result.get("ok", false) or abs(float_result.get("value", 0.0) - 1.25) > 0.001:
        printerr("NUMERIC_EDITOR_ADAPTER_FAIL: float parse")
        quit(1)
        return

    var vector_result: Dictionary = parser.parse_vector2i_array("[(0,0),(1,0)]")
    if not vector_result.get("ok", false) or vector_result.get("value", []).size() != 2:
        printerr("NUMERIC_EDITOR_ADAPTER_FAIL: vector parse")
        quit(1)
        return

    var invalid_result: Dictionary = parser.parse_vector2i_array("[broken]")
    if invalid_result.get("ok", true):
        printerr("NUMERIC_EDITOR_ADAPTER_FAIL: invalid vector accepted")
        quit(1)
        return

    print("NUMERIC_EDITOR_ADAPTER_PASS")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_adapter_runner.gd`
Expected: FAIL with `missing core scripts`

- [ ] **Step 3: Write minimal implementation**

```gdscript
# res://addons/syncark_numeric_editor/table_model.gd
extends RefCounted
class_name NumericEditorTableModel

var columns: Array[StringName] = []
var rows: Array[Dictionary] = []

func setup(p_columns: Array[StringName], p_rows: Array[Dictionary]) -> NumericEditorTableModel:
    columns = p_columns.duplicate()
    rows = p_rows.duplicate(true)
    return self
```

```gdscript
# res://addons/syncark_numeric_editor/typed_value_parser.gd
extends RefCounted
class_name NumericEditorTypedValueParser

func parse_typed_value(raw: String, kind: String) -> Dictionary:
    match kind:
        "int":
            if not raw.is_valid_int():
                return {"ok": false, "error": "Expected int"}
            return {"ok": true, "value": int(raw)}
        "float":
            if not raw.is_valid_float():
                return {"ok": false, "error": "Expected float"}
            return {"ok": true, "value": float(raw)}
        _:
            return {"ok": true, "value": raw}

func parse_vector2i_array(raw: String) -> Dictionary:
    var trimmed := raw.strip_edges()
    if not trimmed.begins_with("[") or not trimmed.ends_with("]"):
        return {"ok": false, "error": "Expected [..]"}
    var body := trimmed.substr(1, trimmed.length() - 2).strip_edges()
    if body.is_empty():
        return {"ok": true, "value": []}
    var matcher := RegEx.new()
    matcher.compile("\\((-?\\d+)\\s*,\\s*(-?\\d+)\\)")
    var results: Array[Vector2i] = []
    for match in matcher.search_all(body):
        results.append(Vector2i(int(match.get_string(1)), int(match.get_string(2))))
    if results.is_empty():
        return {"ok": false, "error": "Expected Vector2i tuple list"}
    return {"ok": true, "value": results}
```

```gdscript
# res://addons/syncark_numeric_editor/resource_paths.gd
extends RefCounted
class_name NumericEditorResourcePaths

const FOOD_CATALOG := "res://Data/Foods/food_catalog.tres"
const CHARACTER_ROSTER := "res://Data/Characters/character_roster.tres"
const MONSTER_ROSTER := "res://Data/Monsters/monster_roster.tres"
const MARKET_CONFIG := "res://Data/Configs/market_config.tres"
const STAGE_FLOW_CONFIG := "res://Data/Configs/stage_flow_config.tres"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_adapter_runner.gd`
Expected: PASS with `NUMERIC_EDITOR_ADAPTER_PASS`

- [ ] **Step 5: Commit**

```bash
git add Scripts/Tests/numeric_editor_adapter_runner.gd addons/syncark_numeric_editor/table_model.gd addons/syncark_numeric_editor/typed_value_parser.gd addons/syncark_numeric_editor/resource_paths.gd
git commit -m "Add numeric editor parser primitives"
```

### Task 2: Add resource adapters with round-trip coverage

**Files:**
- Modify: `Scripts/Tests/numeric_editor_adapter_runner.gd`
- Create: `addons/syncark_numeric_editor/adapters/food_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/character_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/monster_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/market_table_adapter.gd`
- Create: `addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
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

var first_food: Dictionary = food_table.rows[0].duplicate(true)
first_food["gold_value"] = "99"
var food_write := food_adapter.apply_rows(food_catalog, [first_food])
if not food_write.get("ok", false):
    printerr("NUMERIC_EDITOR_ADAPTER_FAIL: food apply")
    quit(1)
    return

var market_adapter = market_adapter_script.new()
var market_config := load("res://Data/Configs/market_config.tres")
var quantity_table: NumericEditorTableModel = market_adapter.build_quantity_ranges_table(market_config)
if quantity_table.rows.is_empty():
    printerr("NUMERIC_EDITOR_ADAPTER_FAIL: empty quantity table")
    quit(1)
    return

var bad_quantity_rows := quantity_table.rows.duplicate(true)
bad_quantity_rows[0]["min"] = "bad"
var bad_quantity_apply := market_adapter.apply_quantity_ranges_rows(market_config, bad_quantity_rows)
if bad_quantity_apply.get("ok", true):
    printerr("NUMERIC_EDITOR_ADAPTER_FAIL: invalid quantity row accepted")
    quit(1)
    return

var stage_adapter = stage_adapter_script.new()
var stage_config := load("res://Data/Configs/stage_flow_config.tres")
var difficulty_table: NumericEditorTableModel = stage_adapter.build_difficulty_table(stage_config)
if difficulty_table.rows.is_empty():
    printerr("NUMERIC_EDITOR_ADAPTER_FAIL: empty stage difficulty table")
    quit(1)
    return

print("NUMERIC_EDITOR_ADAPTER_PASS")
quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_adapter_runner.gd`
Expected: FAIL with `missing adapter scripts`

- [ ] **Step 3: Write minimal implementation**

```gdscript
# res://addons/syncark_numeric_editor/adapters/food_table_adapter.gd
extends RefCounted
class_name NumericEditorFoodTableAdapter

const COLUMNS: Array[StringName] = [
    &"id", &"display_name", &"category", &"hybrid_categories", &"rarity",
    &"gold_value", &"hp_bonus", &"attack_bonus", &"bonus_damage",
    &"attack_speed_percent", &"heal_per_second", &"execute_threshold_percent",
    &"passive_text", &"shape_cells"
]

var _parser := NumericEditorTypedValueParser.new()

func build_table(catalog: FoodCatalog) -> NumericEditorTableModel:
    var rows: Array[Dictionary] = []
    for food in catalog.foods:
        rows.append({
            "id": String(food.id),
            "display_name": food.display_name,
            "category": String(food.category),
            "hybrid_categories": ",".join(food.hybrid_categories),
            "rarity": String(food.rarity),
            "gold_value": str(food.gold_value),
            "hp_bonus": str(food.hp_bonus),
            "attack_bonus": str(food.attack_bonus),
            "bonus_damage": str(food.bonus_damage),
            "attack_speed_percent": str(food.attack_speed_percent),
            "heal_per_second": str(food.heal_per_second),
            "execute_threshold_percent": str(food.execute_threshold_percent),
            "passive_text": food.passive_text,
            "shape_cells": _format_vector2i_array(food.shape_cells),
        })
    return NumericEditorTableModel.new().setup(COLUMNS, rows)

func apply_rows(catalog: FoodCatalog, rows: Array[Dictionary]) -> Dictionary:
    if rows.size() != catalog.foods.size():
        return {"ok": false, "error": "Food row count mismatch"}
    for index in rows.size():
        var row := rows[index]
        var food := catalog.foods[index]
        var gold_result := _parser.parse_typed_value(str(row.get("gold_value", "")), "int")
        if not gold_result.ok:
            return {"ok": false, "error": gold_result.error}
        food.gold_value = gold_result.value
    return {"ok": true}

func _format_vector2i_array(values: Array[Vector2i]) -> String:
    var parts: Array[String] = []
    for value in values:
        parts.append("(%d,%d)" % [value.x, value.y])
    return "[%s]" % ",".join(parts)
```

```gdscript
# res://addons/syncark_numeric_editor/adapters/market_table_adapter.gd
extends RefCounted
class_name NumericEditorMarketTableAdapter

var _parser := NumericEditorTypedValueParser.new()

func build_quantity_ranges_table(config: MarketConfig) -> NumericEditorTableModel:
    var rows: Array[Dictionary] = []
    for key in config.quantity_ranges.keys():
        var value: Vector2i = config.quantity_ranges[key]
        rows.append({"rarity": String(key), "min": str(value.x), "max": str(value.y)})
    return NumericEditorTableModel.new().setup([&"rarity", &"min", &"max"], rows)

func apply_quantity_ranges_rows(config: MarketConfig, rows: Array[Dictionary]) -> Dictionary:
    var next_ranges := {}
    for row in rows:
        var min_result := _parser.parse_typed_value(str(row.get("min", "")), "int")
        var max_result := _parser.parse_typed_value(str(row.get("max", "")), "int")
        if not min_result.ok or not max_result.ok:
            return {"ok": false, "error": "Quantity range must use ints"}
        next_ranges[StringName(str(row.get("rarity", "")))] = Vector2i(min_result.value, max_result.value)
    config.quantity_ranges = next_ranges
    return {"ok": true}
```

```gdscript
# res://addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd
extends RefCounted
class_name NumericEditorStageFlowTableAdapter

func build_difficulty_table(config: StageFlowConfig) -> NumericEditorTableModel:
    var row_count := min(
        config.normal_battle_reward_gold.size(),
        config.normal_drop_value_curve.size(),
        config.monster_hp_multiplier_curve.size(),
        config.monster_attack_multiplier_curve.size()
    )
    var rows: Array[Dictionary] = []
    for index in row_count:
        rows.append({
            "battle_index": str(index),
            "normal_battle_reward_gold": str(config.normal_battle_reward_gold[index]),
            "normal_drop_value_curve": str(config.normal_drop_value_curve[index]),
            "monster_hp_multiplier_curve": str(config.monster_hp_multiplier_curve[index]),
            "monster_attack_multiplier_curve": str(config.monster_attack_multiplier_curve[index]),
        })
    return NumericEditorTableModel.new().setup([
        &"battle_index",
        &"normal_battle_reward_gold",
        &"normal_drop_value_curve",
        &"monster_hp_multiplier_curve",
        &"monster_attack_multiplier_curve"
    ], rows)
```

```gdscript
# res://addons/syncark_numeric_editor/adapters/character_table_adapter.gd
extends RefCounted
class_name NumericEditorCharacterTableAdapter
```

```gdscript
# res://addons/syncark_numeric_editor/adapters/monster_table_adapter.gd
extends RefCounted
class_name NumericEditorMonsterTableAdapter
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_adapter_runner.gd`
Expected: PASS with `NUMERIC_EDITOR_ADAPTER_PASS`

- [ ] **Step 5: Commit**

```bash
git add Scripts/Tests/numeric_editor_adapter_runner.gd addons/syncark_numeric_editor/adapters
git commit -m "Add numeric editor resource adapters"
```

### Task 3: Add editor plugin registration test and minimal plugin shell

**Files:**
- Create: `Scripts/Tests/numeric_editor_plugin_runner.gd`
- Create: `addons/syncark_numeric_editor/plugin.cfg`
- Create: `addons/syncark_numeric_editor/plugin.gd`
- Create: `addons/syncark_numeric_editor/numeric_editor_panel.gd`
- Create: `addons/syncark_numeric_editor/numeric_editor_panel.tscn`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

func _initialize():
    call_deferred("_run")

func _run():
    var panel_scene := load("res://addons/syncark_numeric_editor/numeric_editor_panel.tscn") as PackedScene
    var plugin_script := load("res://addons/syncark_numeric_editor/plugin.gd")
    if panel_scene == null or plugin_script == null:
        printerr("NUMERIC_EDITOR_PLUGIN_FAIL: missing plugin shell")
        quit(1)
        return

    var panel := panel_scene.instantiate()
    if panel == null or not panel.has_method("refresh_all_tables"):
        printerr("NUMERIC_EDITOR_PLUGIN_FAIL: panel missing refresh api")
        quit(1)
        return

    print("NUMERIC_EDITOR_PLUGIN_PASS")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_plugin_runner.gd`
Expected: FAIL with `missing plugin shell`

- [ ] **Step 3: Write minimal implementation**

```ini
; res://addons/syncark_numeric_editor/plugin.cfg
[plugin]
name="Syncark Numeric Editor"
description="Spreadsheet-style balance editor"
author="Codex"
version="0.1.0"
script="res://addons/syncark_numeric_editor/plugin.gd"
```

```gdscript
# res://addons/syncark_numeric_editor/plugin.gd
@tool
extends EditorPlugin

var _panel: Control

func _enter_tree() -> void:
    var scene := load("res://addons/syncark_numeric_editor/numeric_editor_panel.tscn") as PackedScene
    _panel = scene.instantiate()
    add_control_to_bottom_panel(_panel, "Numeric Editor")

func _exit_tree() -> void:
    if _panel != null:
        remove_control_from_bottom_panel(_panel)
        _panel.queue_free()
        _panel = null
```

```gdscript
# res://addons/syncark_numeric_editor/numeric_editor_panel.gd
@tool
extends VBoxContainer

func refresh_all_tables() -> void:
    pass
```

```text
; res://addons/syncark_numeric_editor/numeric_editor_panel.tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://addons/syncark_numeric_editor/numeric_editor_panel.gd" id="1"]
[node name="NumericEditorPanel" type="VBoxContainer"]
script = ExtResource("1")
```

```ini
; project.godot
[editor_plugins]
enabled=PackedStringArray("res://addons/syncark_numeric_editor/plugin.cfg")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_plugin_runner.gd`
Expected: PASS with `NUMERIC_EDITOR_PLUGIN_PASS`

- [ ] **Step 5: Commit**

```bash
git add Scripts/Tests/numeric_editor_plugin_runner.gd addons/syncark_numeric_editor/plugin.cfg addons/syncark_numeric_editor/plugin.gd addons/syncark_numeric_editor/numeric_editor_panel.gd addons/syncark_numeric_editor/numeric_editor_panel.tscn project.godot
git commit -m "Register numeric editor plugin shell"
```

### Task 4: Build the editable table UI and save flows

**Files:**
- Modify: `addons/syncark_numeric_editor/numeric_editor_panel.gd`
- Modify: `addons/syncark_numeric_editor/numeric_editor_panel.tscn`
- Modify: `addons/syncark_numeric_editor/adapters/food_table_adapter.gd`
- Modify: `addons/syncark_numeric_editor/adapters/character_table_adapter.gd`
- Modify: `addons/syncark_numeric_editor/adapters/monster_table_adapter.gd`
- Modify: `addons/syncark_numeric_editor/adapters/market_table_adapter.gd`
- Modify: `addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
var panel_scene := load("res://addons/syncark_numeric_editor/numeric_editor_panel.tscn") as PackedScene
var panel = panel_scene.instantiate()
panel.refresh_all_tables()
if not panel.has_method("save_current_tab"):
    printerr("NUMERIC_EDITOR_PLUGIN_FAIL: save_current_tab missing")
    quit(1)
    return
if not panel.has_method("save_all_tabs"):
    printerr("NUMERIC_EDITOR_PLUGIN_FAIL: save_all_tabs missing")
    quit(1)
    return
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_plugin_runner.gd`
Expected: FAIL with `save_current_tab missing`

- [ ] **Step 3: Write minimal implementation**

```gdscript
@tool
extends VBoxContainer

const FOOD_ADAPTER := preload("res://addons/syncark_numeric_editor/adapters/food_table_adapter.gd")
const CHARACTER_ADAPTER := preload("res://addons/syncark_numeric_editor/adapters/character_table_adapter.gd")
const MONSTER_ADAPTER := preload("res://addons/syncark_numeric_editor/adapters/monster_table_adapter.gd")
const MARKET_ADAPTER := preload("res://addons/syncark_numeric_editor/adapters/market_table_adapter.gd")
const STAGE_ADAPTER := preload("res://addons/syncark_numeric_editor/adapters/stage_flow_table_adapter.gd")

var _status_label: Label
var _tab_container: TabContainer
var _grid: GridContainer
var _current_table_name := ""
var _tables := {}

func _ready() -> void:
    _status_label = $StatusLabel
    _tab_container = $TabContainer
    refresh_all_tables()

func refresh_all_tables() -> void:
    _tables.clear()
    _status_label.text = ""
    _load_food_table()
    _load_character_table()
    _load_monster_table()
    _load_market_tables()
    _load_stage_flow_tables()

func save_current_tab() -> Dictionary:
    return {"ok": true}

func save_all_tabs() -> Dictionary:
    return {"ok": true}
```

The panel scene should include:
- toolbar row with `Refresh`, `Save Current`, `Save All`
- `Label` named `StatusLabel`
- `TabContainer` named `TabContainer`
- per-tab `Tree` controls or editable `GridContainer` cells for wave-one table editing

Adapter updates in this task should expand `apply_*` methods to cover:
- all food numeric fields
- character rows
- monster rows
- market scalar fields, reroll curve, rarity weights, quantity ranges, expansion offers
- stage-flow route nodes, initial gold, and difficulty curves with aligned-length validation

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_plugin_runner.gd`
Expected: PASS with `NUMERIC_EDITOR_PLUGIN_PASS`

- [ ] **Step 5: Commit**

```bash
git add addons/syncark_numeric_editor Scripts/Tests/numeric_editor_plugin_runner.gd
git commit -m "Build numeric editor panel and save flows"
```

### Task 5: Verify plugin behavior against project resources

**Files:**
- Modify: `Scripts/Tests/numeric_editor_adapter_runner.gd`
- Modify: `Scripts/Tests/numeric_editor_plugin_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
var panel_scene := load("res://addons/syncark_numeric_editor/numeric_editor_panel.tscn") as PackedScene
var panel = panel_scene.instantiate()
panel.refresh_all_tables()
var snapshot := panel.debug_snapshot()
if not snapshot.has("Food") or not snapshot.has("StageFlow/Difficulty Curves"):
    printerr("NUMERIC_EDITOR_PLUGIN_FAIL: missing expected table snapshots")
    quit(1)
    return
if snapshot["Food"].size() == 0:
    printerr("NUMERIC_EDITOR_PLUGIN_FAIL: empty food snapshot")
    quit(1)
    return
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_plugin_runner.gd`
Expected: FAIL with `missing expected table snapshots`

- [ ] **Step 3: Write minimal implementation**

```gdscript
func debug_snapshot() -> Dictionary:
    return {
        "Food": _tables.get("Food", []),
        "StageFlow/Difficulty Curves": _tables.get("StageFlow/Difficulty Curves", [])
    }
```

Expand the adapter test to assert:
- food edit round-trips `gold_value`
- stage difficulty invalid lengths return explicit failure
- market quantity range preserves `Vector2i`

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_adapter_runner.gd`
Expected: PASS with `NUMERIC_EDITOR_ADAPTER_PASS`

Run: `godot4 --headless --path . -s res://Scripts/Tests/numeric_editor_plugin_runner.gd`
Expected: PASS with `NUMERIC_EDITOR_PLUGIN_PASS`

- [ ] **Step 5: Commit**

```bash
git add Scripts/Tests/numeric_editor_adapter_runner.gd Scripts/Tests/numeric_editor_plugin_runner.gd addons/syncark_numeric_editor/numeric_editor_panel.gd
git commit -m "Verify numeric editor resource coverage"
```
