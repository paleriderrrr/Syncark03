extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = root.get_node_or_null("/root/RunState")
	_assert(run_state != null, "RunState autoload should exist")
	if run_state == null:
		_finish()
		return

	run_state.start_new_run()
	_validate_food_catalog(run_state)
	_run_food_cases(run_state)
	_run_runtime_balance_fix_cases(run_state)
	_finish()

func _validate_food_catalog(run_state: Node) -> void:
	_assert(run_state.food_catalog != null, "Food catalog should load")
	if run_state.food_catalog == null:
		return
	_assert(run_state.food_catalog.foods.size() == 54, "Food catalog should contain 54 foods")
	var seen_ids: Dictionary = {}
	for definition_variant in run_state.food_catalog.foods:
		var definition: FoodDefinition = definition_variant
		_assert(definition.id != &"", "Every food should have an id")
		_assert(not seen_ids.has(definition.id), "Food id %s should be unique" % String(definition.id))
		seen_ids[definition.id] = true
		_assert(not definition.shape_cells.is_empty(), "Food %s should define shape cells" % String(definition.id))
		_assert(definition.gold_value > 0, "Food %s should have positive gold value" % String(definition.id))
		if definition.id == &"godfather":
			_assert(definition.passive_text.contains("相邻4格") and definition.passive_text.contains("额外+1金币"), "godfather description should clearly name the orthogonal bonus-gold rule")
		if definition.id == &"bacon_strip":
			_assert(definition.passive_text.contains("放在饭盒中") and definition.passive_text.contains("1金币"), "bacon_strip description should name the bento placement gold rule")
		if definition.id == &"sausage_skewer":
			_assert(definition.passive_text.contains("相邻8格") and definition.passive_text.contains("[主食]"), "sausage_skewer description should stay localized and name the 8-neighbor staple rule")

func _run_food_cases(run_state: Node) -> void:
	for food_variant in run_state.food_catalog.foods:
		var definition: FoodDefinition = food_variant
		_run_food_case(run_state, definition.id)

