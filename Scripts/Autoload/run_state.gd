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

const GRID_WIDTH := 6
const GRID_HEIGHT := 8
const NODE_MARKET: StringName = &"market"
const NODE_BATTLE: StringName = &"battle"
const NODE_REST: StringName = &"rest"
const NODE_BOSS_BATTLE: StringName = &"boss_battle"

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
		var base_cells: Array[Vector2i] = []
		for y in 3:
			for x in 3:
				base_cells.append(Vector2i(x, y))
		character_states[definition.id] = {
			"id": definition.id,
			"active_cells": base_cells,
			"placed_foods": [],
			"pending_expansions": [],
			"placed_expansions": [],
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
			return "甯傚満"
		NODE_BATTLE:
			return "鎴樻枟"
		NODE_REST:
			return "浼戞暣"
		NODE_BOSS_BATTLE:
			return "Boss 鎴樻枟"
		_:
			return String(node_type)

func get_route_label() -> String:
	if stage_flow_config == null or stage_flow_config.route_nodes.is_empty():
		return "Route Unavailable"
	var current_label: String = get_node_display_name(get_current_node_type())
	return "Node %d / %d: %s" % [current_route_index + 1, stage_flow_config.route_nodes.size(), current_label]

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

func get_current_market_tier() -> int:
	return clamp(current_market_index, 1, 4)

func _generate_market_offers() -> void:
	current_market_offers.clear()
	current_reroll_count = 0 if current_market_offers.is_empty() else current_reroll_count
	if get_current_node_type() != NODE_MARKET:
		state_changed.emit()
		return
	for slot_index in market_config.slot_count:
		if _rng.randf() < market_config.expansion_slot_chance:
			current_market_offers.append(_roll_expansion_offer(slot_index))
		else:
			current_market_offers.append(_roll_food_offer(slot_index))
	state_changed.emit()

func refresh_market_offers() -> bool:
	if get_current_node_type() != NODE_MARKET:
		return false
	var curve: PackedInt32Array = market_config.reroll_cost_curve
	var cost: int = curve[min(current_reroll_count, curve.size() - 1)]
	if current_gold < cost:
		return false
	current_gold -= cost
	current_reroll_count += 1
	_increment_cellar_vintage_bonuses()
	current_market_offers.clear()
	for slot_index in market_config.slot_count:
		if _rng.randf() < market_config.expansion_slot_chance:
			current_market_offers.append(_roll_expansion_offer(slot_index))
		else:
			current_market_offers.append(_roll_food_offer(slot_index))
	state_changed.emit()
	return true

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

func _roll_food_offer(slot_index: int) -> Dictionary:
	var weights: Dictionary = _get_rarity_weights_for_market()
	var rarity: StringName = _pick_rarity(weights)
	var candidates: Array[FoodDefinition] = []
	for definition in food_catalog.foods:
		if definition.rarity == rarity:
			candidates.append(definition)
	if candidates.is_empty():
		candidates = food_catalog.foods
	var definition: FoodDefinition = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var range: Vector2i = market_config.quantity_ranges.get(String(rarity), Vector2i.ONE)
	var quantity: int = _rng.randi_range(range.x, range.y)
	var discount: float = _roll_discount()
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
	if get_current_node_type() == NODE_MARKET:
		while current_market_offers.size() < market_config.slot_count:
			var slot_index: int = current_market_offers.size()
			if _rng.randf() < market_config.expansion_slot_chance:
				current_market_offers.append(_roll_expansion_offer(slot_index))
			else:
				current_market_offers.append(_roll_food_offer(slot_index))
	state_changed.emit()
	return true

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
		for cell in placed_cells:
			state["active_cells"].append(cell)
		_remove_pending_expansion(selected_character_id, pending["instance_id"])
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
			for placed_cell in item["cells"]:
				_remove_active_cell(state["active_cells"], placed_cell)
			state["pending_expansions"].append({
				"instance_id": item["instance_id"],
				"label": item["label"],
				"shape_cells": ShapeUtils.rotate_cells(_derive_shape_from_placed_cells(item["cells"], item["anchor"]), 0),
				"rotation": 0,
				"target_character_id": selected_character_id,
			})
			state["placed_expansions"].remove_at(index)
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
	if report.get("result", "") == "win":
		_apply_battle_victory(report)
	else:
		run_finished = true
	state_changed.emit()
	battle_finished.emit(report)

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
