extends RefCounted
class_name CombatEngine

const TICK := 0.25
const MAX_DURATION := 120.0
const ATTRITION_DPS := 8.0

static func simulate(run_state: Node) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new()
	return engine._simulate_internal(run_state)

static func preview_character_actor(run_state: Node, character_id: StringName) -> Dictionary:
	var engine: CombatEngine = CombatEngine.new()
	for actor in engine._build_characters(run_state):
		if actor.get("id", &"") == character_id:
			return actor
	return {}

func _simulate_internal(run_state: Node) -> Dictionary:
	var report: Dictionary = {
		"result": "lose",
		"duration": 0.0,
		"log": PackedStringArray(),
		"bonus_gold": 0,
		"monster_name": "",
		"title": "",
	}

	var characters: Array[Dictionary] = _build_characters(run_state)
	var team_effects: Dictionary = _build_team_effects(characters)
	var monster: Dictionary = _build_monster(run_state.get_current_monster_definition())
	if monster.is_empty():
		report["title"] = "战斗配置缺失"
		return report
	report["monster_name"] = monster["name"]

	var time: float = 0.0
	var attrition_started: bool = false
	var log: Array[String] = []

	_apply_monster_opening_skill(monster, characters, log)
	_apply_character_opening_effects(characters, team_effects, log)

	while time <= MAX_DURATION + 30.0:
		_process_timed_team_effects(time, characters, team_effects, monster, log)
		_process_monster_timed_effects(time, monster, characters, log)
		_apply_regeneration(TICK, characters, team_effects)

		if time >= MAX_DURATION:
			if not attrition_started:
				attrition_started = true
				log.append("[120.0s] 战斗进入超时阶段，双方开始持续掉血。")
			_apply_attrition(TICK, monster, characters, log)

		_process_character_attacks(time, characters, monster, team_effects, log)
		_process_monster_attack(time, monster, characters, team_effects, log)
		_cleanup_expired_buffs(time, characters)

		if monster["current_hp"] <= 0.0:
			report["result"] = "win"
			report["duration"] = time
			break
		if _all_characters_dead(characters):
			report["result"] = "lose"
			report["duration"] = time
			break
		time += TICK

	if report["result"] == "win":
		report["title"] = "战斗胜利"
		report["bonus_gold"] = _calculate_bonus_gold(run_state, characters, report["duration"])
	else:
		report["title"] = "战斗失败"
		report["bonus_gold"] = 0
	_cleanup_log(report, log, characters, monster)
	return report

func _build_characters(run_state: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in run_state.character_roster.characters:
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
			"adjacent_categories": evaluation["adjacent_categories"],
			"alive": true,
		}
		if actor["current_hp"] > actor["max_hp"]:
			actor["current_hp"] = actor["max_hp"]
		result.append(actor)
	return result

