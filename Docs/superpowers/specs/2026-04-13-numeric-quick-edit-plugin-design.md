# Syncark03 Numeric Quick Edit Plugin Design

**Scope**
Define a Godot editor plugin for centralized, spreadsheet-style editing of gameplay numbers and configuration data. The plugin targets the current resource-based data model and must allow direct editing and saving of the project's main balance resources inside the editor.

## Goals
- Provide a Godot editor tool for batch editing numeric and config data without manually opening each resource.
- Use a table-first workflow that feels closer to Excel than to per-resource inspector editing.
- Cover core balance resources in one plugin entry point: foods, characters, monsters, market config, stage flow config, and difficulty curves.
- Save directly back into the existing `.tres` resources used by the runtime.

## Non-Goals In This Wave
- Runtime debug panel or in-game tuning UI
- Automatic balancing suggestions or generated values
- Hidden fallback behavior, silent auto-fixes, or mock save success
- A graphical shape painter for expansion or food shapes
- Generic support for arbitrary project resources outside the current known balance files

## Confirmed Current State
- The project currently stores primary editable balance data in these resources:
  - `res://Data/Foods/food_catalog.tres`
  - `res://Data/Characters/character_roster.tres`
  - `res://Data/Monsters/monster_roster.tres`
  - `res://Data/Configs/market_config.tres`
  - `res://Data/Configs/stage_flow_config.tres`
- Resource scripts already define typed exported fields for food, character, monster, market, and stage-flow data.
- No existing `EditorPlugin` or custom Godot editor extension currently handles centralized balance editing.
- Difficulty tuning currently lives in `StageFlowConfig` as array curves such as reward, drop value, monster HP multiplier, and monster attack multiplier.
- Market tuning currently includes both simple curves and structured config collections such as rarity tables, quantity ranges, and expansion offers.

## Design Principles
- Keep the editing flow centralized and fast for balance work.
- Respect the existing resource layout instead of introducing a parallel data source.
- Prefer explicit validation errors over silent coercion or automatic repair.
- Separate table presentation from resource serialization logic so each data family stays understandable.
- Make config-heavy resources editable in tables, but do not force unrelated structures into one giant universal grid.

## Recommended Approach

### Chosen Direction
Implement a single `EditorPlugin` with a multi-tab spreadsheet-style editor.

### Why This Approach
- It matches the requested batch-edit workflow better than inspector-driven editing.
- It keeps one plugin entry point while still allowing each data family to use a table structure that fits its schema.
- It is substantially easier to maintain than a single giant heterogeneous table.

### Alternatives Considered
1. Single mega-table for all data types
- Rejected because food, unit, and config resources have incompatible schemas and would produce a noisy, fragile UI.

2. Mixed model with forms for config and tables for units
- Rejected for first wave because it weakens the "Excel-like" workflow the user explicitly wants.

## Plugin Architecture

### Main Components
- `EditorPlugin`
  - Registers the tool with Godot.
  - Adds and removes the main panel from the editor UI.
- Main panel scene/script
  - Hosts top-level tabs, toolbar actions, save state, and status/error messaging.
- Table adapter layer
  - Converts resource data into a normalized table model.
  - Converts edited table data back into typed resources before save.
- Validation layer
  - Performs field parsing and structural checks before resource write-back.

### Resource Ownership
- Foods, characters, and monsters each get one dedicated adapter.
- `MarketConfig` gets dedicated adapters per logical sub-table.
- `StageFlowConfig` gets dedicated adapters per logical sub-table.

This avoids a "universal schema" abstraction that would add complexity without helping this project.

## UI Design

### Top-Level Structure
- One main plugin panel inside the Godot editor.
- Top-level tabs:
  - `Food`
  - `Character`
  - `Monster`
  - `Market`
  - `StageFlow`
- `Market` and `StageFlow` use nested tabs for their sub-tables.

### Toolbar Actions
- `Refresh`
- `Save Current`
- `Save All`
- Dirty-state indicator
- Error/status message area

### Editing Style
- Each table uses row/column editing with direct cell edits.
- Sorting and simple filtering should be supported where the underlying data is row-based.
- Multi-cell paste is part of the intended workflow for numeric tuning.
- Invalid cells must be visibly marked and must block save for the affected table.

## Data Mapping

### Food Table
One row per `FoodDefinition`.

Expected columns include:
- `id`
- `display_name`
- `category`
- `hybrid_categories`
- `rarity`
- `gold_value`
- `hp_bonus`
- `attack_bonus`
- `bonus_damage`
- `attack_speed_percent`
- `heal_per_second`
- `execute_threshold_percent`
- `passive_text`
- `shape_cells`

