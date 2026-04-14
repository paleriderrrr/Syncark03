extends RefCounted
class_name CombatEngine

const TICK := 0.25
const ATTRITION_START_TIME := 60.0
const ATTRITION_DPS := 7.0

static func simulate(run_state: Object, party_order: Array[StringName] = []) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new()
	return engine._simulate_internal(run_state, party_order)

static func preview_character_actor(run_state: Object, character_id: StringName) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new()
	for actor in engine._build_characters(run_state):
		if actor.get("id", &"") == character_id:
			return actor
	return {}

static func preview_effective_interval(base_interval: float, speed_bonus_pct: float) -> float:
	var engine: CombatEngine = CombatEngine.new()
	return engine._effective_interval(base_interval, speed_bonus_pct)

func _simulate_internal(run_state: Object, party_order: Array[StringName] = []) -> Dictionary:
	var report: Dictionary = {
		"result": "lose",
		"duration": 0.0,
		"log": PackedStringArray(),
		"bonus_gold": 0,
		"monster_id": &"",
		"monster_name": "",
		"title": "",
	}

	var resolved_party_order: Array[StringName] = _resolve_party_order(run_state, party_order)
	var characters: Array[Dictionary] = _build_characters(run_state, resolved_party_order)
	var team_effects: Dictionary = _build_team_effects(characters)
	var monster_multipliers: Dictionary = run_state.get_current_monster_multipliers()
	var monster: Dictionary = _build_monster(
		run_state.get_current_monster_definition(),
		resolved_party_order,
		float(monster_multipliers.get("hp", 1.0)),
		float(monster_multipliers.get("attack", 1.0))
	)
	if monster.is_empty():
		report["title"] = "鎴樻枟閰嶇疆缂哄け"
		return report
	report["monster_id"] = monster["id"]
	report["monster_name"] = monster["name"]

	var time: float = 0.0
	var attrition_started: bool = false
	var log: Array[String] = []

	_apply_monster_opening_skill(monster, characters, log)
	_apply_character_opening_effects(characters, team_effects, log)

	while true:
		_process_timed_team_effects(time, characters, team_effects, monster, log)
		_process_monster_timed_effects(time, monster, characters, log)
		_process_character_status_effects(time, characters, log)
		_apply_regeneration(TICK, time, characters, team_effects, log)

		if time >= ATTRITION_START_TIME:
			if not attrition_started:
				attrition_started = true
				log.append("[60.0s] Battle enters attrition mode.")
			_apply_attrition(TICK, time, monster, characters, log)
		if not bool(monster.get("alive", true)) or monster["current_hp"] <= 0.0:
			report["result"] = "win"
			report["duration"] = time
			break
		if _all_characters_dead(characters):
			report["result"] = "lose"
			report["duration"] = time
			break

		_process_character_attacks(time, characters, monster, team_effects, log)
		if not bool(monster.get("alive", true)) or monster["current_hp"] <= 0.0:
			report["result"] = "win"
			report["duration"] = time
			break
		_process_monster_attack(time, monster, characters, team_effects, log)
		_cleanup_expired_buffs(time, characters)

		if not bool(monster.get("alive", true)) or monster["current_hp"] <= 0.0:
			report["result"] = "win"
			report["duration"] = time
			break
		if _all_characters_dead(characters):
			report["result"] = "lose"
			report["duration"] = time
			break
		time += TICK

	if report["result"] == "win":
		report["title"] = "鎴樻枟鑳滃埄"
		report["bonus_gold"] = _calculate_bonus_gold(run_state, characters, report["duration"])
	else:
		report["title"] = "鎴樻枟澶辫触"
		report["bonus_gold"] = 0
	_cleanup_log(report, log, characters, monster)
	return report