func _build_team_effects(characters: Array[Dictionary]) -> Dictionary:
	var effects: Dictionary = {
		"dessert_pulse_amount": 0.0,
		"dessert_pulse_interval": 3.0,
		"next_dessert_pulse": 3.0,
		"dessert_multiplier_after_20": false,
		"tree_heal_every": false,
		"next_tree_heal": 15.0,
		"caramel_triggered": false,
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
		if flags.get("fairy_speed_on_heal", false):
			effects["fairy_speed_on_heal"] = true
	return effects

func _build_monster(definition: MonsterDefinition) -> Dictionary:
	if definition == null:
		return {}
	return {
		"id": definition.id,
		"name": definition.display_name,
		"category": definition.category,
		"max_hp": float(definition.base_hp),
		"current_hp": float(definition.base_hp),
		"base_attack": float(definition.base_attack),
		"attack_multiplier": 1.0,
		"base_interval": float(definition.attack_interval),
		"attack_speed_slow": 0.0,
		"next_attack_time": float(definition.attack_interval),
		"corrosion_damage": 3.0,
		"damage_taken_window": 0.0,
		"next_satisfaction_tick": 5.0,
		"wave_active_until": -1.0,
		"wave_recorded_damage": 0.0,
		"next_wave_tick": 5.0,
		"skip_next_attack": false,
		"next_swap_tick": 10.0,
		"target_order": [&"warrior", &"hunter", &"mage"],
		"crumbs": 10,
	}

func _evaluate_character_board(run_state: Node, definition: CharacterDefinition, board_state: Dictionary) -> Dictionary:
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
		"adjacent_categories": {},
		"team_aura_flags": {},
	}

	var placed_foods: Array = board_state.get("placed_foods", [])
	var disabled_foods: Dictionary = _compute_durian_disabled_items(placed_foods)
	var category_item_count: Dictionary = {}
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
			category_item_count[category] = category_item_count.get(category, 0) + 1
			category_cell_count[category] = category_cell_count.get(category, 0) + item["cells"].size()
			unique_categories[category] = true
		result["max_hp_bonus"] += food.hp_bonus
		result["attack_bonus"] += food.attack_bonus
		result["bonus_damage"] += food.bonus_damage
		result["attack_speed_bonus"] += food.attack_speed_percent
		result["heal_per_second"] += food.heal_per_second
		result["execute_threshold"] += food.execute_threshold_percent
		_apply_food_passive(run_state, food, item, placed_foods, board_state, result, unique_categories)

	var active_bonds: int = 0
	for category in category_item_count.keys():
		if int(category_item_count[category]) >= 3:
			active_bonds += 1
			var total_cells: int = int(category_cell_count[category])
			match category:
				&"fruit":
					result["retaliate_damage"] += 1.0 + max(total_cells - 3, 0) * 0.5
				&"dessert":
					result["team_aura_flags"]["dessert_pulse_amount"] = float(result["team_aura_flags"].get("dessert_pulse_amount", 0.0)) + 3.0 + max(total_cells - 3, 0)
				&"meat":
					result["extra_meat_bonus"] += 1.5 + floor(max(total_cells - 3, 0) / 2.0)
				&"drink":
					result["enemy_attack_slow"] += minf(50.0, 5.0 + max(total_cells - 3, 0) * 1.5)
				&"staple":
					result["execute_threshold"] += minf(20.0, 5.0 + max(total_cells - 3, 0))
				&"spice":
					result["bonus_damage"] += 1.0 + max(total_cells - 3, 0) * 0.5

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

func _apply_food_passive(run_state: Node, food: FoodDefinition, item: Dictionary, placed_foods: Array, board_state: Dictionary, result: Dictionary, unique_categories: Dictionary) -> void:
	var adj: Dictionary = _adjacent_food_categories(item, placed_foods, run_state)
	result["adjacent_categories"][food.id] = adj
	match food.id:
		&"lettuce_leaf":
			if _has_food_above(item, placed_foods):
				result["max_hp_bonus"] += 16.0
		&"lemon":
			result["attack_bonus"] += 2.0 * _count_adjacent_categories(adj, [&"meat", &"staple"])
		&"broccoli":
			result["max_hp_bonus"] += 5.0 * _count_adjacent_empty_cells(item, board_state)
		&"prickly_pear":
			result["retaliate_damage"] *= 1.25
		&"rock_melon":
			result["first_hit_reduction"] = maxf(result["first_hit_reduction"], 0.5)
		&"rosemary_tomato":
			if adj.has(&"spice"):
				result["retaliate_damage"] += float(result["retaliate_damage"])
		&"demon_durian":
			result["retaliate_damage"] *= 2.0
		&"tree_fruit":
			result["team_aura_flags"]["tree_heal_every"] = true
		&"pudding_cup":
			result["team_aura_flags"]["pudding"] = true
		&"jam_cookie":
			if adj.has(&"fruit"):
				result["max_hp_bonus"] += 16.0
		&"sugar_donut":
			if _donut_center_filled(item, placed_foods):
				result["team_aura_flags"]["dessert_pulse_amount"] = float(result["team_aura_flags"].get("dessert_pulse_amount", 0.0)) + 8.0
		&"cherry_mousse":
			if adj.has(&"drink"):
				result["attack_speed_bonus"] += 10.0
		&"caramel_mille":
			result["team_aura_flags"]["caramel_mille"] = true
		&"puff_tower":
			if unique_categories.size() >= 3:
				result["attack_speed_bonus"] += 50.0
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
			result["team_aura_flags"]["parma_ham"] = true
		&"dragon_tail":
			result["meat_double_below"] = 0.4
		&"monster_tartare":
			result["team_aura_flags"]["monster_tartare"] = true
			result["monster_tartare"] = true
		&"soda":
			result["enemy_attack_slow"] += 25.0
		&"matcha":
			if adj.has(&"dessert"):
				result["attack_speed_bonus"] += 20.0
		&"honey_drink":
			result["team_aura_flags"]["honey_drink"] = true
		&"frozen_mint":
			if adj.has(&"staple"):
				result["frozen_extra_slow_chance"] = 0.2
		&"power_coffee":
			result["team_aura_flags"]["power_coffee"] = true
		&"amber_tea":
			result["amber_cancel_chance"] += 0.05 * _count_adjacent_categories(adj, [&"drink"])
		&"cellar_vintage":
			result["attack_speed_bonus"] += 10.0 * int(item.get("reroll_bonus_count", 0))
			result["enemy_attack_slow"] += 5.0 * int(item.get("reroll_bonus_count", 0))
		&"corn_cake":
			if adj.has(&"fruit") and adj.has(&"meat"):
				result["attack_bonus"] += 5.0
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
			var count: int = unique_categories.size()
			result["max_hp_bonus"] += 8.0 * count
			result["attack_bonus"] += 1.5 * count
			result["execute_threshold"] += 5.0 * count
		&"salt_pack":
			if _is_below_category(item, placed_foods, run_state, [&"staple", &"meat"]):
				result["bonus_damage"] += 5.0
		&"wasabi":
			result["bonus_damage"] += 1.0
		&"soy_sauce":
			result["bonus_damage"] += _count_adjacent_empty_cells(item, board_state)
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