func _run_food_case(run_state: Node, food_id: StringName) -> void:
	match food_id:
		&"red_berry":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			var actor: Dictionary = _preview_actor(run_state)
			_assert(_hp_bonus(actor) == 8.0, "red_berry should grant +8 HP")
		&"lettuce_leaf":
			_reset_board(run_state, [
				{"id": &"red_berry", "anchor": Vector2i(0, 0)},
				{"id": food_id, "anchor": Vector2i(0, 1)},
			])
			_assert(_hp_bonus(_preview_actor(run_state)) == 24.0, "lettuce_leaf should add +8 HP to food placed above it")
		&"lemon":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"bacon_strip", "anchor": Vector2i(1, 0)},
			])
			_assert(_attack_bonus(_preview_actor(run_state)) == 3.0, "lemon should gain +1.5 ATK when adjacent to meat or staple food")
		&"broccoli":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 3)))
			_assert(_hp_bonus(_preview_actor(run_state)) == 32.0, "broccoli should count only orthogonally adjacent empty cells for its HP bonus")
		&"prickly_pear":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(3, 0)},
				{"id": &"lemon", "anchor": Vector2i(4, 0)},
			])
			var pear_actor: Dictionary = _preview_actor(run_state)
			_reset_board(run_state, [
				{"id": &"red_berry", "anchor": Vector2i(0, 0)},
				{"id": &"lemon", "anchor": Vector2i(1, 0)},
				{"id": &"lettuce_leaf", "anchor": Vector2i(2, 0)},
			])
			var baseline_actor: Dictionary = _preview_actor(run_state)
			_assert(float(pear_actor["retaliate_damage"]) > float(baseline_actor["retaliate_damage"]), "prickly_pear should increase fruit retaliation damage")
			_assert(is_equal_approx(float(pear_actor["retaliate_damage"]), 4.375), "prickly_pear should multiply the active fruit bond retaliation by 25%")
		&"rock_melon":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(float(_preview_actor(run_state)["first_hit_reduction"]) == 0.5, "rock_melon should grant 50% first-hit reduction")
		&"rosemary_tomato":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(3, 0)},
				{"id": &"lemon", "anchor": Vector2i(4, 0)},
				{"id": &"sesame", "anchor": Vector2i(2, 0)},
			])
			var rosemary_actor: Dictionary = _preview_actor(run_state)
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(3, 0)},
				{"id": &"lemon", "anchor": Vector2i(4, 0)},
			])
			var rosemary_base: Dictionary = _preview_actor(run_state)
			_assert(float(rosemary_actor["retaliate_damage"]) > float(rosemary_base["retaliate_damage"]), "rosemary_tomato should add extra retaliation when adjacent to spice")
		&"demon_durian":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(4, 0)},
				{"id": &"lemon", "anchor": Vector2i(5, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(8, 4)))
			_assert(float(_preview_actor(run_state)["retaliate_damage"]) >= 2.0, "demon_durian should double fruit retaliation output")
			_assert(is_equal_approx(float(_preview_actor(run_state)["retaliate_damage"]), 12.0), "demon_durian should double the active fruit bond retaliation after the bond value is calculated")
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(1, 0)},
				{"id": &"lemon", "anchor": Vector2i(2, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			var durian_summary: Dictionary = run_state.get_synergy_summary(&"warrior")
			var fruit_entry: Dictionary = _find_synergy_entry(durian_summary, &"fruit")
			_assert(int(fruit_entry.get("count", 0)) == 1 and not bool(fruit_entry.get("active", false)), "synergy summary should ignore foods disabled by demon_durian")
		&"tree_fruit":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)))
			var tree_actor: Dictionary = _preview_actor(run_state)
			_assert(bool(tree_actor["team_aura_flags"].get("tree_heal_every", false)), "tree_fruit should enable periodic team healing")
			_assert(run_state.get_food_categories(run_state.get_food_definition(food_id)).has(&"dessert"), "tree_fruit should count as dessert")
		&"gummy_block":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			_assert(float(_preview_actor(run_state)["heal_per_second"]) == 1.0, "gummy_block should grant +1 HPS")
		&"pudding_cup":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("pudding", false)), "pudding_cup should mark its opening heal effect")
		&"jam_cookie":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(1, 0)},
			])
			_assert(_hp_bonus(_preview_actor(run_state)) == 16.0, "jam_cookie should gain +8 HP when adjacent to fruit")
		&"sugar_donut":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(1, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			var donut_actor: Dictionary = _preview_actor(run_state)
			_assert(float(donut_actor["team_aura_flags"].get("dessert_pulse_amount", 0.0)) >= 2.0, "sugar_donut should boost dessert pulse when its center is filled")
		&"cherry_mousse":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"iced_black_tea", "anchor": Vector2i(1, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(float(_preview_actor(run_state)["attack_speed_bonus"]) == 20.0, "cherry_mousse should gain +10% speed when adjacent to drink")
		&"caramel_mille":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("caramel_mille", false)), "caramel_mille should register its 20s attack-speed trigger")
		&"puff_tower":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(3, 0)},
				{"id": &"bacon_strip", "anchor": Vector2i(4, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(6, 5)))
			_assert(float(_preview_actor(run_state)["attack_speed_bonus"]) >= 20.0, "puff_tower should gain +20% speed with at least 3 categories present")
		&"ice_cream_sundae":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 6)))
			var sundae_actor: Dictionary = _preview_actor(run_state)
			_assert(bool(sundae_actor["team_aura_flags"].get("dessert_multiplier_after_20", false)), "ice_cream_sundae should register dessert scaling after 20s")
			_assert(run_state.get_food_categories(run_state.get_food_definition(food_id)).has(&"drink"), "ice_cream_sundae should count as drink")
		&"fairy_candy_castle":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("fairy_speed_on_heal", false)), "fairy_candy_castle should add speed on heal")
		&"bacon_strip":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			var bacon_actor: Dictionary = _preview_actor(run_state)
			_assert(_attack_bonus(bacon_actor) == 1.5, "bacon_strip should grant +1.5 ATK")
			_assert(float(bacon_actor["economy_gold_bonus"]) == 1.0, "bacon_strip should grant +1 battle bonus gold while placed in a bento")
		&"chicken_steak":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _full_grid_cells(), 0.4)
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("chicken_steak", false)), "chicken_steak should mark its low-HP attack trigger")
			var chicken_actor: Dictionary = _preview_actor(run_state)
			var chicken_attack: Dictionary = CombatEngine.new()._calculate_actor_attack(chicken_actor, 0.0)
			_assert(is_equal_approx(float(chicken_attack.get("damage", 0.0)), float(chicken_actor.get("base_attack", 0.0)) + 3.0), "chicken_steak should add +3 ATK below half HP")
		&"sausage_skewer":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"mashed_potato", "anchor": Vector2i(1, 1)},
				{"id": &"ramen", "anchor": Vector2i(1, 3)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 5)))
			var sausage_summary: Dictionary = run_state.get_synergy_summary(&"warrior")
			var meat_entry: Dictionary = _find_synergy_entry(sausage_summary, &"meat")
			_assert(int(meat_entry.get("count", 0)) == 3 and bool(meat_entry.get("active", false)), "sausage_skewer should add visible meat bond layers for adjacent staples")
		&"lamb_rib":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 3)))
			_assert(float(_preview_actor(run_state)["extra_meat_bonus"]) == 0.0, "lamb_rib should not add extra meat scaling before the meat bond is active")
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"bacon_strip", "anchor": Vector2i(3, 0)},
				{"id": &"chicken_steak", "anchor": Vector2i(4, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(6, 4)))
			_assert(float(_preview_actor(run_state)["extra_meat_bonus"]) > 0.0, "lamb_rib should add extra meat scaling once the meat bond is active")
		&"tomahawk_steak":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"sesame", "anchor": Vector2i(3, 2)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			_assert(float(_preview_actor(run_state)["crit_chance"]) == 0.25, "tomahawk_steak should gain 25% crit chance from diagonal 8-neighbor spice")
		&"flame_sausage":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _full_grid_cells(), 1.0)
			var flame_actor: Dictionary = _preview_actor(run_state)
			var flame_engine: CombatEngine = CombatEngine.new()
			var healthy_monster := {"current_hp": 100.0, "max_hp": 100.0}
			var low_monster := {"current_hp": 49.0, "max_hp": 100.0}
			_assert(is_equal_approx(float(flame_engine._calculate_actor_attack(flame_actor, 0.0, healthy_monster)["speed_bonus_pct"]), 0.0), "flame_sausage should not grant speed while the monster is above half HP")
			_assert(is_equal_approx(float(flame_engine._calculate_actor_attack(flame_actor, 0.0, low_monster)["speed_bonus_pct"]), 8.0), "flame_sausage should grant speed below half monster HP")
		&"parma_ham":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"bacon_strip", "anchor": Vector2i(3, 0)},
				{"id": &"chicken_steak", "anchor": Vector2i(4, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(6, 4)))
			_assert(_hp_bonus(_preview_actor(run_state)) >= 24.0, "parma_ham should grant its +24 HP bonus when at least 3 meat foods are present")
		&"dragon_tail":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)), 0.35)
			var dragon_tail_actor: Dictionary = _preview_actor(run_state)
			_assert(float(dragon_tail_actor["meat_double_below"]) == 0.4, "dragon_tail should double meat scaling below 40% HP")
			_assert(run_state.get_food_categories(run_state.get_food_definition(food_id)).has(&"staple"), "dragon_tail should count as staple")
		&"monster_tartare":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			var tartare_report: Dictionary = _simulate(run_state, &"charging_beast")
			var tartare_actor: Dictionary = _find_report_actor(tartare_report, &"warrior")
			_assert(float(tartare_actor.get("current_hp", 0.0)) < float(tartare_actor.get("max_hp", 0.0)), "monster_tartare should self-damage on battle start")
		&"iced_black_tea":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			_assert(float(_preview_actor(run_state)["attack_speed_bonus"]) == 10.0, "iced_black_tea should grant +10% speed")
		&"soda":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 4)))
			_assert(float(_preview_actor(run_state)["enemy_attack_slow"]) == 25.0, "soda should apply 25% enemy slow at battle start")
		&"matcha":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"gummy_block", "anchor": Vector2i(2, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 3)))
			_assert(float(_preview_actor(run_state)["attack_speed_bonus"]) == 20.0, "matcha should gain +10% speed when adjacent to dessert")
		&"honey_drink":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 3)))
			var honey_actor: Dictionary = _preview_actor(run_state)
			var honey_engine: CombatEngine = CombatEngine.new()
			_assert(is_equal_approx(float(honey_engine._calculate_actor_attack(honey_actor, 0.0, {"current_hp": 100.0, "max_hp": 100.0})["extra_enemy_slow"]), 0.0), "honey_drink should not slow unless the drink bond is active")
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"iced_black_tea", "anchor": Vector2i(2, 0)},
				{"id": &"matcha", "anchor": Vector2i(2, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			honey_actor = _preview_actor(run_state)
			_assert(is_equal_approx(float(honey_engine._calculate_actor_attack(honey_actor, 0.0, {"current_hp": 100.0, "max_hp": 100.0})["extra_enemy_slow"]), 0.0), "honey_drink should not slow on the hero attack")
			var honey_characters: Array[Dictionary] = honey_engine._build_characters(run_state)
			var honey_effects: Dictionary = honey_engine._build_team_effects(honey_characters)
			var honey_monster: Dictionary = honey_engine._build_monster(run_state.get_monster_definition(&"water_giant"))
			honey_monster["next_attack_time"] = 0.0
			var honey_log: Array[String] = []
			honey_engine._process_monster_attack(0.0, honey_monster, honey_characters, honey_effects, honey_log)
			_assert(is_equal_approx(float(honey_monster.get("attack_speed_slow", 0.0)), 5.0), "honey_drink should slow after the enemy attacks while the drink bond is active")
		&"godfather":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)))
			_assert(float(_preview_actor(run_state)["economy_gold_bonus"]) > 0.0, "godfather should expose its adjacent-empty gold bonus")
		&"frozen_mint":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"mashed_potato", "anchor": Vector2i(1, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(float(_preview_actor(run_state)["frozen_extra_slow_chance"]) == 0.2, "frozen_mint should gain 20% extra slow chance when adjacent to staple")
		&"power_coffee":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 3)))
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("power_coffee", false)), "power_coffee should register its 15s team speed trigger")
		&"amber_tea":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"iced_black_tea", "anchor": Vector2i(3, 0)},
				{"id": &"matcha", "anchor": Vector2i(3, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(6, 3)))
			_assert(float(_preview_actor(run_state)["amber_cancel_chance"]) == 0.1, "amber_tea should gain 5% cancel chance per adjacent drink")
			var amber_actor: Dictionary = _preview_actor(run_state)
			amber_actor["amber_cancel_chance"] = 1.0
			amber_actor["next_attack_time"] = 0.0
			var bread_monster := {
				"id": &"bread_knight",
				"name": "bread_knight",
				"alive": true,
				"current_hp": 100.0,
				"max_hp": 100.0,
				"crumbs": 1,
			}
			CombatEngine.new()._process_character_attacks(0.0, [amber_actor], bread_monster, {}, [])
			_assert(not bool(bread_monster.get("skip_next_attack", false)), "amber_tea should not cancel attacks when damage is fully negated")
		&"cellar_vintage":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 0), "reroll_bonus_count": 3}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			var cellar_actor: Dictionary = _preview_actor(run_state)
			_assert(float(cellar_actor["attack_speed_bonus"]) == 70.0, "cellar_vintage should gain +10% speed per reroll on top of its base speed")
			_assert(float(cellar_actor["enemy_attack_slow"]) == 15.0, "cellar_vintage should add 5% enemy slow per reroll")
		&"mashed_potato":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			var potato_actor: Dictionary = _preview_actor(run_state)
			_assert(_hp_bonus(potato_actor) == 8.0 and _attack_bonus(potato_actor) == 1.5, "mashed_potato should grant +8 HP and +1.5 ATK")
		&"ramen":
			_assert(run_state.get_food_categories(run_state.get_food_definition(food_id)).has(&"drink"), "ramen should count as drink")
		&"corn_cake":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(1, 1)},
				{"id": &"red_berry", "anchor": Vector2i(0, 1)},
				{"id": &"bacon_strip", "anchor": Vector2i(2, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			_assert(_attack_bonus(_preview_actor(run_state)) == 4.5, "corn_cake should gain +3 ATK when adjacent to fruit and meat")
		&"baguette":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 5)))
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("baguette", false)), "baguette should register its stacking staple trigger")
			var baguette_actor: Dictionary = _preview_actor(run_state)
			baguette_actor["disable_until"] = 5.0
			baguette_actor["next_attack_time"] = 0.0
			var baguette_monster := {"id": &"cream_overlord", "name": "monster", "alive": true, "current_hp": 100.0, "max_hp": 100.0}
			CombatEngine.new()._process_character_attacks(0.0, [baguette_actor], baguette_monster, {}, [])
			_assert(float(baguette_actor["dynamic_execute_bonus"]) == 0.0, "baguette should not stack while bento effects are disabled")
		&"sandwich":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(1, 1)},
				{"id": &"red_berry", "anchor": Vector2i(0, 1)},
				{"id": &"bacon_strip", "anchor": Vector2i(3, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			_assert(_hp_bonus(_preview_actor(run_state)) == 40.0, "sandwich should gain +8 HP per adjacent category")
		&"seafood_rice":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"iced_black_tea", "anchor": Vector2i(1, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(float(_preview_actor(run_state)["attack_speed_bonus"]) == 14.0, "seafood_rice should gain +4% speed when adjacent to drink")
		&"travel_bento":
			run_state.start_new_run()
			run_state.current_gold -= 6
			var travel_instance: Dictionary = run_state.generate_item_instance(food_id)
			run_state.shared_inventory.append(travel_instance)
			run_state._apply_food_purchase_side_effects(travel_instance)
			_assert(run_state.free_food_purchase_count == 1, "travel_bento should grant one free food purchase")
			run_state.current_market_offers.clear()
			run_state.current_market_offers.append({
				"offer_id": &"travel_bento_offer",
				"slot_index": 0,
				"kind": &"food",
				"definition_id": &"travel_bento",
				"quantity": 1,
				"rarity": &"rare",
				"discount": 1.0,
				"price": 1,
			})
			run_state.current_gold = 30
			run_state.current_reroll_count = 2
			var purchased_bento: Array[Dictionary] = run_state.purchase_market_offer_package(&"travel_bento_offer")
			_assert(not purchased_bento.is_empty(), "travel_bento should be purchasable through the market package path")
			_assert(run_state.current_market_offers.size() == run_state.market_config.slot_count, "travel_bento purchase should leave a full refreshed market")
			_assert(run_state.current_reroll_count == 2, "travel_bento free refresh should not reset the paid reroll count")
			run_state.current_market_offers.clear()
			run_state.current_market_offers.append({
				"offer_id": &"travel_bento_bundle_offer",
				"slot_index": 0,
				"kind": &"food",
				"definition_id": &"travel_bento",
				"quantity": 3,
				"rarity": &"rare",
				"discount": 1.0,
				"price": 1,
			})
			run_state.free_food_purchase_count = 0
			run_state.current_gold = 30
			var purchased_bento_bundle: Array[Dictionary] = run_state.purchase_market_offer_package(&"travel_bento_bundle_offer")
			_assert(purchased_bento_bundle.size() == 3, "travel_bento bundled purchases should still grant all package copies")
			_assert(run_state.free_food_purchase_count == 1, "travel_bento package side effects should trigger once per purchased package")
		&"mixed_feast":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(4, 0)},
				{"id": &"lemon", "anchor": Vector2i(5, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(7, 4)))
			_assert(_attack_bonus(_preview_actor(run_state)) >= 3.0, "mixed_feast should gain stats for each active bond")
		&"dragon_stove":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(4, 0)},
				{"id": &"bacon_strip", "anchor": Vector2i(5, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(7, 4)))
			var stove_actor: Dictionary = _preview_actor(run_state)
			_assert(_hp_bonus(stove_actor) >= 12.0 and _attack_bonus(stove_actor) >= 2.25, "dragon_stove should scale with unique categories present")
			var stove_hunter: Dictionary = CombatEngine.preview_character_actor(run_state, &"hunter")
			_assert(_hp_bonus(stove_hunter) >= 12.0 and _attack_bonus(stove_hunter) >= 2.25, "dragon_stove should grant its category stats to the whole team")
		&"sesame":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			_assert(float(_preview_actor(run_state)["bonus_damage"]) == 1.5, "sesame should grant +1.5 bonus damage")
		&"salt_pack":
			_reset_board(run_state, [
				{"id": &"mashed_potato", "anchor": Vector2i(0, 0)},
				{"id": food_id, "anchor": Vector2i(0, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 4)))
			_assert(float(_preview_actor(run_state)["bonus_damage"]) == 3.0, "salt_pack should gain +3 bonus damage when under staple or meat")
		&"wasabi":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}])
			_assert(float(_preview_actor(run_state)["bonus_damage"]) == 3.0, "wasabi should add three extra damage")
		&"soy_sauce":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(int(_preview_actor(run_state).get("extra_damage_hits", 0)) > 0, "soy_sauce should gain separate extra damage hits from adjacent empty cells")
			var soy_engine: CombatEngine = CombatEngine.new()
			var soy_characters: Array[Dictionary] = soy_engine._build_characters(run_state)
			var soy_monster: Dictionary = soy_engine._build_monster(run_state.get_monster_definition(&"nc2_auto_cooker"))
			soy_characters[0]["next_attack_time"] = 0.0
			soy_engine._process_character_attacks(0.0, soy_characters, soy_monster, {}, [])
			_assert(int(soy_monster.get("received_hit_count", 0)) > 1, "soy_sauce extra damage should count as separate attack hits")
		&"cilantro":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 3)))
			_assert(float(_preview_actor(run_state)["bonus_damage"]) == 18.0, "cilantro should start at +9 bonus damage when not adjacent to food")
		&"pepper_bundle":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"red_berry", "anchor": Vector2i(1, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 5)))
			_assert(float(_preview_actor(run_state)["bonus_damage"]) == 2.5, "pepper_bundle should gain +1.5 bonus damage when adjacent to fruit")
		&"curry_can":
			run_state.start_new_run()
			run_state.current_gold -= 6
			var gold_before: int = run_state.current_gold
			var curry_instance: Dictionary = run_state.generate_item_instance(food_id)
			run_state.shared_inventory.append(curry_instance)
			run_state._apply_food_purchase_side_effects(curry_instance)
			_assert(run_state.current_gold == gold_before + 3, "curry_can should refund 3 gold on purchase")
			_assert(run_state.spice_purchase_refund == 1, "curry_can should increase spice purchase refund counter")
		&"sage_ashes":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 3)))
			_assert(float(_preview_actor(run_state)["revive_pct"]) == 0.3, "sage_ashes should grant 30% revive")
			var sage_engine: CombatEngine = CombatEngine.new()
			var sage_actor: Dictionary = _preview_actor(run_state)
			sage_actor["disable_until"] = 5.0
			sage_actor["current_hp"] = 1.0
			var sage_log: Array[String] = []
			sage_engine._apply_damage_to_actor(sage_actor, 99.0, sage_log, 0.0, "test")
			_assert(not bool(sage_actor.get("alive", true)) and is_equal_approx(float(sage_actor.get("current_hp", 0.0)), 0.0), "sage_ashes should not revive while bento effects are disabled")
		&"forbidden_herb":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			_assert(float(_preview_actor(run_state)["forbidden_attack_reduction"]) == 0.05, "forbidden_herb should reduce enemy attack by 5% on hit")
		_:
			_assert(false, "Missing food automation case for %s" % String(food_id))