`hybrid_categories` and `shape_cells` are represented as editable text in wave one and parsed on save.

### Character Table
One row per `CharacterDefinition`.

Expected columns:
- `id`
- `display_name`
- `base_hp`
- `base_attack`
- `attack_interval`

### Monster Table
One row per `MonsterDefinition`.

Expected columns:
- `id`
- `display_name`
- `category`
- `base_hp`
- `base_attack`
- `attack_interval`
- `skill_summary`
- `target_rule`

### Market Tables
`MarketConfig` is split into focused sub-tables:

1. `Reroll Curve`
- Row index plus reroll cost value.

2. `Rarity Weights`
- One row per market stage.
- Columns: `market`, `common`, `rare`, `epic`

3. `Quantity Ranges`
- One row per rarity.
- Columns: `rarity`, `min`, `max`

4. `Expansion Offers`
- One row per offer.
- Columns: `label`, `price`, `weight`, `shape`

Other scalar config fields remain editable in a compact scalar section or a small table inside the `Market` tab:
- `slot_count`
- `expansion_slot_chance`
- `food_slot_chance`
- `discount_min`
- `discount_max`

### StageFlow Tables
`StageFlowConfig` is split into:

1. `Route Nodes`
- One row per route index.
- Columns: `index`, `node_type`

2. `Difficulty Curves`
- One row per battle index.
- Columns:
  - `battle_index`
  - `normal_battle_reward_gold`
  - `normal_drop_value_curve`
  - `monster_hp_multiplier_curve`
  - `monster_attack_multiplier_curve`

3. Scalar section or small table:
- `initial_gold`

## Data Flow
- On plugin open, load the known resource paths directly.
- Convert each resource into a table model used by the UI layer.
- The UI edits only table state, not live resource fields directly.
- On save, validate table state first.
- If validation passes, rebuild the typed resource values and write back with `ResourceSaver.save()`.
- After successful save, clear dirty state for the saved table or tables.

## Validation And Error Handling

### Required Behavior
- No silent fallback values.
- No hidden auto-fill of missing curve entries.
- No save success when any target resource failed to serialize.

### Validation Rules
- Numeric fields must parse to the expected type.
- `StringName`-backed fields must not be silently rewritten to arbitrary defaults.
- `quantity_ranges` must remain a dictionary mapping rarity keys to `Vector2i`.
- `rarity_weights_by_market` rows must preserve required keys such as `market`, `common`, `rare`, and `epic`.
- Difficulty-curve columns in `StageFlow` must have aligned lengths after edit.
- Shape text fields must parse into valid arrays of `Vector2i` before save.

### Save Failure Policy
- Cell-level errors are shown inline where possible.
- Structural errors are shown in the active table header/status area.
- `Save Current` only writes the current tab if valid.
- `Save All` stops on the first invalid or failed resource and reports the error clearly.
- The plugin must not pretend that partially saved data is a full success.

## Complex Field Strategy For Wave One
- `shape_cells` and `expansion_offers.shape` are edited as text expressions representing `Vector2i` lists.
- `hybrid_categories` and `route_nodes` may be edited either as comma-separated text or through their dedicated row tables, depending on the tab.
- Wave one prioritizes full coverage of editable data over bespoke graphical editors.

## Testing Strategy
- Add script-level tests for adapter round-trips between resource data and table models.
- Add tests that verify invalid table content blocks save with explicit failure.
- Add editor-loading coverage sufficient to ensure the plugin can register and load the target resources.
- Add focused tests for:
  - `StageFlow` curve alignment success and failure cases
  - `MarketConfig.quantity_ranges` round-trip preservation
  - `MarketConfig.rarity_weights_by_market` key preservation
  - `FoodDefinition.shape_cells` parsing success and failure

## Main Risks
- A generic table UI in Godot may require custom handling for multi-cell paste and typed parsing.
- Text-based editing of shape data is less friendly than a graphical editor, but is acceptable for first-wave coverage.
- `MarketConfig` contains mixed scalar, array, and dictionary structures, so adapter boundaries must stay explicit to avoid a hard-to-debug serializer.
- If dirty-state tracking is too coarse, users may lose confidence in what has or has not been saved.

## Success Criteria
- A designer can open one Godot editor tool and edit the main balance resources without opening each resource manually.
- Core resource tables support direct numeric editing and save back into the existing `.tres` files.
- Market config, stage flow config, and difficulty curves are editable from structured tabular views.
- Invalid input surfaces as an explicit error instead of being silently ignored or normalized.