func _build_characters(run_state: Object, party_order: Array[StringName] = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definitions_by_id: Dictionary = {}
	for definition_variant in run_state.character_roster.characters:
		var definition: CharacterDefinition = definition_variant
		definitions_by_id[definition.id] = definition
	for character_id in _resolve_party_order(run_state, party_order):
		var definition: CharacterDefinition = definitions_by_id.get(character_id) as CharacterDefinition
		if definition == null:
			continue
		var board_state: Dictionary = run_state.get_character_state(definition.id)
		var evaluation: Dictionary = _evaluate_character_board(run_state, definition, board_state)
		var actor: Dictionary = {
			"id": definition.id,
			"name": definition.display_name,
			"max_hp": float(definition.base_hp + evaluation["max_hp_bonus"]),
			"current_hp": float(definition.base_hp + evaluation["max_hp_bonus"]) * clampf(float(board_state.get("hp_ratio", 1.0)), 0.0, 1.0),
			"base_hp": float(definition.base_hp),
			"base_attack": float(definition.base_attack),
			"attack_bonus": float(evaluation["attack_bonus"]),
			"base_interval": float(definition.attack_interval),
			"attack_speed_bonus": float(evaluation["attack_speed_bonus"]),
			"bonus_damage": float(evaluation["bonus_damage"]),
			"heal_per_second": float(evaluation["heal_per_second"]),
			"execute_threshold": float(evaluation["execute_threshold"]),
			"retaliate_damage": float(evaluation["retaliate_damage"]),
			"enemy_attack_slow": float(evaluation["enemy_attack_slow"]),
			"first_hit_reduction": float(evaluation["first_hit_reduction"]),
			"first_hit_spent": false,
			"crit_chance": float(evaluation["crit_chance"]),
			"crit_multiplier": float(evaluation["crit_multiplier"]),
			"extra_meat_bonus": float(evaluation["extra_meat_bonus"]),
			"meat_double_below": float(evaluation["meat_double_below"]),
			"revive_pct": float(evaluation["revive_pct"]),
			"revived": false,
			"disable_until": 0.0,
			"next_attack_time": float(definition.attack_interval),
			"temporary_speed_buffs": [],
			"team_aura_flags": evaluation["team_aura_flags"],
			"board_eval": evaluation,
			"dynamic_execute_bonus": 0.0,
			"amber_cancel_chance": float(evaluation["amber_cancel_chance"]),
			"frozen_extra_slow_chance": float(evaluation["frozen_extra_slow_chance"]),
			"forbidden_attack_reduction": float(evaluation["forbidden_attack_reduction"]),
			"economy_gold_bonus": float(evaluation["economy_gold_bonus"]),
			"pudding_heal_amount": float(evaluation["pudding_heal_amount"]),
			"pudding_heal_interval": float(evaluation["pudding_heal_interval"]),
			"pudding_heal_until": float(evaluation["pudding_heal_until"]),
			"adjacent_categories": evaluation["adjacent_categories"],
			"monster_attack_down_stacks": 0,
			"armor_break_stacks": 0,
			"healing_reduction_until": 0.0,
			"healing_reduction_pct": 0.0,
			"corrosion_until": 0.0,
			"corrosion_damage_per_second": 0.0,
			"next_corrosion_tick": 1.0,
			"next_pudding_heal": float(evaluation["pudding_heal_interval"]) if float(evaluation["pudding_heal_amount"]) > 0.0 else -1.0,
			"alive": true,
		}
		if actor["current_hp"] > actor["max_hp"]:
			actor["current_hp"] = actor["max_hp"]
		result.append(actor)
	return result

func _resolve_party_order(run_state: Object, requested_order: Array[StringName]) -> Array[StringName]:
	var roster_order: Array[StringName] = []
	var seen: Dictionary = {}
	for definition_variant in run_state.character_roster.characters:
		var definition: CharacterDefinition = definition_variant
		roster_order.append(definition.id)
	var resolved_order: Array[StringName] = []
	for role_id in requested_order:
		if seen.has(role_id) or not roster_order.has(role_id):
			continue
		seen[role_id] = true
		resolved_order.append(role_id)
	for role_id in roster_order:
		if not seen.has(role_id):
			resolved_order.append(role_id)
	return resolved_order

func _build_team_effects(characters: Array[Dictionary]) -> Dictionary:
	var effects: Dictionary = {
		"dessert_pulse_amount": 0.0,
		"dessert_pulse_interval": 4.0,
		"next_dessert_pulse": 4.0,
		"dessert_multiplier_after_20": false,
		"tree_heal_every": false,
		"next_tree_heal": 15.0,
		"caramel_mille": false,
		"caramel_triggered": false,
		"power_coffee": false,
		"power_coffee_triggered": false,
		"fairy_speed_on_heal": false,
	}
	for actor in characters:
		var flags: Dictionary = actor["team_aura_flags"]
		effects["dessert_pulse_amount"] += float(flags.get("dessert_pulse_amount", 0.0))
		if flags.get("dessert_multiplier_after_20", false):
			effects["dessert_multiplier_after_20"] = true
		if flags.get("tree_heal_every", false):
			effects["tree_heal_every"] = true
		if flags.get("caramel_mille", false):
			effects["caramel_mille"] = true
		if flags.get("power_coffee", false):
			effects["power_coffee"] = true
		if flags.get("fairy_speed_on_heal", false):
			effects["fairy_speed_on_heal"] = true
	return effects

func _build_monster(definition: MonsterDefinition, target_order: Array[StringName] = [], hp_multiplier: float = 1.0, attack_multiplier: float = 1.0) -> Dictionary:
	if definition == null:
		return {}
	var scaled_max_hp: float = float(definition.base_hp) * maxf(hp_multiplier, 0.0)
	var scaled_attack: float = float(definition.base_attack) * maxf(attack_multiplier, 0.0)
	var resolved_target_order: Array[StringName] = target_order.duplicate()
	if resolved_target_order.is_empty():
		resolved_target_order = [&"warrior", &"hunter", &"mage"]
	return {
		"id": definition.id,
		"name": definition.display_name,
		"category": definition.category,
		"max_hp": scaled_max_hp,
		"current_hp": scaled_max_hp,
		"alive": true,
		"base_attack": scaled_attack,
		"attack_multiplier": 1.0,
		"base_interval": float(definition.attack_interval),
		"attack_speed_slow": 0.0,
		"next_attack_time": float(definition.attack_interval),
		"corrosion_damage": 3.0,
		"next_cream_heal_tick": 5.0,
		"wave_active_until": -1.0,
		"wave_recorded_damage": 0.0,
		"next_wave_tick": 5.0,
		"skip_next_attack": false,
		"next_heal_lock_tick": 5.0,
		"target_order": resolved_target_order,
		"crumbs": 3 if definition.id == &"bread_knight" else 0,
		"half_hp_burst_used": false,
		"received_hit_count": 0,
		"attack_count": 0,
	}

func _evaluate_character_board(run_state: Object, definition: CharacterDefinition, board_state: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"max_hp_bonus": 0.0,
		"attack_bonus": 0.0,
		"bonus_damage": 0.0,
		"attack_speed_bonus": 0.0,
		"heal_per_second": 0.0,
		"execute_threshold": 0.0,
		"retaliate_damage": 0.0,
		"enemy_attack_slow": 0.0,
		"first_hit_reduction": 0.0,
		"crit_chance": 0.0,
		"crit_multiplier": 2.0,
		"extra_meat_bonus": 0.0,
		"meat_double_below": 0.0,
		"revive_pct": 0.0,
		"amber_cancel_chance": 0.0,
		"frozen_extra_slow_chance": 0.0,
		"forbidden_attack_reduction": 0.0,
		"economy_gold_bonus": 0.0,
		"pudding_heal_amount": 0.0,
		"pudding_heal_interval": 0.0,
		"pudding_heal_until": 0.0,
		"adjacent_categories": {},
		"team_aura_flags": {},
	}

	var placed_foods: Array = board_state.get("placed_foods", [])
	var disabled_foods: Dictionary = _compute_durian_disabled_items(placed_foods)
	var category_definition_sets: Dictionary = {}
	var category_distinct_count: Dictionary = {}
	var category_cell_count: Dictionary = {}
	var unique_categories: Dictionary = {}

	for item in placed_foods:
		if disabled_foods.has(item["instance_id"]):
			continue
		var food: FoodDefinition = run_state.get_food_definition(item["definition_id"])
		var categories: Array[StringName] = [food.category]
		for hybrid in food.hybrid_categories:
			categories.append(hybrid)
		for category in categories:
			var definition_set: Dictionary = category_definition_sets.get(category, {})
			definition_set[food.id] = true
			category_definition_sets[category] = definition_set
			category_distinct_count[category] = definition_set.size()
			category_cell_count[category] = category_cell_count.get(category, 0) + item["cells"].size()
			unique_categories[category] = true
		result["max_hp_bonus"] += food.hp_bonus
		result["attack_bonus"] += food.attack_bonus
		result["bonus_damage"] += food.bonus_damage
		result["attack_speed_bonus"] += food.attack_speed_percent
		result["heal_per_second"] += food.heal_per_second
		result["execute_threshold"] += food.execute_threshold_percent
		_apply_food_passive(run_state, food, item, placed_foods, board_state, result, unique_categories)

	for item_variant in placed_foods:
		var item: Dictionary = item_variant
		if disabled_foods.has(item["instance_id"]):
			continue
		var definition_post: FoodDefinition = run_state.get_food_definition(item["definition_id"])
		_apply_food_post_passive(run_state, definition_post, item, placed_foods, board_state, result, category_distinct_count, unique_categories)

	var active_bonds: int = 0
	for category in category_distinct_count.keys():
		if int(category_distinct_count[category]) >= 3:
			active_bonds += 1
			var total_cells: int = int(category_cell_count[category])
			match category:
				&"fruit":
					result["retaliate_damage"] += 2.0 + max(total_cells - 3, 0) * 0.5
				&"dessert":
					result["team_aura_flags"]["dessert_pulse_amount"] = float(result["team_aura_flags"].get("dessert_pulse_amount", 0.0)) + 1.0 + floor(max(total_cells - 3, 0) / 2.0)
				&"meat":
					result["extra_meat_bonus"] += 1.0 + floor(max(total_cells - 3, 0) / 3.0) * 0.5
				&"drink":
					result["enemy_attack_slow"] += minf(20.0, 8.0 + max(total_cells - 3, 0) * 1.0)
				&"staple":
					result["execute_threshold"] += minf(8.0, 2.0 + max(total_cells - 3, 0) * 0.5)
				&"spice":
					result["bonus_damage"] += 1.5 + max(total_cells - 3, 0) * 0.5

	if result["team_aura_flags"].has("dessert_pulse_amount"):
		result["team_aura_flags"]["dessert_pulse_amount"] = float(result["team_aura_flags"]["dessert_pulse_amount"])
	if result["team_aura_flags"].get("mixed_feast", false):
		result["attack_bonus"] += active_bonds * 3.0
		result["max_hp_bonus"] += active_bonds * 16.0
		result["attack_speed_bonus"] += active_bonds * 10.0

	return result

func _compute_durian_disabled_items(placed_foods: Array) -> Dictionary:
	var disabled: Dictionary = {}
	var durian_cells: Array[Vector2i] = []
	for item in placed_foods:
		if item["definition_id"] == &"demon_durian":
			for cell in item["cells"]:
				durian_cells.append(cell)
	for item in placed_foods:
		if item["definition_id"] == &"demon_durian":
			continue
		for cell in item["cells"]:
			for durian_cell in durian_cells:
				if abs(cell.x - durian_cell.x) <= 1 and abs(cell.y - durian_cell.y) <= 1:
					disabled[item["instance_id"]] = true
	return disabled

func _apply_food_passive(run_state: Object, food: FoodDefinition, item: Dictionary, placed_foods: Array, board_state: Dictionary, result: Dictionary, unique_categories: Dictionary) -> void:
	var adj: Dictionary = _adjacent_food_categories(item, placed_foods, run_state)
	result["adjacent_categories"][food.id] = adj
	match food.id:
		&"lettuce_leaf":
			if _has_food_above(item, placed_foods):
				result["max_hp_bonus"] += 8.0
		&"lemon":
			result["attack_bonus"] += 1.5 * _count_adjacent_categories(adj, [&"meat", &"staple"])
		&"broccoli":
			result["max_hp_bonus"] += 2.0 * _count_adjacent_empty_cells(item, board_state)
		&"prickly_pear":
			result["retaliate_damage"] *= 1.25
		&"rock_melon":
			result["first_hit_reduction"] = maxf(result["first_hit_reduction"], 0.5)
		&"rosemary_tomato":
			pass
		&"demon_durian":
			result["retaliate_damage"] *= 2.0
		&"tree_fruit":
			result["team_aura_flags"]["tree_heal_every"] = true
		&"pudding_cup":
			result["team_aura_flags"]["pudding"] = true
			result["pudding_heal_amount"] = 8.0
			result["pudding_heal_interval"] = 2.0
			result["pudding_heal_until"] = 10.0
		&"jam_cookie":
			if adj.has(&"fruit"):
				result["max_hp_bonus"] += 8.0
		&"sugar_donut":
			if _donut_center_filled(item, placed_foods):
				result["team_aura_flags"]["dessert_pulse_amount"] = float(result["team_aura_flags"].get("dessert_pulse_amount", 0.0)) + 2.0
		&"cherry_mousse":
			if adj.has(&"drink"):
				result["attack_speed_bonus"] += 10.0
		&"caramel_mille":
			result["team_aura_flags"]["caramel_mille"] = true
		&"puff_tower":
			pass
		&"ice_cream_sundae":
			result["team_aura_flags"]["dessert_multiplier_after_20"] = true
		&"fairy_candy_castle":
			result["team_aura_flags"]["fairy_speed_on_heal"] = true
		&"chicken_steak":
			result["team_aura_flags"]["chicken_steak"] = true
		&"sausage_skewer":
			result["extra_meat_bonus"] += float(_count_adjacent_categories(adj, [&"staple"]))
		&"lamb_rib":
			result["extra_meat_bonus"] += 0.5
		&"tomahawk_steak":
			if adj.has(&"spice"):
				result["crit_chance"] = maxf(result["crit_chance"], 0.25)
		&"flame_sausage":
			result["team_aura_flags"]["flame_sausage"] = true
		&"parma_ham":
			pass
		&"dragon_tail":
			result["meat_double_below"] = 0.4
		&"monster_tartare":
			result["team_aura_flags"]["monster_tartare"] = true
			result["monster_tartare"] = true
		&"soda":
			result["enemy_attack_slow"] += 25.0
		&"matcha":
			if adj.has(&"dessert"):
				result["attack_speed_bonus"] += 10.0
		&"honey_drink":
			result["team_aura_flags"]["honey_drink"] = true
		&"frozen_mint":
			if adj.has(&"staple"):
				result["frozen_extra_slow_chance"] = 0.2
		&"power_coffee":
			result["team_aura_flags"]["power_coffee"] = true
		&"amber_tea":
			pass
		&"cellar_vintage":
			result["attack_speed_bonus"] += 10.0 * int(item.get("reroll_bonus_count", 0))
			result["enemy_attack_slow"] += 5.0 * int(item.get("reroll_bonus_count", 0))
		&"corn_cake":
			if adj.has(&"fruit") and adj.has(&"meat"):
				result["attack_bonus"] += 3.0
		&"baguette":
			result["team_aura_flags"]["baguette"] = true
		&"sandwich":
			result["max_hp_bonus"] += 8.0 * adj.size()
		&"seafood_rice":
			if adj.has(&"drink"):
				result["attack_speed_bonus"] += 4.0
		&"mixed_feast":
			result["team_aura_flags"]["mixed_feast"] = true
		&"dragon_stove":
			pass
		&"godfather":
			pass
		&"salt_pack":
			if _is_below_category(item, placed_foods, run_state, [&"staple", &"meat"]):
				result["bonus_damage"] += 3.0
		&"wasabi":
			result["bonus_damage"] += 3.0
		&"soy_sauce":
			pass
		&"cilantro":
			result["bonus_damage"] += maxf(0.0, 9.0 - 3.0 * _count_adjacent_foods(item, placed_foods))
		&"pepper_bundle":
			if adj.has(&"fruit"):
				result["bonus_damage"] += 1.5
		&"sage_ashes":
			result["revive_pct"] = 0.3
		&"forbidden_herb":
			result["forbidden_attack_reduction"] = 0.05
		_:
			pass

func _adjacent_food_categories(item: Dictionary, placed_foods: Array, run_state: Object) -> Dictionary:
	var categories: Dictionary = {}
	for other in placed_foods:
		if other["instance_id"] == item["instance_id"]:
			continue
		if _items_touch(item, other):
			var definition: FoodDefinition = run_state.get_food_definition(other["definition_id"])
			categories[definition.category] = true
			for hybrid in definition.hybrid_categories:
				categories[hybrid] = true
	return categories

func _items_touch(item_a: Dictionary, item_b: Dictionary) -> bool:
	var lookup: Dictionary = ShapeUtils.cells_to_lookup(item_b["cells"])
	for cell in item_a["cells"]:
		var neighbors := [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
		]
		for neighbor in neighbors:
			if lookup.has("%d:%d" % [neighbor.x, neighbor.y]):
				return true
	return false

func _count_adjacent_categories(adjacency: Dictionary, categories: Array[StringName]) -> int:
	var count: int = 0
	for category in categories:
		if adjacency.has(category):
			count += 1
	return count

func _count_adjacent_empty_cells(item: Dictionary, board_state: Dictionary) -> int:
	var active_lookup: Dictionary = ShapeUtils.cells_to_lookup(board_state.get("active_cells", []))
	var occupied_lookup: Dictionary = ShapeUtils.cells_to_lookup(_flatten_food_cells(board_state.get("placed_foods", [])))
	var seen: Dictionary = {}
	var count: int = 0
	for cell in item["cells"]:
		for neighbor in [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
			Vector2i(cell.x + 1, cell.y + 1),
			Vector2i(cell.x - 1, cell.y - 1),
			Vector2i(cell.x + 1, cell.y - 1),
			Vector2i(cell.x - 1, cell.y + 1),
		]:
			var key: String = "%d:%d" % [neighbor.x, neighbor.y]
			if seen.has(key):
				continue
			seen[key] = true
			if active_lookup.has(key) and not occupied_lookup.has(key):
				count += 1
	return count

func _count_adjacent_foods(item: Dictionary, placed_foods: Array) -> int:
	var count: int = 0
	for other in placed_foods:
		if other["instance_id"] == item["instance_id"]:
			continue
		if _items_touch(item, other):
			count += 1
	return count

func _apply_food_post_passive(run_state: Object, food: FoodDefinition, item: Dictionary, placed_foods: Array, board_state: Dictionary, result: Dictionary, category_distinct_count: Dictionary, unique_categories: Dictionary) -> void:
	match food.id:
		&"rosemary_tomato":
			var adj: Dictionary = _adjacent_food_categories(item, placed_foods, run_state)
			if adj.has(&"spice"):
				result["retaliate_damage"] += float(category_distinct_count.get(&"fruit", 0))
		&"puff_tower":
			if unique_categories.size() >= 3:
				result["attack_speed_bonus"] += 20.0
		&"parma_ham":
			if int(category_distinct_count.get(&"meat", 0)) >= 3:
				result["max_hp_bonus"] += 24.0
		&"amber_tea":
			result["amber_cancel_chance"] += 0.05 * _count_adjacent_items_in_categories(item, placed_foods, run_state, [&"drink"], true)
		&"dragon_stove":
			var category_count: int = unique_categories.size()
			result["max_hp_bonus"] += 4.0 * category_count
			result["attack_bonus"] += 0.75 * category_count
			result["execute_threshold"] += 2.0 * category_count
		&"godfather":
			result["economy_gold_bonus"] += 1.0 * _count_adjacent_empty_cells_orthogonal(item, board_state)
		&"soy_sauce":
			var base_bonus: float = maxf(0.0, result["bonus_damage"] - float(food.bonus_damage))
			result["bonus_damage"] = float(food.bonus_damage) + base_bonus + _count_adjacent_empty_cells_orthogonal(item, board_state)
		_:
			pass

func _flatten_food_cells(placed_foods: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for item in placed_foods:
		for cell in item["cells"]:
			result.append(cell)
	return result

func _count_adjacent_items_in_categories(item: Dictionary, placed_foods: Array, run_state: Object, categories: Array[StringName], include_diagonals: bool) -> int:
	var count: int = 0
	for other_variant in placed_foods:
		var other: Dictionary = other_variant
		if other["instance_id"] == item["instance_id"]:
			continue
		if not _items_touch_mode(item, other, include_diagonals):
			continue
		var definition: FoodDefinition = run_state.get_food_definition(other["definition_id"])
		if definition == null:
			continue
		var food_categories: Array[StringName] = run_state.get_food_categories(definition)
		for category_id in food_categories:
			if categories.has(category_id):
				count += 1
				break
	return count

func _items_touch_mode(item_a: Dictionary, item_b: Dictionary, include_diagonals: bool) -> bool:
	var lookup: Dictionary = ShapeUtils.cells_to_lookup(item_b["cells"])
	for cell_variant in item_a["cells"]:
		var cell: Vector2i = cell_variant
		var neighbors: Array[Vector2i] = [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
		]
		if include_diagonals:
			neighbors.append_array([
				Vector2i(cell.x + 1, cell.y + 1),
				Vector2i(cell.x - 1, cell.y - 1),
				Vector2i(cell.x + 1, cell.y - 1),
				Vector2i(cell.x - 1, cell.y + 1),
			])
		for neighbor in neighbors:
			if lookup.has("%d:%d" % [neighbor.x, neighbor.y]):
				return true
	return false

func _count_adjacent_empty_cells_orthogonal(item: Dictionary, board_state: Dictionary) -> int:
	var active_lookup: Dictionary = ShapeUtils.cells_to_lookup(board_state.get("active_cells", []))
	var occupied_lookup: Dictionary = ShapeUtils.cells_to_lookup(_flatten_food_cells(board_state.get("placed_foods", [])))
	var seen: Dictionary = {}
	var count: int = 0
	for cell_variant in item["cells"]:
		var cell: Vector2i = cell_variant
		for neighbor in [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
		]:
			var key: String = "%d:%d" % [neighbor.x, neighbor.y]
			if seen.has(key):
				continue
			seen[key] = true
			if active_lookup.has(key) and not occupied_lookup.has(key):
				count += 1
	return count

func _has_food_above(item: Dictionary, placed_foods: Array) -> bool:
	var lookup: Dictionary = {}
	for other in placed_foods:
		if other["instance_id"] == item["instance_id"]:
			continue
		for cell in other["cells"]:
			lookup["%d:%d" % [cell.x, cell.y]] = true
	for cell in item["cells"]:
		if lookup.has("%d:%d" % [cell.x, cell.y - 1]):
			return true
	return false

func _donut_center_filled(item: Dictionary, placed_foods: Array) -> bool:
	var min_x: int = item["cells"][0].x
	var max_x: int = item["cells"][0].x
	var min_y: int = item["cells"][0].y
	var max_y: int = item["cells"][0].y
	for cell in item["cells"]:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	var center := Vector2i((min_x + max_x) / 2, (min_y + max_y) / 2)
	for other in placed_foods:
		if other["instance_id"] == item["instance_id"]:
			continue
		for cell in other["cells"]:
			if cell == center:
				return true
	return false

func _is_below_category(item: Dictionary, placed_foods: Array, run_state: Object, categories: Array[StringName]) -> bool:
	for cell in item["cells"]:
		var above := Vector2i(cell.x, cell.y - 1)
		for other in placed_foods:
			if other["instance_id"] == item["instance_id"]:
				continue
			if other["cells"].has(above):
				var definition: FoodDefinition = run_state.get_food_definition(other["definition_id"])
				if categories.has(definition.category):
					return true
	return false

func _apply_monster_opening_skill(monster: Dictionary, characters: Array[Dictionary], log: Array[String]) -> void:
	match monster["id"]:
		&"fruit_tree_king":
			for actor_variant in characters:
				var actor: Dictionary = actor_variant
				actor["corrosion_damage_per_second"] = 1.0
				actor["corrosion_until"] = 15.0
				actor["next_corrosion_tick"] = 1.0
			log.append("[0.0s] %s applies corrosion to all characters." % monster["name"])
		&"charging_beast":
			var living: Array[Dictionary] = []
			for actor_variant in characters:
				var actor: Dictionary = actor_variant
				if actor["alive"]:
					living.append(actor)
			if not living.is_empty():
				var target: Dictionary = living[randi() % living.size()]
				target["disable_until"] = 3.0
				log.append("[0.0s] %s disables %s's bento effects for 3s." % [monster["name"], target["name"]])
		_:
			pass

func _apply_character_opening_effects(characters: Array[Dictionary], team_effects: Dictionary, log: Array[String]) -> void:
	for actor in characters:
		if actor["board_eval"].get("monster_tartare", false):
			actor["current_hp"] = maxf(1.0, actor["current_hp"] - 40.0)
			log.append("[0.0s] %s loses 40 HP from Monster Tartare." % actor["name"])

func _process_timed_team_effects(time: float, characters: Array[Dictionary], team_effects: Dictionary, monster: Dictionary, log: Array[String]) -> void:
	if team_effects["dessert_pulse_amount"] > 0.0 and time >= team_effects["next_dessert_pulse"]:
		var heal_amount: float = float(team_effects["dessert_pulse_amount"])
		if team_effects["dessert_multiplier_after_20"] and time >= 20.0:
			heal_amount *= 1.5
		for actor in characters:
			_heal_actor(actor, heal_amount, log, time)
			if team_effects["fairy_speed_on_heal"]:
				_add_temporary_speed(actor, 10.0, time + 4.0)
		team_effects["next_dessert_pulse"] += team_effects["dessert_pulse_interval"]
	if team_effects["tree_heal_every"] and time >= team_effects["next_tree_heal"]:
		for actor in characters:
			_heal_actor(actor, 10.0, log, time)
		team_effects["next_tree_heal"] += 15.0
	if team_effects["caramel_mille"] and not team_effects["caramel_triggered"] and time >= 20.0:
		team_effects["caramel_triggered"] = true
		for actor in characters:
			actor["attack_speed_bonus"] += 60.0
		log.append("[20.0s] Caramel Mille grants the whole team +60% attack speed.")
	if team_effects["power_coffee"] and not team_effects["power_coffee_triggered"] and time >= 15.0:
		team_effects["power_coffee_triggered"] = true
		for actor in characters:
			actor["attack_speed_bonus"] += 5.0
		log.append("[15.0s] Power Coffee grants the whole team +5% attack speed.")

func _process_monster_timed_effects(time: float, monster: Dictionary, characters: Array[Dictionary], log: Array[String]) -> void:
	if not bool(monster.get("alive", true)):
		return
	if monster["id"] == &"cream_overlord" and time >= float(monster.get("next_cream_heal_tick", 5.0)):
		var heal_amount: float = 20.0
		var before_hp: float = float(monster["current_hp"])
		monster["current_hp"] = minf(monster["max_hp"], monster["current_hp"] + heal_amount)
		var healed_amount: float = float(monster["current_hp"]) - before_hp
		monster["next_cream_heal_tick"] = float(monster.get("next_cream_heal_tick", 5.0)) + 5.0
		if healed_amount > 0.0:
			log.append("[%.1fs] %s restores %.1f HP through Milky Sweetness." % [time, monster["name"], healed_amount])
	if monster["id"] == &"spice_wizard" and time >= float(monster.get("next_heal_lock_tick", 5.0)):
		var living: Array[Dictionary] = []
		for actor_variant in characters:
			var actor: Dictionary = actor_variant
			if actor["alive"]:
				living.append(actor)
		if not living.is_empty():
			var target: Dictionary = living[randi() % living.size()]
			target["healing_reduction_until"] = time + 3.0
			target["healing_reduction_pct"] = 0.5
			log.append("[%.1fs] %s applies heal reduction to %s." % [time, monster["name"], target["name"]])
		monster["next_heal_lock_tick"] = float(monster.get("next_heal_lock_tick", 5.0)) + 5.0

func _process_character_status_effects(time: float, characters: Array[Dictionary], log: Array[String]) -> void:
	for actor_variant in characters:
		var actor: Dictionary = actor_variant
		if not actor["alive"]:
			continue
		while float(actor.get("pudding_heal_amount", 0.0)) > 0.0 and float(actor.get("next_pudding_heal", -1.0)) >= 0.0 and time >= float(actor["next_pudding_heal"]) and float(actor["next_pudding_heal"]) <= float(actor.get("pudding_heal_until", 0.0)):
			if float(actor["next_pudding_heal"]) >= float(actor.get("disable_until", 0.0)):
				_heal_actor(actor, float(actor["pudding_heal_amount"]), log, float(actor["next_pudding_heal"]))
			actor["next_pudding_heal"] = float(actor["next_pudding_heal"]) + float(actor.get("pudding_heal_interval", 0.0))
		if actor["corrosion_damage_per_second"] > 0.0 and time >= actor["next_corrosion_tick"] and time <= actor["corrosion_until"]:
			actor["next_corrosion_tick"] += 1.0
			_apply_damage_to_actor(actor, actor["corrosion_damage_per_second"], log, time, "Corrosion")

func _apply_regeneration(delta: float, time: float, characters: Array[Dictionary], team_effects: Dictionary, log: Array[String]) -> void:
	for actor_variant in characters:
		var actor: Dictionary = actor_variant
		if actor["alive"] and actor["heal_per_second"] > 0.0:
			_heal_actor(actor, actor["heal_per_second"] * delta, log, time)

func _apply_attrition(delta: float, time: float, monster: Dictionary, characters: Array[Dictionary], log: Array[String]) -> void:
	monster["current_hp"] -= ATTRITION_DPS * delta
	if monster["current_hp"] <= 0.0:
		_handle_monster_death(monster, log, time)
	for actor in characters:
		if actor["alive"]:
			actor["current_hp"] -= ATTRITION_DPS * delta
			if actor["current_hp"] <= 0.0:
				_handle_actor_death(actor, log, ATTRITION_START_TIME)

func _process_character_attacks(time: float, characters: Array[Dictionary], monster: Dictionary, team_effects: Dictionary, log: Array[String]) -> void:
	for actor in characters:
		if not actor["alive"] or not bool(monster.get("alive", true)) or monster["current_hp"] <= 0.0:
			continue
		if time + 0.001 < actor["next_attack_time"]:
			continue
		var attack_data: Dictionary = _calculate_actor_attack(actor, time)
		var damage: float = float(attack_data["damage"])
		var speed_bonus_pct: float = float(attack_data["speed_bonus_pct"])
		if randf() < actor["crit_chance"]:
			damage *= actor["crit_multiplier"]
			log.append("[%.1fs] %s lands a critical hit for %.1f." % [time, actor["name"], damage])
		damage = _apply_monster_incoming_damage_modifiers(monster, damage)
		monster["current_hp"] -= damage
		_handle_monster_hit_by_character(monster, actor, characters, damage, time, log)
		if actor["forbidden_attack_reduction"] > 0.0 and damage > 0.0:
			monster["attack_multiplier"] *= maxf(0.1, 1.0 - actor["forbidden_attack_reduction"])
		if actor["amber_cancel_chance"] > 0.0 and randf() < actor["amber_cancel_chance"]:
			monster["skip_next_attack"] = true
		if actor["frozen_extra_slow_chance"] > 0.0 and randf() < actor["frozen_extra_slow_chance"]:
			monster["attack_speed_slow"] = minf(80.0, monster["attack_speed_slow"] + 5.0)
		if attack_data["extra_enemy_slow"] > 0.0:
			monster["attack_speed_slow"] = minf(80.0, monster["attack_speed_slow"] + attack_data["extra_enemy_slow"])
		if actor["execute_threshold"] + actor["dynamic_execute_bonus"] > 0.0 and monster["current_hp"] / monster["max_hp"] <= (actor["execute_threshold"] + actor["dynamic_execute_bonus"]) / 100.0:
			monster["current_hp"] = 0.0
			log.append("[%.1fs] %s executes %s." % [time, actor["name"], monster["name"]])
		else:
			log.append("[%.1fs] %s deals %.1f damage to %s." % [time, actor["name"], damage, monster["name"]])
		if monster["current_hp"] <= 0.0:
			_handle_monster_death(monster, log, time)
		if actor["board_eval"].get("baguette", false):
			actor["dynamic_execute_bonus"] += 2.0
		actor["next_attack_time"] = time + _effective_interval(actor["base_interval"], speed_bonus_pct + _temporary_speed(actor))

func _calculate_actor_attack(actor: Dictionary, time: float) -> Dictionary:
	var bonuses_active: bool = time >= float(actor["disable_until"])
	var attack: float = float(actor["base_attack"])
	var bonus_damage: float = 0.0
	var speed_bonus: float = 0.0
	var extra_enemy_slow: float = 0.0
	if bonuses_active:
		attack += actor["attack_bonus"] - float(actor.get("monster_attack_down_stacks", 0))
		attack = maxf(0.0, attack)
		bonus_damage += actor["bonus_damage"]
		speed_bonus += actor["attack_speed_bonus"]
		var hp_ratio: float = float(actor["current_hp"]) / maxf(float(actor["max_hp"]), 1.0)
		if actor["extra_meat_bonus"] > 0.0 and hp_ratio < 0.5:
			var steps: float = floor((0.5 - hp_ratio) / 0.05) + 1.0
			var bonus_pct: float = steps * float(actor["extra_meat_bonus"])
			if actor["meat_double_below"] > 0.0 and hp_ratio <= actor["meat_double_below"]:
				bonus_pct *= 2.0
			attack *= 1.0 + bonus_pct / 100.0
		if actor["board_eval"].get("chicken_steak", false) and hp_ratio < 0.5:
			attack += 3.0
		if actor["board_eval"].get("flame_sausage", false):
			speed_bonus += 8.0
		if actor["board_eval"].get("honey_drink", false):
			extra_enemy_slow += 5.0
		if actor["board_eval"].get("parma_ham", false):
			pass
		if actor["board_eval"].get("monster_tartare", false):
			var lost_ratio: float = 1.0 - hp_ratio
			attack += floor(lost_ratio / 0.1) * 3.0
	attack += 0.0
	return {
		"damage": attack + bonus_damage,
		"speed_bonus_pct": speed_bonus,
		"extra_enemy_slow": extra_enemy_slow,
	}

func _process_monster_attack(time: float, monster: Dictionary, characters: Array[Dictionary], team_effects: Dictionary, log: Array[String]) -> void:
	if not bool(monster.get("alive", true)) or monster["current_hp"] <= 0.0:
		return
	if time + 0.001 < monster["next_attack_time"]:
		return
	if monster["skip_next_attack"]:
		monster["skip_next_attack"] = false
		monster["next_attack_time"] = time + _effective_interval(monster["base_interval"], -monster["attack_speed_slow"])
		log.append("[%.1fs] %s's next attack is cancelled." % [time, monster["name"]])
		return
	var target: Dictionary = _select_monster_target(characters, monster["target_order"])
	if target.is_empty():
		return
	var damage: float = float(monster["base_attack"]) * float(monster["attack_multiplier"])
	if monster["id"] == &"water_giant":
		var hp_ratio: float = float(target["current_hp"]) / maxf(float(target["max_hp"]), 1.0)
		if hp_ratio > 0.5:
			damage += 3.0
	if monster["id"] == &"spice_wizard" and time < float(target.get("healing_reduction_until", 0.0)):
		damage += float(target["current_hp"]) * 0.01
	if target["first_hit_reduction"] > 0.0 and not target["first_hit_spent"]:
		damage *= (1.0 - target["first_hit_reduction"])
		target["first_hit_spent"] = true
	var source_name: String = String(monster["name"])
	_apply_damage_to_actor(target, damage, log, time, source_name)
	if target["alive"] and target["retaliate_damage"] > 0.0 and time >= target["disable_until"]:
		monster["current_hp"] -= target["retaliate_damage"]
		log.append("[%.1fs] %s retaliates for %.1f damage." % [time, target["name"], target["retaliate_damage"]])
		if monster["current_hp"] <= 0.0:
			_handle_monster_death(monster, log, time)
	if monster["id"] == &"bread_knight" and target["alive"]:
		target["armor_break_stacks"] = mini(int(target.get("armor_break_stacks", 0)) + 1, 5)
	if monster["id"] == &"nc2_auto_cooker":
		monster["attack_count"] = int(monster.get("attack_count", 0)) + 1
		if int(monster["attack_count"]) % 3 == 0:
			target["disable_until"] = maxf(float(target.get("disable_until", 0.0)), time + 3.0)
	monster["next_attack_time"] = time + _effective_interval(monster["base_interval"], -monster["attack_speed_slow"])

func _apply_monster_incoming_damage_modifiers(monster: Dictionary, damage: float) -> float:
	var final_damage: float = damage
	if monster["id"] == &"bread_knight" and int(monster.get("crumbs", 0)) > 0:
		monster["crumbs"] = int(monster["crumbs"]) - 1
		return 0.0
	if monster["id"] == &"water_giant":
		var hp_ratio: float = float(monster["current_hp"]) / maxf(float(monster["max_hp"]), 1.0)
		if hp_ratio <= 0.5:
			final_damage = maxf(0.0, final_damage - 1.0)
	return final_damage

func _handle_monster_hit_by_character(monster: Dictionary, attacker: Dictionary, characters: Array[Dictionary], damage: float, time: float, log: Array[String]) -> void:
	if not bool(monster.get("alive", true)):
		return
	match monster["id"]:
		&"cream_overlord":
			attacker["monster_attack_down_stacks"] = mini(int(attacker.get("monster_attack_down_stacks", 0)) + 1, 5)
		&"charging_beast":
			if not bool(monster.get("half_hp_burst_used", false)) and float(monster["current_hp"]) <= float(monster["max_hp"]) * 0.5:
				var living: Array[Dictionary] = []
				for actor_variant in characters:
					var actor: Dictionary = actor_variant
					if actor["alive"]:
						living.append(actor)
				if not living.is_empty():
					var target: Dictionary = living[randi() % living.size()]
					monster["half_hp_burst_used"] = true
					log.append("[%.1fs] %s unleashes Burst Charge." % [time, monster["name"]])
					_apply_damage_to_actor(target, 35.0, log, time, monster["name"])
		&"nc2_auto_cooker":
			monster["received_hit_count"] = int(monster.get("received_hit_count", 0)) + 1
			if int(monster["received_hit_count"]) % 30 == 0:
				var rotated: Array = []
				var order: Array = monster.get("target_order", [])
				if order.size() > 1:
					rotated = order.slice(1, order.size())
					rotated.append(order[0])
					monster["target_order"] = rotated
					log.append("[%.1fs] %s shifts target order." % [time, monster["name"]])
		_:
			pass

func _handle_monster_death(monster: Dictionary, log: Array[String], time: float) -> void:
	if not bool(monster.get("alive", true)):
		return
	monster["alive"] = false
	monster["current_hp"] = 0.0
	log.append("[%.1fs] %s is defeated." % [time, monster["name"]])

func _select_monster_target(characters: Array[Dictionary], order: Array) -> Dictionary:
	for role_id in order:
		for actor in characters:
			if actor["id"] == role_id and actor["alive"]:
				return actor
	return {}

func _apply_damage_to_actor(actor: Dictionary, amount: float, log: Array[String], time: float, source_name: String) -> void:
	if not actor["alive"]:
		return
	var final_amount: float = amount
	if float(actor.get("armor_break_stacks", 0)) > 0:
		final_amount *= 1.0 + 0.1 * float(actor["armor_break_stacks"])
	actor["current_hp"] -= final_amount
	log.append("[%.1fs] %s deals %.1f damage to %s." % [time, source_name, final_amount, actor["name"]])
	if actor["current_hp"] <= 0.0:
		if actor["revive_pct"] > 0.0 and not actor["revived"]:
			actor["revived"] = true
			actor["current_hp"] = actor["max_hp"] * actor["revive_pct"]
			log.append("[%.1fs] %s revives with %.1f HP." % [time, actor["name"], actor["current_hp"]])
		else:
			_handle_actor_death(actor, log, time)

func _handle_actor_death(actor: Dictionary, log: Array[String], time: float) -> void:
	actor["alive"] = false
	actor["current_hp"] = 0.0
	log.append("[%.1fs] %s is defeated." % [time, actor["name"]])

func _heal_actor(actor: Dictionary, amount: float, log: Array[String], time: float) -> void:
	if not actor["alive"] or amount <= 0.0:
		return
	var final_amount: float = amount
	if time < float(actor.get("healing_reduction_until", 0.0)):
		final_amount *= 1.0 - float(actor.get("healing_reduction_pct", 0.0))
	var before: float = float(actor["current_hp"])
	actor["current_hp"] = minf(actor["max_hp"], actor["current_hp"] + final_amount)
	var healed: float = float(actor["current_hp"]) - before
	if healed > 0.0:
		log.append("[%.1fs] %s restores %.1f HP." % [time, actor["name"], healed])

func _add_temporary_speed(actor: Dictionary, amount: float, expires_at: float) -> void:
	actor["temporary_speed_buffs"].append({
		"value": amount,
		"expires_at": expires_at,
	})

func _temporary_speed(actor: Dictionary) -> float:
	var total: float = 0.0
	for buff in actor["temporary_speed_buffs"]:
		total += buff["value"]
	return total

func _cleanup_expired_buffs(time: float, characters: Array[Dictionary]) -> void:
	for actor in characters:
		var active: Array[Dictionary] = []
		for buff in actor["temporary_speed_buffs"]:
			if float(buff["expires_at"]) > time:
				active.append(buff)
		actor["temporary_speed_buffs"] = active

func _effective_interval(base_interval: float, speed_bonus_pct: float) -> float:
	if speed_bonus_pct >= 0.0:
		return maxf(0.15, base_interval / (1.0 + speed_bonus_pct / 100.0))
	return maxf(0.15, base_interval * (1.0 + abs(speed_bonus_pct) / 100.0))

func _all_characters_dead(characters: Array[Dictionary]) -> bool:
	for actor in characters:
		if actor["alive"]:
			return false
	return true

func _calculate_bonus_gold(run_state: Object, characters: Array[Dictionary], duration: float) -> int:
	var battle_index: int = run_state.get_completed_battle_count()
	if battle_index < 0 or battle_index >= run_state.stage_flow_config.normal_battle_reward_gold.size():
		return 0
	var base_gold: int = run_state.stage_flow_config.normal_battle_reward_gold[battle_index]
	var hp_ratio: float = 0.0
	for actor in characters:
		hp_ratio += actor["current_hp"] / maxf(actor["max_hp"], 1.0)
	hp_ratio /= maxf(float(characters.size()), 1.0)
	var time_score: float = clampf(1.0 - duration / ATTRITION_START_TIME, 0.0, 1.0)
	var performance_bonus: int = int(round(base_gold * 0.5 * ((hp_ratio + time_score) * 0.5)))
	var economy_bonus: int = 0
	for actor in characters:
		economy_bonus += int(round(float(actor.get("economy_gold_bonus", 0.0))))
	return performance_bonus + economy_bonus

func _cleanup_log(report: Dictionary, log: Array[String], characters: Array[Dictionary], monster: Dictionary) -> void:
	var trimmed: Array[String] = log
	if trimmed.size() > 120:
		trimmed = trimmed.slice(trimmed.size() - 120, trimmed.size())
	report["log"] = PackedStringArray(trimmed)
	var summaries: Array[Dictionary] = []
	for actor in characters:
		summaries.append({
			"id": actor["id"],
			"name": actor["name"],
			"current_hp": actor["current_hp"],
			"max_hp": actor["max_hp"],
			"alive": actor["alive"],
		})
	report["characters"] = summaries
	report["monster_id"] = monster["id"]
	report["monster_hp"] = monster["current_hp"]
	report["monster_max_hp"] = monster["max_hp"]
