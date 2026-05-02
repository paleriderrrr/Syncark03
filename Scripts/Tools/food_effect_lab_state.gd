extends RefCounted
class_name FoodEffectLabState

const CHARACTER_DATA_PATH := "res://Data/Characters/character_roster.tres"
const FOOD_DATA_PATH := "res://Data/Foods/food_catalog.tres"
const MONSTER_DATA_PATH := "res://Data/Monsters/monster_roster.tres"
const STAGE_FLOW_CONFIG_PATH := "res://Data/Configs/stage_flow_config.tres"

const GRID_WIDTH := 8
const GRID_HEIGHT := 6
const CATEGORY_ORDER: Array[StringName] = [&"fruit", &"dessert", &"meat", &"drink", &"staple", &"spice"]
const CATEGORY_DISPLAY_NAMES := {
	&"fruit": "Fruit",
	&"dessert": "Dessert",
	&"meat": "Meat",
	&"drink": "Drink",
	&"staple": "Staple",
	&"spice": "Spice",
}
const CATEGORY_SYNERGY_NAMES := {
	&"fruit": "Retaliate",
	&"dessert": "Recovery",
	&"meat": "Bloodrage",
	&"drink": "Freeze",
	&"staple": "Execute",
	&"spice": "Bonus Damage",
}

var character_roster: CharacterRoster
var food_catalog: FoodCatalog
var monster_roster: MonsterRoster
var stage_flow_config: StageFlowConfig

var food_lookup: Dictionary = {}
var monster_lookup: Dictionary = {}
var character_states: Dictionary = {}
var selected_character_id: StringName = &"warrior"
var selected_monster_id: StringName = &""
var _instance_counter: int = 1

func _init() -> void:
	_load_static_data()
	_build_lookup_tables()
	_initialize_character_states()
	_initialize_default_monster()

func _load_static_data() -> void:
	character_roster = load(CHARACTER_DATA_PATH) as CharacterRoster
	food_catalog = load(FOOD_DATA_PATH) as FoodCatalog
	monster_roster = load(MONSTER_DATA_PATH) as MonsterRoster
	stage_flow_config = load(STAGE_FLOW_CONFIG_PATH) as StageFlowConfig

func _build_lookup_tables() -> void:
	food_lookup.clear()
	monster_lookup.clear()
	for definition_variant in food_catalog.foods:
		var definition: FoodDefinition = definition_variant
		food_lookup[definition.id] = definition
	for definition_variant in monster_roster.monsters:
		var definition: MonsterDefinition = definition_variant
		monster_lookup[definition.id] = definition

func _initialize_character_states() -> void:
	var full_grid: Array[Vector2i] = get_full_grid_cells()
	for definition_variant in character_roster.characters:
		var definition: CharacterDefinition = definition_variant
		character_states[definition.id] = {
			"id": definition.id,
			"base_shape": [],
			"base_anchor": Vector2i.ZERO,
			"active_cells": full_grid.duplicate(),
			"placed_foods": [],
			"pending_expansions": [],
			"placed_expansions": [],
			"hp_ratio": 1.0,
		}

func _initialize_default_monster() -> void:
	for definition_variant in monster_roster.monsters:
		var definition: MonsterDefinition = definition_variant
		if definition.category != &"boss":
			selected_monster_id = definition.id
			return
	if not monster_roster.monsters.is_empty():
		selected_monster_id = (monster_roster.monsters[0] as MonsterDefinition).id

func get_character_state(character_id: StringName) -> Dictionary:
	return character_states.get(character_id, {})

func get_selected_character_state() -> Dictionary:
	return get_character_state(selected_character_id)

func get_food_definition(food_id: StringName) -> FoodDefinition:
	return food_lookup.get(food_id) as FoodDefinition

func get_current_monster_definition() -> MonsterDefinition:
	return monster_lookup.get(selected_monster_id) as MonsterDefinition

func get_food_categories(definition: FoodDefinition) -> Array[StringName]:
	var categories: Array[StringName] = []
	if definition == null:
		return categories
	categories.append(definition.category)
	for category_id_variant in definition.hybrid_categories:
		var category_id: StringName = category_id_variant
		if not categories.has(category_id):
			categories.append(category_id)
	return categories

func get_completed_battle_count() -> int:
	return 0

func get_current_monster_multipliers() -> Dictionary:
	return {
		"hp": _get_stage_curve_value("monster_hp_multiplier_curve", 1.0),
		"attack": _get_stage_curve_value("monster_attack_multiplier_curve", 1.0),
	}

func get_full_grid_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			result.append(Vector2i(x, y))
	return result

func clear_selected_board() -> void:
	var state: Dictionary = get_selected_character_state()
	state["placed_foods"] = []
	state["placed_expansions"] = []
	state["pending_expansions"] = []

func set_selected_character(character_id: StringName) -> void:
	if character_states.has(character_id):
		selected_character_id = character_id

func set_selected_monster(monster_id: StringName) -> void:
	if monster_lookup.has(monster_id):
		selected_monster_id = monster_id

func set_hp_ratio(value: float) -> void:
	var state: Dictionary = get_selected_character_state()
	state["hp_ratio"] = clampf(value, 0.0, 1.0)

func get_hp_ratio() -> float:
	return float(get_selected_character_state().get("hp_ratio", 1.0))

