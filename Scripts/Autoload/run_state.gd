extends Node

signal state_changed
signal selected_character_changed(character_id: StringName)
signal selected_item_changed
signal battle_requested
signal battle_finished(report: Dictionary)

const CHARACTER_DATA_PATH := "res://Data/Characters/character_roster.tres"
const FOOD_DATA_PATH := "res://Data/Foods/food_catalog.tres"
const MONSTER_DATA_PATH := "res://Data/Monsters/monster_roster.tres"
const MARKET_CONFIG_PATH := "res://Data/Configs/market_config.tres"
const STAGE_FLOW_CONFIG_PATH := "res://Data/Configs/stage_flow_config.tres"

const GRID_WIDTH := 8
const GRID_HEIGHT := 6
const NODE_MARKET: StringName = &"market"
const NODE_BATTLE: StringName = &"battle"
const NODE_REST: StringName = &"rest"
const NODE_BOSS_BATTLE: StringName = &"boss_battle"
const ACTION_BUTTON_DEPART: StringName = &"depart"
const ACTION_BUTTON_CONTINUE: StringName = &"continue"
const ACTION_BUTTON_RESTART: StringName = &"restart"
const CATEGORY_ORDER: Array[StringName] = [&"fruit", &"dessert", &"meat", &"drink", &"staple", &"spice"]
const CATEGORY_DISPLAY_NAMES := {
	&"fruit": "蔬果",
	&"dessert": "甜品",
	&"meat": "肉类",
	&"drink": "饮品",
	&"staple": "主食",
	&"spice": "香料",
}
const CATEGORY_SYNERGY_NAMES := {
	&"fruit": "果酸反伤",
	&"dessert": "周期回复",
	&"meat": "血怒状态",
	&"drink": "冻结降速",
	&"staple": "血线斩杀",
	&"spice": "附加伤害",
}
const CATEGORY_SYNERGY_EFFECTS := {
	&"fruit": "腐蚀接触的敌怪",
	&"dessert": "按周期回复生命",
	&"meat": "血越低伤害越高",
	&"drink": "降低敌方攻速",
	&"staple": "低于门槛直接秒杀",
	&"spice": "每次攻击附带额外伤害",
}

var character_roster: CharacterRoster
var food_catalog: FoodCatalog
var monster_roster: MonsterRoster
var market_config: MarketConfig
var stage_flow_config: StageFlowConfig

var food_lookup: Dictionary = {}
var monster_lookup: Dictionary = {}

var current_gold: int = 0
var current_route_index: int = 0
var current_market_index: int = 1
var current_reroll_count: int = 0
var selected_character_id: StringName = &"warrior"
var shared_inventory: Array[Dictionary] = []
var character_states: Dictionary = {}
var selected_item: Dictionary = {}
var current_market_offers: Array[Dictionary] = []
var normal_monster_order: Array[StringName] = []
var free_food_purchase_count: int = 0
var spice_purchase_refund: int = 0
var battle_reports: Array[Dictionary] = []
var pre_battle_snapshot: Dictionary = {}
var run_finished: bool = false

var _instance_counter: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_load_static_data()
	start_new_run()

func _load_static_data() -> void:
	character_roster = load(CHARACTER_DATA_PATH) as CharacterRoster
	food_catalog = load(FOOD_DATA_PATH) as FoodCatalog
	monster_roster = load(MONSTER_DATA_PATH) as MonsterRoster
	market_config = load(MARKET_CONFIG_PATH) as MarketConfig
	stage_flow_config = load(STAGE_FLOW_CONFIG_PATH) as StageFlowConfig
	_build_lookup_tables()

func _build_lookup_tables() -> void:
	food_lookup.clear()
	monster_lookup.clear()
	if food_catalog:
		for definition in food_catalog.foods:
			food_lookup[definition.id] = definition
	if monster_roster:
		for definition in monster_roster.monsters:
			monster_lookup[definition.id] = definition

func ensure_initialized() -> void:
	if character_roster == null or stage_flow_config == null:
		_load_static_data()
	if character_states.is_empty():
		start_new_run()

func start_new_run() -> void:
	current_gold = stage_flow_config.initial_gold if stage_flow_config else 30
	current_route_index = 0
	current_market_index = 1
	current_reroll_count = 0
	selected_character_id = &"warrior"
	shared_inventory.clear()
	character_states.clear()
	selected_item = {}
	current_market_offers.clear()
	free_food_purchase_count = 0
	spice_purchase_refund = 0
	battle_reports.clear()
	pre_battle_snapshot.clear()
	run_finished = false
	_instance_counter = 1
	_init_character_states()
	_init_normal_monster_order()
	_generate_market_offers()
	state_changed.emit()
	selected_character_changed.emit(selected_character_id)
	selected_item_changed.emit()

func _init_character_states() -> void:
	for definition in character_roster.characters:
		var base_shape: Array[Vector2i] = []
		for y in 3:
			for x in 3:
				base_shape.append(Vector2i(x, y))
		var base_anchor := Vector2i(0, 0)
		character_states[definition.id] = {
			"id": definition.id,
			"base_shape": base_shape,
			"base_anchor": base_anchor,
			"active_cells": ShapeUtils.translate_cells(base_shape, base_anchor),
			"placed_foods": [],
			"pending_expansions": [],
			"placed_expansions": [],
			"hp_ratio": 1.0,
		}