func _run_runtime_balance_fix_cases(run_state: Node) -> void:
	var engine: CombatEngine = CombatEngine.new()
	var log: Array[String] = []

	_reset_board(run_state, [])
	var no_carousel_characters: Array[Dictionary] = engine._build_characters(run_state)
	var no_carousel_effects: Dictionary = engine._build_team_effects(no_carousel_characters)
	engine._process_timed_team_effects(20.0, no_carousel_characters, no_carousel_effects, {"alive": true}, log)
	_assert(float(no_carousel_characters[0]["attack_speed_bonus"]) == 0.0, "caramel_mille timing should not trigger without the food present")

	_reset_board(run_state, [{"id": &"caramel_mille", "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
	var caramel_characters: Array[Dictionary] = engine._build_characters(run_state)
	var caramel_effects: Dictionary = engine._build_team_effects(caramel_characters)
	engine._process_timed_team_effects(20.0, caramel_characters, caramel_effects, {"alive": true}, log)
	_assert(float(caramel_characters[0]["attack_speed_bonus"]) >= 60.0, "caramel_mille timing should grant its team speed bonus only when present")

	_reset_board(run_state, [])
	var no_coffee_characters: Array[Dictionary] = engine._build_characters(run_state)
	var no_coffee_effects: Dictionary = engine._build_team_effects(no_coffee_characters)
	engine._process_timed_team_effects(15.0, no_coffee_characters, no_coffee_effects, {"alive": true}, log)
	_assert(float(no_coffee_characters[0]["attack_speed_bonus"]) == 0.0, "power_coffee timing should not trigger without the food present")

	_reset_board(run_state, [{"id": &"power_coffee", "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 3)))
	var coffee_characters: Array[Dictionary] = engine._build_characters(run_state)
	var coffee_effects: Dictionary = engine._build_team_effects(coffee_characters)
	engine._process_timed_team_effects(15.0, coffee_characters, coffee_effects, {"alive": true}, log)
	_assert(float(coffee_characters[0]["attack_speed_bonus"]) >= 5.0, "power_coffee timing should grant its team speed bonus only when present")

	_reset_board(run_state, [{"id": &"pudding_cup", "anchor": Vector2i(0, 0)}])
	var pudding_characters: Array[Dictionary] = engine._build_characters(run_state)
	pudding_characters[0]["current_hp"] = maxf(1.0, float(pudding_characters[0]["current_hp"]) - 20.0)
	var pudding_hp_before: float = float(pudding_characters[0]["current_hp"])
	engine._process_character_status_effects(2.0, pudding_characters, log)
	_assert(is_equal_approx(float(pudding_characters[0]["current_hp"]) - pudding_hp_before, 5.0), "pudding_cup should heal its holder by 5 HP on its first timed trigger")

	_reset_board(run_state, [
		{"id": &"fairy_candy_castle", "anchor": Vector2i(0, 0)},
		{"id": &"gummy_block", "anchor": Vector2i(4, 0)},
	], _cells_in_rect(Vector2i(0, 0), Vector2i(6, 4)))
	var fairy_characters: Array[Dictionary] = engine._build_characters(run_state)
	var fairy_effects: Dictionary = engine._build_team_effects(fairy_characters)
	fairy_characters[0]["current_hp"] = maxf(1.0, float(fairy_characters[0]["current_hp"]) - 10.0)
	engine._apply_regeneration(1.0, 1.0, fairy_characters, fairy_effects, log)
	_assert(not fairy_characters[0]["temporary_speed_buffs"].is_empty(), "fairy_candy_castle should grant speed when any healing effect restores HP")

	_reset_board(run_state, [{"id": &"soda", "anchor": Vector2i(0, 0)}])
	var soda_characters: Array[Dictionary] = engine._build_characters(run_state)
	var soda_effects: Dictionary = engine._build_team_effects(soda_characters)
	_assert(is_equal_approx(float(soda_effects.get("opening_enemy_attack_slow", 0.0)), 25.0), "soda opening slow should be promoted to a team combat effect")
	var soda_monster: Dictionary = engine._build_monster(run_state.get_current_monster_definition())
	engine._apply_team_enemy_slow_to_monster(soda_monster, soda_effects)
	_assert(is_equal_approx(float(soda_monster["attack_speed_slow"]), 25.0), "soda opening slow should apply to the runtime monster state")
	_assert(is_equal_approx(float(soda_monster["next_attack_time"]), engine._effective_interval(float(soda_monster["base_interval"]), -25.0)), "soda opening slow should delay the monster's first attack")
	engine._expire_monster_opening_slow(10.0, soda_monster)
	_assert(is_equal_approx(float(soda_monster["attack_speed_slow"]), 0.0), "soda opening slow should expire after 10 seconds")
	soda_characters[0]["disable_until"] = 3.0
	var disabled_soda_effects: Dictionary = engine._build_team_effects(soda_characters)
	_assert(is_equal_approx(float(disabled_soda_effects.get("opening_enemy_attack_slow", 0.0)), 0.0), "disabled bento effects should not contribute opening team slows")

	_reset_board(run_state, [{"id": &"monster_tartare", "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
	var disabled_tartare_characters: Array[Dictionary] = engine._build_characters(run_state)
	disabled_tartare_characters[0]["disable_until"] = 3.0
	var tartare_hp_before: float = float(disabled_tartare_characters[0].get("current_hp", 0.0))
	engine._apply_character_opening_effects(disabled_tartare_characters, {}, log)
	_assert(is_equal_approx(float(disabled_tartare_characters[0].get("current_hp", 0.0)), tartare_hp_before), "monster_tartare opening self-damage should not trigger while bento effects are disabled")

	_reset_board(run_state, [{"id": &"cellar_vintage", "anchor": Vector2i(1, 1), "reroll_bonus_count": 3}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)))
	var cellar_runtime_characters: Array[Dictionary] = engine._build_characters(run_state)
	var cellar_runtime_effects: Dictionary = engine._build_team_effects(cellar_runtime_characters)
	var cellar_monster: Dictionary = engine._build_monster(run_state.get_current_monster_definition())
	engine._apply_team_enemy_slow_to_monster(cellar_monster, cellar_runtime_effects)
	_assert(is_equal_approx(float(cellar_monster["attack_speed_slow"]), 15.0), "cellar_vintage reroll slow should apply to the runtime monster state")
	engine._expire_monster_opening_slow(10.0, cellar_monster)
	_assert(is_equal_approx(float(cellar_monster["attack_speed_slow"]), 15.0), "cellar_vintage reroll slow should persist after opening slows expire")

	_reset_board(run_state, [])
	var baseline_characters: Array[Dictionary] = engine._build_characters(run_state)
	var baseline_bonus_gold: int = engine._calculate_bonus_gold(run_state, baseline_characters, 0.0)
	_reset_board(run_state, [{"id": &"godfather", "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)))
	var godfather_characters: Array[Dictionary] = engine._build_characters(run_state)
	var godfather_bonus_gold: int = engine._calculate_bonus_gold(run_state, godfather_characters, 0.0)
	_assert(godfather_bonus_gold > baseline_bonus_gold, "godfather should convert its economy bonus into battle bonus gold")

	_reset_board(run_state, [
		{"id": &"lemon", "anchor": Vector2i(1, 1)},
		{"id": &"bacon_strip", "anchor": Vector2i(2, 1)},
	], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
	var highlight_report: Dictionary = CombatEngine.preview_adjacency_synergy(run_state, &"warrior", &"test_lemon_1_1")
	_assert(highlight_report.get("selected_cells", []).has(Vector2i(1, 1)), "Adjacency highlight should include the selected food cells")
	_assert(highlight_report.get("checked_cells", []).has(Vector2i(2, 1)), "Adjacency highlight should check the same orthogonal cells used by gameplay")
	_assert(highlight_report.get("partner_cells", []).has(Vector2i(2, 1)), "Adjacency highlight should mark real adjacent synergy partners")
	_assert(bool(highlight_report.get("adjacent_categories", {}).get(&"meat", false)), "Adjacency highlight categories should match gameplay adjacency categories")
	var preview_cells: Array[Vector2i] = [Vector2i(1, 2)]
	var preview_highlight: Dictionary = CombatEngine.preview_adjacency_synergy_for_cells(run_state, &"warrior", preview_cells, &"")
	_assert(preview_highlight.get("checked_cells", []).has(Vector2i(2, 2)), "Adjacency preview should visualize orthogonal checks for unplaced foods")
	_assert(not preview_highlight.get("checked_cells", []).has(Vector2i(2, 3)), "Adjacency preview should not include diagonal checks for unplaced foods")

func _reset_board(run_state: Node, food_specs: Array, active_cells: Array[Vector2i] = [], hp_ratio: float = 1.0) -> void:
	run_state.select_character(&"warrior")
	var state: Dictionary = run_state.get_character_state(&"warrior")
	state["placed_foods"] = []
	state["placed_expansions"] = []
	state["pending_expansions"] = []
	state["hp_ratio"] = hp_ratio
	state["active_cells"] = active_cells if not active_cells.is_empty() else _full_grid_cells()
	for spec_variant in food_specs:
		var spec: Dictionary = spec_variant
		var definition: FoodDefinition = run_state.get_food_definition(spec["id"])
		var rotation: int = int(spec.get("rotation", 0))
		var cells: Array[Vector2i] = ShapeUtils.translate_cells(ShapeUtils.rotate_cells(definition.shape_cells, rotation), spec["anchor"])
		state["placed_foods"].append({
			"instance_id": StringName("test_%s_%d_%d" % [String(spec["id"]), spec["anchor"].x, spec["anchor"].y]),
			"definition_id": spec["id"],
			"rotation": rotation,
			"anchor": spec["anchor"],
			"cells": cells,
			"reroll_bonus_count": int(spec.get("reroll_bonus_count", 0)),
		})
	for character_id in run_state.character_states.keys():
		if character_id == &"warrior":
			continue
		var other_state: Dictionary = run_state.get_character_state(character_id)
		other_state["placed_foods"] = []
		other_state["placed_expansions"] = []
		other_state["pending_expansions"] = []
		other_state["active_cells"] = _full_grid_cells()
		other_state["hp_ratio"] = 1.0

func _preview_actor(run_state: Node) -> Dictionary:
	return CombatEngine.preview_character_actor(run_state, &"warrior")

func _simulate(run_state: Node, monster_id: StringName) -> Dictionary:
	run_state.current_route_index = 1
	run_state.set("normal_monster_order", [monster_id])
	return CombatEngine.simulate(run_state)

func _find_report_actor(report: Dictionary, character_id: StringName) -> Dictionary:
	for actor_variant in report.get("characters", []):
		var actor: Dictionary = actor_variant
		if actor.get("id", &"") == character_id:
			return actor
	return {}

func _find_synergy_entry(summary: Dictionary, category_id: StringName) -> Dictionary:
	for entry_variant in summary.get("entries", []):
		var entry: Dictionary = entry_variant
		if entry.get("category_id", &"") == category_id:
			return entry
	return {}

func _hp_bonus(actor: Dictionary) -> float:
	return float(actor.get("max_hp", 0.0)) - float(actor.get("base_hp", 0.0))

func _attack_bonus(actor: Dictionary) -> float:
	return float(actor.get("attack_bonus", 0.0))

func _full_grid_cells() -> Array[Vector2i]:
	return _cells_in_rect(Vector2i(0, 0), Vector2i(8, 6))

func _cells_in_rect(anchor: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			result.append(Vector2i(anchor.x + x, anchor.y + y))
	return result

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_EFFECT_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_EFFECT_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
