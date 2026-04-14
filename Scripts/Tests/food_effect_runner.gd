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
			_assert(_hp_bonus(_preview_actor(run_state)) > 20.0, "broccoli should gain extra HP from adjacent empty cells")
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
			_assert(_attack_bonus(_preview_actor(run_state)) == 1.5, "bacon_strip should grant +1.5 ATK")
		&"chicken_steak":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _full_grid_cells(), 0.4)
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("chicken_steak", false)), "chicken_steak should mark its low-HP attack trigger")
		&"sausage_skewer":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"mashed_potato", "anchor": Vector2i(1, 1)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(4, 4)))
			_assert(float(_preview_actor(run_state)["extra_meat_bonus"]) >= 1.0, "sausage_skewer should add meat bond value when adjacent to staple")
		&"lamb_rib":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _cells_in_rect(Vector2i(0, 0), Vector2i(3, 3)))
			_assert(float(_preview_actor(run_state)["extra_meat_bonus"]) == 0.5, "lamb_rib should add extra meat scaling")
		&"tomahawk_steak":
			_reset_board(run_state, [
				{"id": food_id, "anchor": Vector2i(0, 0)},
				{"id": &"sesame", "anchor": Vector2i(3, 0)},
			], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 4)))
			_assert(float(_preview_actor(run_state)["crit_chance"]) == 0.25, "tomahawk_steak should gain 25% crit chance when adjacent to spice")
		&"flame_sausage":
			_reset_board(run_state, [{"id": food_id, "anchor": Vector2i(0, 0)}], _full_grid_cells(), 1.0)
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("flame_sausage", false)), "flame_sausage should register its enemy-low-HP speed trigger")
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
			_assert(bool(_preview_actor(run_state)["team_aura_flags"].get("honey_drink", false)), "honey_drink should register its on-hit slow trigger")
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
			_assert(_hp_bonus(stove_actor) >= 20.0 and _attack_bonus(stove_actor) >= 3.75, "dragon_stove should scale with unique categories present")
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
			_assert(float(_preview_actor(run_state)["bonus_damage"]) > 1.0, "soy_sauce should gain bonus damage from adjacent empty cells")
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
	_assert(float(pudding_characters[0]["current_hp"]) > pudding_hp_before, "pudding_cup should heal its holder on its first timed trigger")

	_reset_board(run_state, [])
	var baseline_characters: Array[Dictionary] = engine._build_characters(run_state)
	var baseline_bonus_gold: int = engine._calculate_bonus_gold(run_state, baseline_characters, 0.0)
	_reset_board(run_state, [{"id": &"godfather", "anchor": Vector2i(1, 1)}], _cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)))
	var godfather_characters: Array[Dictionary] = engine._build_characters(run_state)
	var godfather_bonus_gold: int = engine._calculate_bonus_gold(run_state, godfather_characters, 0.0)
	_assert(godfather_bonus_gold > baseline_bonus_gold, "godfather should convert its economy bonus into battle bonus gold")

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