func _init_normal_monster_order() -> void:
	normal_monster_order.clear()
	var ids: Array[StringName] = []
	for definition in monster_roster.monsters:
		if definition.category != &"boss":
			ids.append(definition.id)
	while not ids.is_empty():
		var pick: int = _rng.randi_range(0, ids.size() - 1)
		normal_monster_order.append(ids[pick])
		ids.remove_at(pick)

func get_current_node_type() -> StringName:
	if stage_flow_config == null or stage_flow_config.route_nodes.is_empty():
		return &"unknown"
	return stage_flow_config.route_nodes[min(current_route_index, stage_flow_config.route_nodes.size() - 1)]

func get_node_display_name(node_type: StringName) -> String:
	match node_type:
		NODE_MARKET:
			return "市场"
		NODE_BATTLE:
			return "战斗"
		NODE_REST:
			return "休整"
		NODE_BOSS_BATTLE:
			return "Boss战"
		_:
			return String(node_type)

func get_route_label() -> String:
	if stage_flow_config == null or stage_flow_config.route_nodes.is_empty():
		return "路线不可用"
	var current_label: String = get_node_display_name(get_current_node_type())
	return "节点 %d / %d：%s" % [current_route_index + 1, stage_flow_config.route_nodes.size(), current_label]

func get_character_display_names() -> Dictionary:
	var result: Dictionary = {}
	if character_roster == null:
		return result
	for definition in character_roster.characters:
		result[definition.id] = definition.display_name
	return result

func select_character(character_id: StringName) -> void:
	if selected_character_id == character_id:
		return
	selected_character_id = character_id
	selected_character_changed.emit(selected_character_id)
	state_changed.emit()

func get_selected_character_state() -> Dictionary:
	return character_states.get(selected_character_id, {})

func get_character_state(character_id: StringName) -> Dictionary:
	return character_states.get(character_id, {})

func get_food_definition(food_id: StringName) -> FoodDefinition:
	return food_lookup.get(food_id) as FoodDefinition

func get_current_monster_definition() -> MonsterDefinition:
	if get_current_node_type() == NODE_BOSS_BATTLE:
		return monster_lookup.get(&"nc2_auto_cooker") as MonsterDefinition
	var battle_index: int = get_completed_battle_count()
	if battle_index < 0 or battle_index >= normal_monster_order.size():
		return null
	return monster_lookup.get(normal_monster_order[battle_index]) as MonsterDefinition

func get_completed_battle_count() -> int:
	var count: int = 0
	for report in battle_reports:
		if report.get("result", "") == "win":
			count += 1
	return count