func _adjacent_food_categories(item: Dictionary, placed_foods: Array, run_state: Node) -> Dictionary:
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

func _flatten_food_cells(placed_foods: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for item in placed_foods:
		for cell in item["cells"]:
			result.append(cell)
	return result

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

func _is_below_category(item: Dictionary, placed_foods: Array, run_state: Node, categories: Array[StringName]) -> bool:
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
		&"charging_beast":
			var living: Array = characters.filter(func(actor: Dictionary) -> bool: return actor["alive"])
			if not living.is_empty():
				var target: Dictionary = living[randi() % living.size()]
				target["disable_until"] = 5.0
				log.append("[0.0s] %s 使 %s 的饭盒效果失效5秒。" % [monster["name"], target["name"]])
		_:
			pass

func _apply_character_opening_effects(characters: Array[Dictionary], team_effects: Dictionary, log: Array[String]) -> void:
	for actor in characters:
		if actor["board_eval"].get("monster_tartare", false):
			actor["current_hp"] = maxf(1.0, actor["current_hp"] - 40.0)
			log.append("[0.0s] %s 受到怪物鞑靼的开场自伤40点。" % actor["name"])

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
	if not team_effects["caramel_triggered"] and time >= 20.0:
		team_effects["caramel_triggered"] = true
		for actor in characters:
			actor["attack_speed_bonus"] += 60.0
		log.append("[20.0s] 焦糖千层触发，全队攻速提升60%。")
	if not team_effects["power_coffee_triggered"] and time >= 15.0:
		team_effects["power_coffee_triggered"] = true
		for actor in characters:
			actor["attack_speed_bonus"] += 5.0
		log.append("[15.0s] 超给力咖啡触发，全队攻速提升5%。")

func _process_monster_timed_effects(time: float, monster: Dictionary, characters: Array[Dictionary], log: Array[String]) -> void:
	if monster["id"] == &"cream_overlord" and time >= monster["next_satisfaction_tick"]:
		var heal_amount: float = float(monster["damage_taken_window"]) * 0.5
		monster["current_hp"] = minf(monster["max_hp"], monster["current_hp"] + heal_amount)
		monster["damage_taken_window"] = 0.0
		monster["next_satisfaction_tick"] += 5.0
		log.append("[%.1fs] %s 回复 %.1f 生命。" % [time, monster["name"], heal_amount])
	if monster["id"] == &"water_giant":
		if time >= monster["next_wave_tick"]:
			monster["wave_active_until"] = time + 4.0
			monster["wave_recorded_damage"] = 0.0
			monster["next_wave_tick"] += 5.0
			log.append("[%.1fs] %s 聚集浪花，开始记录4秒内受到的伤害。" % [time, monster["name"]])
		elif monster["wave_active_until"] > 0.0 and time >= monster["wave_active_until"]:
			var splash: float = float(monster["wave_recorded_damage"]) * 0.4
			for actor in characters:
				if actor["alive"]:
					_apply_damage_to_actor(actor, splash, log, time, monster["name"])
			monster["wave_active_until"] = -1.0
			monster["wave_recorded_damage"] = 0.0
			log.append("[%.1fs] %s 的浪花爆发，对全队造成 %.1f 伤害。" % [time, monster["name"], splash])
	if monster["id"] == &"spice_wizard" and time >= monster["next_swap_tick"]:
		monster["next_swap_tick"] += 10.0
		monster["target_order"].shuffle()
		log.append("[%.1fs] %s 扰乱站位，角色承伤顺序发生变化。" % [time, monster["name"]])

func _apply_regeneration(delta: float, characters: Array[Dictionary], team_effects: Dictionary) -> void:
	for actor in characters:
		if actor["alive"] and actor["heal_per_second"] > 0.0:
			actor["current_hp"] = minf(actor["max_hp"], actor["current_hp"] + actor["heal_per_second"] * delta)

func _apply_attrition(delta: float, monster: Dictionary, characters: Array[Dictionary], log: Array[String]) -> void:
	monster["current_hp"] -= ATTRITION_DPS * delta
	for actor in characters:
		if actor["alive"]:
			actor["current_hp"] -= ATTRITION_DPS * delta
			if actor["current_hp"] <= 0.0:
				_handle_actor_death(actor, log, MAX_DURATION)

func _process_character_attacks(time: float, characters: Array[Dictionary], monster: Dictionary, team_effects: Dictionary, log: Array[String]) -> void:
	for actor in characters:
		if not actor["alive"] or monster["current_hp"] <= 0.0:
			continue
		if time + 0.001 < actor["next_attack_time"]:
			continue
		var attack_data: Dictionary = _calculate_actor_attack(actor, time)
		var damage: float = float(attack_data["damage"])
		var speed_bonus_pct: float = float(attack_data["speed_bonus_pct"])
		if randf() < actor["crit_chance"]:
			damage *= actor["crit_multiplier"]
			log.append("[%.1fs] %s 暴击造成 %.1f 伤害。" % [time, actor["name"], damage])
		if monster["id"] == &"bread_knight":
			if monster["crumbs"] > 0:
				monster["crumbs"] -= 1
				log.append("[%.1fs] %s 的面包糠抵消了 %s 的攻击。" % [time, monster["name"], actor["name"]])
				damage = 0.0
			monster["current_hp"] = minf(monster["max_hp"], monster["current_hp"] + 10.0)
		monster["current_hp"] -= damage
		monster["damage_taken_window"] += damage
		if monster["wave_active_until"] > time:
			monster["wave_recorded_damage"] += damage
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
			log.append("[%.1fs] %s 触发斩杀，直接击倒 %s。" % [time, actor["name"], monster["name"]])
		else:
			log.append("[%.1fs] %s 对 %s 造成 %.1f 伤害。" % [time, actor["name"], monster["name"], damage])
		if actor["retaliate_damage"] > 0.0 and damage < 0.0:
			pass
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
		attack += actor["attack_bonus"]
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
			attack += 4.5
		if actor["board_eval"].get("flame_sausage", false):
			speed_bonus += 8.0
		if actor["board_eval"].get("honey_drink", false):
			extra_enemy_slow += 5.0
		if actor["board_eval"].get("parma_ham", false):
			pass
		if actor["board_eval"].get("monster_tartare", false):
			var lost_ratio: float = 1.0 - hp_ratio
			attack += floor(lost_ratio / 0.1) * 4.5
	attack += 0.0
	return {
		"damage": attack + bonus_damage,
		"speed_bonus_pct": speed_bonus,
		"extra_enemy_slow": extra_enemy_slow,
	}

func _process_monster_attack(time: float, monster: Dictionary, characters: Array[Dictionary], team_effects: Dictionary, log: Array[String]) -> void:
	if monster["current_hp"] <= 0.0:
		return
	if time + 0.001 < monster["next_attack_time"]:
		return
	if monster["skip_next_attack"]:
		monster["skip_next_attack"] = false
		monster["next_attack_time"] = time + _effective_interval(monster["base_interval"], -monster["attack_speed_slow"])
		log.append("[%.1fs] %s 的下一次攻击被时停琥珀茶抵消。" % [time, monster["name"]])
		return
	var target: Dictionary = _select_monster_target(characters, monster["target_order"])
	if target.is_empty():
		return
	var damage: float = float(monster["base_attack"]) * float(monster["attack_multiplier"])
	if target["first_hit_reduction"] > 0.0 and not target["first_hit_spent"]:
		damage *= (1.0 - target["first_hit_reduction"])
		target["first_hit_spent"] = true
	var source_name: String = String(monster["name"])
	_apply_damage_to_actor(target, damage, log, time, source_name)
	if target["alive"] and target["retaliate_damage"] > 0.0 and time >= target["disable_until"]:
		monster["current_hp"] -= target["retaliate_damage"]
		monster["damage_taken_window"] += target["retaliate_damage"]
		log.append("[%.1fs] %s 反伤 %.1f。" % [time, target["name"], target["retaliate_damage"]])
	if monster["id"] == &"fruit_tree_king" and target["alive"]:
		_apply_damage_to_actor(target, monster["corrosion_damage"], log, time, "腐蚀")
	monster["next_attack_time"] = time + _effective_interval(monster["base_interval"], -monster["attack_speed_slow"])

func _select_monster_target(characters: Array[Dictionary], order: Array) -> Dictionary:
	for role_id in order:
		for actor in characters:
			if actor["id"] == role_id and actor["alive"]:
				return actor
	return {}

func _apply_damage_to_actor(actor: Dictionary, amount: float, log: Array[String], time: float, source_name: String) -> void:
	if not actor["alive"]:
		return
	actor["current_hp"] -= amount
	log.append("[%.1fs] %s 对 %s 造成 %.1f 伤害。" % [time, source_name, actor["name"], amount])
	if actor["current_hp"] <= 0.0:
		if actor["revive_pct"] > 0.0 and not actor["revived"]:
			actor["revived"] = true
			actor["current_hp"] = actor["max_hp"] * actor["revive_pct"]
			log.append("[%.1fs] %s 被贤者骨灰复活，恢复 %.1f 生命。" % [time, actor["name"], actor["current_hp"]])
		else:
			_handle_actor_death(actor, log, time)

func _handle_actor_death(actor: Dictionary, log: Array[String], time: float) -> void:
	actor["alive"] = false
	actor["current_hp"] = 0.0
	log.append("[%.1fs] %s 倒下。" % [time, actor["name"]])

func _heal_actor(actor: Dictionary, amount: float, log: Array[String], time: float) -> void:
	if not actor["alive"] or amount <= 0.0:
		return
	var before: float = float(actor["current_hp"])
	actor["current_hp"] = minf(actor["max_hp"], actor["current_hp"] + amount)
	var healed: float = float(actor["current_hp"]) - before
	if healed > 0.0:
		log.append("[%.1fs] %s 回复 %.1f 生命。" % [time, actor["name"], healed])

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

func _calculate_bonus_gold(run_state: Node, characters: Array[Dictionary], duration: float) -> int:
	var battle_index: int = run_state.get_completed_battle_count()
	if battle_index < 0 or battle_index >= run_state.stage_flow_config.normal_battle_reward_gold.size():
		return 0
	var base_gold: int = run_state.stage_flow_config.normal_battle_reward_gold[battle_index]
	var hp_ratio: float = 0.0
	for actor in characters:
		hp_ratio += actor["current_hp"] / maxf(actor["max_hp"], 1.0)
	hp_ratio /= maxf(float(characters.size()), 1.0)
	var time_score: float = clampf(1.0 - duration / MAX_DURATION, 0.0, 1.0)
	return int(round(base_gold * 0.5 * ((hp_ratio + time_score) * 0.5)))

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
	report["monster_hp"] = monster["current_hp"]
	report["monster_max_hp"] = monster["max_hp"]