func place_food(definition_id: StringName, anchor: Vector2i, rotation: int = 0) -> bool:
	var definition: FoodDefinition = get_food_definition(definition_id)
	if definition == null:
		return false
	var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(definition.shape_cells, rotation)
	var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(rotated_cells, anchor)
	if not _can_place_cells(placed_cells):
		return false
	get_selected_character_state()["placed_foods"].append({
		"instance_id": _next_instance_id("lab_food"),
		"definition_id": definition.id,
		"rotation": rotation,
		"anchor": anchor,
		"cells": placed_cells,
		"reroll_bonus_count": 0,
	})
	return true

func move_food(from_cell: Vector2i, new_anchor: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	for index in range(state["placed_foods"].size()):
		var item: Dictionary = state["placed_foods"][index]
		if not ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [from_cell.x, from_cell.y]):
			continue
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		if definition == null:
			return false
		var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(definition.shape_cells, int(item.get("rotation", 0)))
		var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(rotated_cells, new_anchor)
		if not _can_place_cells(placed_cells, item["instance_id"]):
			return false
		item["anchor"] = new_anchor
		item["cells"] = placed_cells
		state["placed_foods"][index] = item
		return true
	return false

func remove_food_at_cell(cell: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	for index in range(state["placed_foods"].size()):
		var item: Dictionary = state["placed_foods"][index]
		if ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [cell.x, cell.y]):
			state["placed_foods"].remove_at(index)
			return true
	return false

func get_synergy_summary(character_id: StringName) -> Dictionary:
	var category_definition_sets: Dictionary = {}
	for category_id_variant in CATEGORY_ORDER:
		var category_id: StringName = category_id_variant
		category_definition_sets[category_id] = {}
	var state: Dictionary = get_character_state(character_id)
	for item_variant in state.get("placed_foods", []):
		var item: Dictionary = item_variant
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		if definition == null:
			continue
		for category_id_variant in get_food_categories(definition):
			var category_id: StringName = category_id_variant
			var definition_set: Dictionary = category_definition_sets.get(category_id, {})
			definition_set[definition.id] = true
			category_definition_sets[category_id] = definition_set
	var entries: Array[Dictionary] = []
	for category_id_variant in CATEGORY_ORDER:
		var category_id: StringName = category_id_variant
		var count: int = int((category_definition_sets.get(category_id, {}) as Dictionary).size())
		entries.append({
			"category_id": category_id,
			"category_name": CATEGORY_DISPLAY_NAMES.get(category_id, String(category_id)),
			"synergy_name": CATEGORY_SYNERGY_NAMES.get(category_id, ""),
			"count": count,
			"active": count >= 3,
		})
	return {
		"character_id": character_id,
		"entries": entries,
	}

func get_food_entries(category_filter: StringName = &"all", search_text: String = "") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_search: String = search_text.strip_edges().to_lower()
	for definition_variant in food_catalog.foods:
		var definition: FoodDefinition = definition_variant
		if category_filter != &"all" and definition.category != category_filter and not definition.hybrid_categories.has(category_filter):
			continue
		if not normalized_search.is_empty():
			var name_match: bool = definition.display_name.to_lower().contains(normalized_search)
			var id_match: bool = String(definition.id).to_lower().contains(normalized_search)
			if not name_match and not id_match:
				continue
		entries.append({
			"group_key": definition.id,
			"definition_id": definition.id,
			"display_name": definition.display_name,
			"count": 1,
			"category": definition.category,
			"rarity": definition.rarity,
			"display_price": definition.gold_value,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_index: int = CATEGORY_ORDER.find(a.get("category", &""))
		var b_index: int = CATEGORY_ORDER.find(b.get("category", &""))
		if a_index == b_index:
			return String(a.get("display_name", "")) < String(b.get("display_name", ""))
		return a_index < b_index
	)
	return entries

func get_monster_entries() -> Array[MonsterDefinition]:
	return monster_roster.monsters.duplicate()

func get_character_entries() -> Array[CharacterDefinition]:
	return character_roster.characters.duplicate()

func build_battle_preview() -> Dictionary:
	return CombatEngine.simulate(self)

func _can_place_cells(cells: Array[Vector2i], excluded_instance_id: StringName = &"") -> bool:
	if not ShapeUtils.within_bounds(cells, GRID_WIDTH, GRID_HEIGHT):
		return false
	if not ShapeUtils.contains_all(get_selected_character_state().get("active_cells", []), cells):
		return false
	for item_variant in get_selected_character_state().get("placed_foods", []):
		var item: Dictionary = item_variant
		if item.get("instance_id", &"") == excluded_instance_id:
			continue
		if ShapeUtils.overlaps(item.get("cells", []), cells):
			return false
	return true

func _next_instance_id(prefix: String) -> StringName:
	var value: String = "%s_%d" % [prefix, _instance_counter]
	_instance_counter += 1
	return StringName(value)

func _get_stage_curve_value(property_name: StringName, default_value: float) -> float:
	if stage_flow_config == null:
		return default_value
	var values_variant: Variant = stage_flow_config.get(property_name)
	if not (values_variant is Array):
		return default_value
	var values: Array = values_variant
	if values.is_empty():
		return default_value
	return float(values[0])