func get_board_item_cells(character_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var state: Dictionary = get_character_state(character_id)
	for item in state.get("placed_foods", []):
		for cell in item.get("cells", []):
			result.append(cell)
	return result

func get_board_expansion_cells(character_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var state: Dictionary = get_character_state(character_id)
	for item in state.get("placed_expansions", []):
		for cell in item.get("cells", []):
			result.append(cell)
	return result

func get_base_cells(character_id: StringName) -> Array[Vector2i]:
	var state: Dictionary = get_character_state(character_id)
	return ShapeUtils.translate_cells(_clone_cells(state.get("base_shape", [])), state.get("base_anchor", Vector2i.ZERO))

func _rebuild_active_cells(state: Dictionary) -> void:
	var active_cells: Array[Vector2i] = ShapeUtils.translate_cells(_clone_cells(state.get("base_shape", [])), state.get("base_anchor", Vector2i.ZERO))
	for expansion in state.get("placed_expansions", []):
		for cell_variant in expansion.get("cells", []):
			active_cells.append(cell_variant)
	state["active_cells"] = active_cells

func _next_instance_id(prefix: String) -> StringName:
	var value: String = "%s_%d" % [prefix, _instance_counter]
	_instance_counter += 1
	return StringName(value)

func _clone_cells(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell)
	return result

func generate_item_instance(food_id: StringName) -> Dictionary:
	return {
		"instance_id": _next_instance_id("food"),
		"definition_id": food_id,
		"rotation": 0,
		"reroll_bonus_count": 0,
	}

func get_inventory_counts() -> Dictionary:
	var counts: Dictionary = {}
	for item in shared_inventory:
		var food_id: StringName = item["definition_id"]
		counts[food_id] = counts.get(food_id, 0) + 1
	return counts

func get_food_categories(definition: FoodDefinition) -> Array[StringName]:
	var categories: Array[StringName] = []
	if definition == null:
		return categories
	categories.append(definition.category)
	for category_id in definition.hybrid_categories:
		if not categories.has(category_id):
			categories.append(category_id)
	return categories

func get_current_market_tier() -> int:
	return clamp(current_market_index, 1, 4)

func _generate_market_offers() -> void:
	current_market_offers.clear()
	current_reroll_count = 0 if current_market_offers.is_empty() else current_reroll_count
	if get_current_node_type() != NODE_MARKET:
		state_changed.emit()
		return
	var used_food_ids: Dictionary = {}
	for slot_index in market_config.slot_count:
		if _rng.randf() < market_config.expansion_slot_chance:
			current_market_offers.append(_roll_expansion_offer(slot_index))
		else:
			current_market_offers.append(_roll_food_offer(slot_index, used_food_ids))
	state_changed.emit()

func refresh_market_offers() -> bool:
	if get_current_node_type() != NODE_MARKET:
		return false
	var cost: int = get_current_refresh_cost()
	if current_gold < cost:
		return false
	current_gold -= cost
	current_reroll_count += 1
	_increment_cellar_vintage_bonuses()
	current_market_offers.clear()
	var used_food_ids: Dictionary = {}
	for slot_index in market_config.slot_count:
		if _rng.randf() < market_config.expansion_slot_chance:
			current_market_offers.append(_roll_expansion_offer(slot_index))
		else:
			current_market_offers.append(_roll_food_offer(slot_index, used_food_ids))
	state_changed.emit()
	return true

func get_current_refresh_cost() -> int:
	if market_config == null:
		return 0
	var curve: PackedInt32Array = market_config.reroll_cost_curve
	if curve.is_empty():
		return 0
	return int(curve[min(current_reroll_count, curve.size() - 1)])

func _roll_expansion_offer(slot_index: int) -> Dictionary:
	var roll: float = _rng.randf()
	var accumulated: float = 0.0
	var picked: Dictionary = market_config.expansion_offers[0]
	for entry in market_config.expansion_offers:
		accumulated += float(entry["weight"])
		if roll <= accumulated:
			picked = entry
			break
	var target_id: StringName = character_roster.characters[_rng.randi_range(0, character_roster.characters.size() - 1)].id
	return {
		"offer_id": _next_instance_id("offer"),
		"slot_index": slot_index,
		"kind": &"expansion",
		"target_character_id": target_id,
		"shape_cells": _clone_cells(picked["shape"]),
		"price": picked["price"],
		"label": picked["label"],
	}

func _get_rarity_weights_for_market() -> Dictionary:
	for entry in market_config.rarity_weights_by_market:
		if int(entry["market"]) == get_current_market_tier():
			return entry
	return market_config.rarity_weights_by_market[0]

func _roll_food_offer(slot_index: int, used_food_ids: Dictionary = {}) -> Dictionary:
	var weights: Dictionary = _get_rarity_weights_for_market()
	var rarity: StringName = _pick_rarity(weights)
	var candidates: Array[FoodDefinition] = []
	for definition in food_catalog.foods:
		if definition.rarity == rarity and not used_food_ids.has(definition.id):
			candidates.append(definition)
	if candidates.is_empty():
		for definition in food_catalog.foods:
			if not used_food_ids.has(definition.id):
				candidates.append(definition)
	if candidates.is_empty():
		candidates = food_catalog.foods
	var definition: FoodDefinition = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var range: Vector2i = market_config.quantity_ranges.get(String(rarity), Vector2i.ONE)
	var quantity: int = _rng.randi_range(range.x, range.y)
	if rarity == &"epic":
		quantity = 1
	var discount: float = _roll_discount()
	used_food_ids[definition.id] = true
	return {
		"offer_id": _next_instance_id("offer"),
		"slot_index": slot_index,
		"kind": &"food",
		"definition_id": definition.id,
		"quantity": quantity,
		"rarity": rarity,
		"discount": discount,
		"price": maxi(1, int(roundi(definition.gold_value * quantity * discount))),
	}

func _pick_rarity(weights: Dictionary) -> StringName:
	var roll: int = _rng.randi_range(1, 100)
	var boundary: int = int(weights["common"])
	if roll <= boundary:
		return &"common"
	boundary += int(weights["rare"])
	if roll <= boundary:
		return &"rare"
	return &"epic"

func _roll_discount() -> float:
	var t: float = _rng.randf()
	return lerpf(market_config.discount_min, market_config.discount_max, t * t)

func buy_market_offer(index: int) -> bool:
	if index < 0 or index >= current_market_offers.size():
		return false
	var offer: Dictionary = current_market_offers[index]
	var price: int = int(offer["price"])
	if offer["kind"] == &"food" and free_food_purchase_count > 0:
		price = 0
		free_food_purchase_count -= 1
	if current_gold < price:
		return false
	current_gold -= price
	if offer["kind"] == &"food":
		for _i in int(offer["quantity"]):
			var instance: Dictionary = generate_item_instance(offer["definition_id"])
			shared_inventory.append(instance)
			_apply_food_purchase_side_effects(instance)
	else:
		var expansion: Dictionary = {
			"instance_id": _next_instance_id("expansion"),
			"label": offer["label"],
			"shape_cells": _clone_cells(offer["shape_cells"]),
			"rotation": 0,
			"target_character_id": offer["target_character_id"],
		}
		var character_state: Dictionary = get_character_state(offer["target_character_id"])
		character_state["pending_expansions"].append(expansion)
	current_market_offers.remove_at(index)
	state_changed.emit()
	return true

func purchase_market_offer_package(offer_id: StringName) -> Array[Dictionary]:
	var index: int = resolve_offer_index_by_id(offer_id)
	if index < 0 or index >= current_market_offers.size():
		return []
	var offer: Dictionary = current_market_offers[index]
	var gained_items: Array[Dictionary] = []
	var price: int = int(offer["price"])
	if offer["kind"] == &"food" and free_food_purchase_count > 0:
		price = 0
		free_food_purchase_count -= 1
	if current_gold < price:
		return []
	current_gold -= price
	if offer["kind"] == &"food":
		for _i in int(offer["quantity"]):
			var instance: Dictionary = generate_item_instance(offer["definition_id"])
			shared_inventory.append(instance)
			gained_items.append(instance)
			_apply_food_purchase_side_effects(instance)
	else:
		var expansion: Dictionary = {
			"instance_id": _next_instance_id("expansion"),
			"label": offer["label"],
			"shape_cells": _clone_cells(offer["shape_cells"]),
			"rotation": 0,
			"target_character_id": offer["target_character_id"],
		}
		var character_state: Dictionary = get_character_state(offer["target_character_id"])
		character_state["pending_expansions"].append(expansion)
		gained_items.append(expansion)
	current_market_offers.remove_at(index)
	state_changed.emit()
	return gained_items

func get_effective_offer_price(offer: Dictionary) -> int:
	if offer.is_empty():
		return 0
	if offer.get("kind", &"") == &"food" and free_food_purchase_count > 0:
		return 0
	return int(offer.get("price", 0))

func _apply_food_purchase_side_effects(instance: Dictionary) -> void:
	var definition: FoodDefinition = get_food_definition(instance["definition_id"])
	match definition.id:
		&"travel_bento":
			free_food_purchase_count += 1
			_generate_market_offers()
		&"curry_can":
			current_gold += 4
			spice_purchase_refund += 1
		_:
			pass
	if definition.category == &"spice" and spice_purchase_refund > 0 and definition.id != &"curry_can":
		current_gold += spice_purchase_refund
	if definition.id == &"cellar_vintage":
		instance["reroll_bonus_count"] = 0

func _increment_cellar_vintage_bonuses() -> void:
	for item in shared_inventory:
		if item["definition_id"] == &"cellar_vintage":
			item["reroll_bonus_count"] = int(item.get("reroll_bonus_count", 0)) + 1
	for character_id in character_states.keys():
		for item in character_states[character_id]["placed_foods"]:
			if item["definition_id"] == &"cellar_vintage":
				item["reroll_bonus_count"] = int(item.get("reroll_bonus_count", 0)) + 1

func select_inventory_item(instance_id: StringName) -> void:
	for item in shared_inventory:
		if item["instance_id"] == instance_id:
			selected_item = {
				"source": &"inventory",
				"instance_id": instance_id,
				"rotation": int(item.get("rotation", 0)),
			}
			selected_item_changed.emit()
			state_changed.emit()
			return

func pick_inventory_instance(group_key: StringName) -> Dictionary:
	for item in shared_inventory:
		if item.get("definition_id", &"") == group_key:
			selected_item = {
				"source": &"inventory",
				"instance_id": item["instance_id"],
				"rotation": int(item.get("rotation", 0)),
			}
			selected_item_changed.emit()
			state_changed.emit()
			return selected_item.duplicate(true)
	return {}

func store_placed_food(from_cell: Vector2i) -> bool:
	return remove_item_at_cell(from_cell)

func move_base_board(to_anchor: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	var current_anchor: Vector2i = state.get("base_anchor", Vector2i.ZERO)
	var delta: Vector2i = to_anchor - current_anchor
	if delta == Vector2i.ZERO:
		return true
	var new_base_cells: Array[Vector2i] = ShapeUtils.translate_cells(_clone_cells(state.get("base_shape", [])), to_anchor)
	if not ShapeUtils.within_bounds(new_base_cells, GRID_WIDTH, GRID_HEIGHT):
		return false
	var shifted_expansions: Array[Dictionary] = []
	for expansion_variant in state.get("placed_expansions", []):
		var expansion: Dictionary = expansion_variant.duplicate(true)
		expansion["anchor"] = expansion["anchor"] + delta
		expansion["cells"] = ShapeUtils.translate_cells(_clone_cells(expansion["cells"]), delta)
		if not ShapeUtils.within_bounds(expansion["cells"], GRID_WIDTH, GRID_HEIGHT):
			return false
		shifted_expansions.append(expansion)
	var shifted_foods: Array[Dictionary] = []
	for food_variant in state.get("placed_foods", []):
		var food: Dictionary = food_variant.duplicate(true)
		food["anchor"] = food["anchor"] + delta
		food["cells"] = ShapeUtils.translate_cells(_clone_cells(food["cells"]), delta)
		if not ShapeUtils.within_bounds(food["cells"], GRID_WIDTH, GRID_HEIGHT):
			return false
		shifted_foods.append(food)
	state["base_anchor"] = to_anchor
	state["placed_expansions"] = shifted_expansions
	state["placed_foods"] = shifted_foods
	_rebuild_active_cells(state)
	state_changed.emit()
	return true

func select_pending_expansion(instance_id: StringName) -> void:
	var state: Dictionary = get_selected_character_state()
	for item in state.get("pending_expansions", []):
		if item["instance_id"] == instance_id:
			selected_item = {
				"source": &"expansion",
				"instance_id": instance_id,
				"rotation": int(item.get("rotation", 0)),
			}
			selected_item_changed.emit()
			state_changed.emit()
			return

func clear_selection() -> void:
	selected_item = {}
	selected_item_changed.emit()
	state_changed.emit()

func rotate_selected_item() -> void:
	if selected_item.is_empty():
		return
	selected_item["rotation"] = posmod(int(selected_item["rotation"]) + 1, 4)
	selected_item_changed.emit()
	state_changed.emit()

func get_selected_item_cells() -> Array[Vector2i]:
	if selected_item.is_empty():
		return []
	var source: StringName = selected_item["source"]
	if source == &"inventory":
		var item: Dictionary = _find_inventory_item(selected_item["instance_id"])
		if item.is_empty():
			return []
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		return ShapeUtils.rotate_cells(definition.shape_cells, int(selected_item["rotation"]))
	var pending: Dictionary = _find_pending_expansion(selected_character_id, selected_item["instance_id"])
	if pending.is_empty():
		return []
	return ShapeUtils.rotate_cells(_clone_cells(pending["shape_cells"]), int(selected_item["rotation"]))

func _find_inventory_item(instance_id: StringName) -> Dictionary:
	for item in shared_inventory:
		if item["instance_id"] == instance_id:
			return item
	return {}

func _find_pending_expansion(character_id: StringName, instance_id: StringName) -> Dictionary:
	var state: Dictionary = get_character_state(character_id)
	for item in state.get("pending_expansions", []):
		if item["instance_id"] == instance_id:
			return item
	return {}

func try_place_selected_item(anchor: Vector2i) -> bool:
	if selected_item.is_empty():
		return false
	var local_cells: Array[Vector2i] = get_selected_item_cells()
	if local_cells.is_empty():
		return false
	var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(local_cells, anchor)
	if not ShapeUtils.within_bounds(placed_cells, GRID_WIDTH, GRID_HEIGHT):
		return false
	var state: Dictionary = get_selected_character_state()
	if selected_item["source"] == &"inventory":
		if not ShapeUtils.contains_all(state["active_cells"], placed_cells):
			return false
		if ShapeUtils.overlaps(get_board_item_cells(selected_character_id), placed_cells):
			return false
		var inventory_item: Dictionary = _find_inventory_item(selected_item["instance_id"])
		if inventory_item.is_empty():
			return false
		inventory_item["rotation"] = int(selected_item["rotation"])
		state["placed_foods"].append({
			"instance_id": inventory_item["instance_id"],
			"definition_id": inventory_item["definition_id"],
			"rotation": int(selected_item["rotation"]),
			"anchor": anchor,
			"cells": placed_cells,
			"reroll_bonus_count": int(inventory_item.get("reroll_bonus_count", 0)),
		})
		_remove_inventory_item(inventory_item["instance_id"])
	else:
		if ShapeUtils.overlaps(state["active_cells"], placed_cells):
			return false
		if not ShapeUtils.shares_edge(placed_cells, state["active_cells"]):
			return false
		var pending: Dictionary = _find_pending_expansion(selected_character_id, selected_item["instance_id"])
		if pending.is_empty():
			return false
		state["placed_expansions"].append({
			"instance_id": pending["instance_id"],
			"label": pending["label"],
			"rotation": int(selected_item["rotation"]),
			"anchor": anchor,
			"cells": placed_cells,
		})
		_remove_pending_expansion(selected_character_id, pending["instance_id"])
		_rebuild_active_cells(state)
	state_changed.emit()
	clear_selection()
	return true

func _remove_inventory_item(instance_id: StringName) -> void:
	for index in shared_inventory.size():
		if shared_inventory[index]["instance_id"] == instance_id:
			shared_inventory.remove_at(index)
			return

func _remove_pending_expansion(character_id: StringName, instance_id: StringName) -> void:
	var state: Dictionary = get_character_state(character_id)
	for index in state["pending_expansions"].size():
		if state["pending_expansions"][index]["instance_id"] == instance_id:
			state["pending_expansions"].remove_at(index)
			return

func remove_item_at_cell(cell: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	for index in state["placed_foods"].size():
		var item: Dictionary = state["placed_foods"][index]
		if ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [cell.x, cell.y]):
			shared_inventory.append({
				"instance_id": item["instance_id"],
				"definition_id": item["definition_id"],
				"rotation": int(item["rotation"]),
				"reroll_bonus_count": int(item.get("reroll_bonus_count", 0)),
			})
			state["placed_foods"].remove_at(index)
			state_changed.emit()
			return true
	for index in state["placed_expansions"].size():
		var item: Dictionary = state["placed_expansions"][index]
		if ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [cell.x, cell.y]):
			if _has_food_on_cells(selected_character_id, item["cells"]):
				return false
			state["pending_expansions"].append({
				"instance_id": item["instance_id"],
				"label": item["label"],
				"shape_cells": ShapeUtils.rotate_cells(_derive_shape_from_placed_cells(item["cells"], item["anchor"]), 0),
				"rotation": 0,
				"target_character_id": selected_character_id,
			})
			state["placed_expansions"].remove_at(index)
			_rebuild_active_cells(state)
			state_changed.emit()
			return true
	return false

func move_placed_food(from_cell: Vector2i, to_anchor: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	for index in range(state["placed_foods"].size()):
		var item: Dictionary = state["placed_foods"][index]
		if not ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [from_cell.x, from_cell.y]):
			continue
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		if definition == null:
			return false
		var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(definition.shape_cells, int(item.get("rotation", 0)))
		var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(rotated_cells, to_anchor)
		if not ShapeUtils.within_bounds(placed_cells, GRID_WIDTH, GRID_HEIGHT):
			return false
		if not ShapeUtils.contains_all(state["active_cells"], placed_cells):
			return false
		var occupied_by_others: Array[Vector2i] = []
		for other_index in range(state["placed_foods"].size()):
			if other_index == index:
				continue
			for other_cell in state["placed_foods"][other_index]["cells"]:
				occupied_by_others.append(other_cell)
		if ShapeUtils.overlaps(occupied_by_others, placed_cells):
			return false
		item["anchor"] = to_anchor
		item["cells"] = placed_cells
		state["placed_foods"][index] = item
		state_changed.emit()
		return true
	return false

func move_placed_expansion(from_cell: Vector2i, to_anchor: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	for index in range(state["placed_expansions"].size()):
		var item: Dictionary = state["placed_expansions"][index]
		if not ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [from_cell.x, from_cell.y]):
			continue
		if _has_food_on_cells(selected_character_id, item["cells"]):
			return false
		var shape_cells: Array[Vector2i] = _derive_shape_from_placed_cells(item["cells"], item["anchor"])
		var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(shape_cells, int(item.get("rotation", 0)))
		var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(rotated_cells, to_anchor)
		if not ShapeUtils.within_bounds(placed_cells, GRID_WIDTH, GRID_HEIGHT):
			return false
		var active_without_self: Array[Vector2i] = _clone_cells(state["active_cells"])
		for owned_cell in item["cells"]:
			_remove_active_cell(active_without_self, owned_cell)
		if ShapeUtils.overlaps(active_without_self, placed_cells):
			return false
		if not ShapeUtils.shares_edge(placed_cells, active_without_self):
			return false
		item["anchor"] = to_anchor
		item["cells"] = placed_cells
		state["placed_expansions"][index] = item
		_rebuild_active_cells(state)
		state_changed.emit()
		return true
	return false

func _derive_shape_from_placed_cells(cells: Array[Vector2i], anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell - anchor)
	return ShapeUtils.normalize_cells(result)

func _remove_active_cell(cells: Array[Vector2i], target: Vector2i) -> void:
	for index in range(cells.size() - 1, -1, -1):
		if cells[index] == target:
			cells.remove_at(index)
			return

func _has_food_on_cells(character_id: StringName, cells: Array[Vector2i]) -> bool:
	var lookup: Dictionary = ShapeUtils.cells_to_lookup(cells)
	for item in get_character_state(character_id).placed_foods:
		for item_cell in item["cells"]:
			if lookup.has("%d:%d" % [item_cell.x, item_cell.y]):
				return true
	return false

func get_selected_item_summary() -> String:
	if selected_item.is_empty():
		return "未选择物品"
	if selected_item["source"] == &"inventory":
		var item: Dictionary = _find_inventory_item(selected_item["instance_id"])
		if item.is_empty():
			return "未选择物品"
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		return "放置食物: %s" % definition.display_name
	var expansion: Dictionary = _find_pending_expansion(selected_character_id, selected_item["instance_id"])
	if expansion.is_empty():
		return "未选择物品"
	return "放置饭盒拓展: %s" % expansion["label"]

func get_inventory_display_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item in shared_inventory:
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		entries.append({
			"instance_id": item["instance_id"],
			"label": "%s [%s]" % [definition.display_name, definition.category],
			"definition_id": item["definition_id"],
		})
	return entries

func get_grouped_inventory_entries() -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for item in shared_inventory:
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		if definition == null:
			continue
		var key: StringName = definition.id
		if not grouped.has(key):
			grouped[key] = {
				"group_key": key,
				"definition_id": definition.id,
				"display_name": definition.display_name,
				"count": 0,
				"category": definition.category,
				"rarity": definition.rarity,
			}
		grouped[key]["count"] = int(grouped[key]["count"]) + 1
	var entries: Array[Dictionary] = []
	for category_id in CATEGORY_ORDER:
		for group_key in grouped.keys():
			var entry: Dictionary = grouped[group_key]
			if entry.get("category", &"") == category_id:
				entries.append(entry)
	for group_key in grouped.keys():
		var unmatched: Dictionary = grouped[group_key]
		if not entries.has(unmatched):
			entries.append(unmatched)
	for character_id in character_states.keys():
		for pending_variant in character_states[character_id].get("pending_expansions", []):
			var pending: Dictionary = pending_variant
			entries.append({
				"group_key": pending["instance_id"],
				"instance_id": pending["instance_id"],
				"definition_id": &"",
				"display_name": "%s 拓展 %s" % [get_character_display_names().get(character_id, String(character_id)), pending["label"]],
				"count": 1,
				"category": &"expansion",
				"rarity": &"rare",
				"entry_kind": &"expansion",
				"target_character_id": character_id,
				"shape_cells": _clone_cells(pending.get("shape_cells", [])),
				"rotation": int(pending.get("rotation", 0)),
			})
	return entries

func get_pending_expansion_entries(character_id: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item in get_character_state(character_id).get("pending_expansions", []):
		entries.append({
			"instance_id": item["instance_id"],
			"label": "拓展 %s" % item["label"],
		})
	return entries

func get_market_display_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for offer in current_market_offers:
		if offer["kind"] == &"food":
			var definition: FoodDefinition = get_food_definition(offer["definition_id"])
			entries.append({
				"offer_id": offer["offer_id"],
				"label": "%s x%d [%s] - %d金" % [definition.display_name, offer["quantity"], offer["rarity"], offer["price"]],
			})
		else:
			var names: Dictionary = get_character_display_names()
			entries.append({
				"offer_id": offer["offer_id"],
				"label": "%s 给 %s - %d金" % [offer["label"], names.get(offer["target_character_id"], String(offer["target_character_id"])), offer["price"]],
			})
	return entries

func get_market_package_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for offer in current_market_offers:
		var effective_price: int = get_effective_offer_price(offer)
		if offer.get("kind", &"") == &"food":
			var definition: FoodDefinition = get_food_definition(offer["definition_id"])
			if definition == null:
				continue
			entries.append({
				"group_key": offer["offer_id"],
				"offer_id": offer["offer_id"],
				"kind": &"food",
				"definition_id": definition.id,
				"display_name": definition.display_name,
				"count": int(offer.get("quantity", 0)),
				"category": definition.category,
				"rarity": definition.rarity,
				"display_price": effective_price,
				"unit_price": int(offer["price"]),
			})
		else:
			var names: Dictionary = get_character_display_names()
			entries.append({
				"group_key": offer["offer_id"],
				"offer_id": offer["offer_id"],
				"kind": &"expansion",
				"display_name": "拓展 %s" % offer["label"],
				"count": 1,
				"category": &"expansion",
				"rarity": &"rare",
				"display_price": effective_price,
				"unit_price": int(offer["price"]),
				"target_character_id": offer["target_character_id"],
				"target_name": names.get(offer["target_character_id"], String(offer["target_character_id"])),
				"shape_cells": _clone_cells(offer["shape_cells"]),
			})
	return entries

func get_next_monster_summary() -> Dictionary:
	var monster: MonsterDefinition = get_current_monster_definition()
	if monster == null:
		return {}
	return {
		"id": monster.id,
		"display_name": monster.display_name,
		"category": monster.category,
		"category_name": CATEGORY_DISPLAY_NAMES.get(monster.category, String(monster.category)),
		"hp": monster.base_hp,
		"attack": monster.base_attack,
		"attack_interval": monster.attack_interval,
		"skill_summary": monster.skill_summary,
	}

func get_synergy_summary(character_id: StringName) -> Dictionary:
	var category_definition_sets: Dictionary = {}
	for category_id in CATEGORY_ORDER:
		category_definition_sets[category_id] = {}
	var state: Dictionary = get_character_state(character_id)
	for item in state.get("placed_foods", []):
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		for category_id in get_food_categories(definition):
			var definition_set: Dictionary = category_definition_sets.get(category_id, {})
			definition_set[definition.id] = true
			category_definition_sets[category_id] = definition_set
	var entries: Array[Dictionary] = []
	for category_id in CATEGORY_ORDER:
		var count: int = int(category_definition_sets.get(category_id, {}).size())
		entries.append({
			"category_id": category_id,
			"category_name": CATEGORY_DISPLAY_NAMES.get(category_id, String(category_id)),
			"synergy_name": CATEGORY_SYNERGY_NAMES.get(category_id, ""),
			"effect_text": CATEGORY_SYNERGY_EFFECTS.get(category_id, ""),
			"count": count,
			"active": count >= 3,
		})
	return {
		"character_id": character_id,
		"entries": entries,
	}

func resolve_offer_index_by_id(offer_id: StringName) -> int:
	for index in current_market_offers.size():
		if current_market_offers[index]["offer_id"] == offer_id:
			return index
	return -1

func get_action_button_text() -> String:
	if run_finished:
		return "重新开始"
	match get_current_node_type():
		NODE_MARKET:
			return "离开市场"
		NODE_REST:
			return "结束休整"
		NODE_BATTLE, NODE_BOSS_BATTLE:
			return "开始战斗"
		_:
			return "继续"

func get_action_button_visual_key() -> StringName:
	if run_finished:
		return ACTION_BUTTON_RESTART
	match get_current_node_type():
		NODE_BATTLE, NODE_BOSS_BATTLE:
			return ACTION_BUTTON_DEPART
		NODE_MARKET, NODE_REST:
			return ACTION_BUTTON_CONTINUE
		_:
			return ACTION_BUTTON_CONTINUE

func perform_primary_action() -> bool:
	if run_finished:
		start_new_run()
		return true
	match get_current_node_type():
		NODE_MARKET, NODE_REST:
			advance_to_next_node()
			return true
		NODE_BATTLE, NODE_BOSS_BATTLE:
			prepare_battle()
			battle_requested.emit()
			return true
		_:
			return false

func advance_to_next_node() -> void:
	if current_route_index < stage_flow_config.route_nodes.size() - 1:
		current_route_index += 1
		if get_current_node_type() == NODE_MARKET:
			current_market_index = min(current_market_index + 1, 4)
			current_reroll_count = 0
			_generate_market_offers()
	state_changed.emit()

func prepare_battle() -> void:
	pre_battle_snapshot = _capture_snapshot()

func _capture_snapshot() -> Dictionary:
	var result: Dictionary = {
		"character_food_layouts": {},
	}
	for character_id in character_states.keys():
		var layouts: Array[Dictionary] = []
		for placed in character_states[character_id]["placed_foods"]:
			layouts.append({
				"definition_id": placed["definition_id"],
				"anchor": placed["anchor"],
				"rotation": placed["rotation"],
				"cells": _clone_cells(placed["cells"]),
			})
		result["character_food_layouts"][character_id] = layouts
	return result

func apply_battle_report(report: Dictionary) -> void:
	battle_reports.append(report)
	_apply_persistent_health(report)
	if report.get("result", "") == "win":
		_apply_battle_victory(report)
	else:
		run_finished = true
	state_changed.emit()
	battle_finished.emit(report)

func _apply_persistent_health(report: Dictionary) -> void:
	if not report.has("characters"):
		return
	for actor_variant in report["characters"]:
		var actor: Dictionary = actor_variant
		var character_id: StringName = actor.get("id", &"")
		if character_id == &"" or not character_states.has(character_id):
			continue
		var max_hp: float = maxf(float(actor.get("max_hp", 0.0)), 1.0)
		var current_hp: float = clampf(float(actor.get("current_hp", 0.0)), 0.0, max_hp)
		character_states[character_id]["hp_ratio"] = current_hp / max_hp

func get_character_health_display(character_id: StringName) -> Dictionary:
	var actor: Dictionary = CombatEngine.preview_character_actor(self, character_id)
	if actor.is_empty():
		return {
			"current_hp": 0,
			"max_hp": 0,
			"hp_ratio": 0.0,
		}
	return {
		"current_hp": int(round(float(actor.get("current_hp", 0.0)))),
		"max_hp": int(round(float(actor.get("max_hp", 0.0)))),
		"hp_ratio": clampf(float(actor.get("current_hp", 0.0)) / maxf(float(actor.get("max_hp", 1.0)), 1.0), 0.0, 1.0),
	}

func _apply_battle_victory(report: Dictionary) -> void:
	var battle_index: int = get_completed_battle_count() - 1
	if battle_index >= 0 and battle_index < stage_flow_config.normal_battle_reward_gold.size():
		current_gold += stage_flow_config.normal_battle_reward_gold[battle_index]
		current_gold += int(report.get("bonus_gold", 0))
	grant_battle_drops(get_current_monster_definition(), battle_index)
	for character_id in character_states.keys():
		character_states[character_id]["placed_foods"].clear()
	if current_route_index >= stage_flow_config.route_nodes.size() - 1:
		run_finished = true
	else:
		current_route_index += 1
		if get_current_node_type() == NODE_MARKET:
			current_market_index = min(current_market_index + 1, 4)
			current_reroll_count = 0
			_generate_market_offers()

func grant_battle_drops(monster: MonsterDefinition, battle_index: int) -> void:
	if monster == null:
		return
	var target_value: int = 8
	if battle_index >= 0 and battle_index < stage_flow_config.normal_drop_value_curve.size():
		target_value = stage_flow_config.normal_drop_value_curve[battle_index]
	var candidates: Array[FoodDefinition] = []
	for definition in food_catalog.foods:
		if definition.category == monster.category or definition.hybrid_categories.has(monster.category):
			candidates.append(definition)
	if candidates.is_empty():
		return
	var current_value: int = 0
	while current_value < target_value:
		var definition: FoodDefinition = candidates[_rng.randi_range(0, candidates.size() - 1)]
		shared_inventory.append(generate_item_instance(definition.id))
		current_value += definition.gold_value

func try_restore_snapshot() -> bool:
	if pre_battle_snapshot.is_empty():
		return false
	for character_id in character_states.keys():
		character_states[character_id]["placed_foods"].clear()
	var inventory_pool: Array[Dictionary] = shared_inventory.duplicate(true)
	for character_id in pre_battle_snapshot["character_food_layouts"].keys():
		for layout in pre_battle_snapshot["character_food_layouts"][character_id]:
			var found_index: int = -1
			for index in inventory_pool.size():
				if inventory_pool[index]["definition_id"] == layout["definition_id"]:
					found_index = index
					break
			if found_index == -1:
				return false
			var item: Dictionary = inventory_pool[found_index]
			inventory_pool.remove_at(found_index)
			character_states[character_id]["placed_foods"].append({
				"instance_id": item["instance_id"],
				"definition_id": item["definition_id"],
				"rotation": int(layout["rotation"]),
				"anchor": layout["anchor"],
				"cells": _clone_cells(layout["cells"]),
				"reroll_bonus_count": int(item.get("reroll_bonus_count", 0)),
			})
	shared_inventory = inventory_pool
	state_changed.emit()
	return true
