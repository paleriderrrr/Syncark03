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
	_validate_monster_roster(run_state)
	_run_monster_cases(run_state)
	_finish()

func _validate_monster_roster(run_state: Node) -> void:
	var expected: Dictionary = {
		&"fruit_tree_king": {"hp": 320.0, "attack": 25.0, "interval": 3.0},
		&"cream_overlord": {"hp": 360.0, "attack": 15.0, "interval": 1.2},
		&"charging_beast": {"hp": 200.0, "attack": 40.0, "interval": 2.0},
		&"water_giant": {"hp": 300.0, "attack": 15.0, "interval": 2.0},
		&"bread_knight": {"hp": 340.0, "attack": 22.0, "interval": 2.5},
		&"spice_wizard": {"hp": 290.0, "attack": 22.0, "interval": 1.8},
		&"nc2_auto_cooker": {"hp": 1000.0, "attack": 60.0, "interval": 5.0},
	}
	for monster_variant in run_state.monster_roster.monsters:
		var definition: MonsterDefinition = monster_variant
		if not expected.has(definition.id):
			continue
		var row: Dictionary = expected[definition.id]
		_assert(float(definition.base_hp) == float(row["hp"]), "%s HP should match latest spec" % String(definition.id))
		_assert(float(definition.base_attack) == float(row["attack"]), "%s ATK should match latest spec" % String(definition.id))
		_assert(is_equal_approx(float(definition.attack_interval), float(row["interval"])), "%s interval should match latest spec" % String(definition.id))

func _run_monster_cases(run_state: Node) -> void:
	var engine: CombatEngine = CombatEngine.new()
	_test_fruit_tree_opening(run_state, engine)
	_test_cream_overlord_on_hit(engine)
	_test_charging_beast_burst(engine)
	_test_water_giant_rules(engine)
	_test_bread_knight_rules(engine)
	_test_spice_wizard_rules(engine)
	_test_boss_rules(engine)

func _test_fruit_tree_opening(run_state: Node, engine: CombatEngine) -> void:
	var monster: Dictionary = engine._build_monster(run_state.monster_lookup[&"fruit_tree_king"])
	var characters: Array[Dictionary] = [_make_actor(&"warrior"), _make_actor(&"hunter"), _make_actor(&"mage")]
	var log: Array[String] = []
	engine._apply_monster_opening_skill(monster, characters, log)
	for actor_variant in characters:
		var actor: Dictionary = actor_variant
		_assert(float(actor.get("corrosion_damage_per_second", 0.0)) == 1.0, "fruit_tree_king should apply 1 corrosion DPS at battle start")
		_assert(float(actor.get("corrosion_until", 0.0)) == 25.0, "fruit_tree_king should apply corrosion for 25 seconds")

func _test_cream_overlord_on_hit(engine: CombatEngine) -> void:
	_assert(engine.has_method("_handle_monster_hit_by_character"), "CombatEngine should expose _handle_monster_hit_by_character for monster reaction tests")
	if not engine.has_method("_handle_monster_hit_by_character"):
		return
	var monster: Dictionary = _make_monster_stub(&"cream_overlord", 360.0, 15.0, 1.2)
	var attacker: Dictionary = _make_actor(&"warrior")
	var characters: Array[Dictionary] = [attacker]
	var log: Array[String] = []
	for _i in 6:
		engine._handle_monster_hit_by_character(monster, attacker, characters, 10.0, 0.0, log)
	_assert(int(attacker.get("monster_attack_down_stacks", 0)) == 5, "cream_overlord should reduce attacker ATK up to 5 stacks")
	_assert(float(monster.get("damage_taken_window", 0.0)) >= 60.0, "cream_overlord should still record incoming damage for satisfaction healing")

func _test_charging_beast_burst(engine: CombatEngine) -> void:
	_assert(engine.has_method("_handle_monster_hit_by_character"), "CombatEngine should expose _handle_monster_hit_by_character for charging_beast burst")
	if not engine.has_method("_handle_monster_hit_by_character"):
		return
	var monster: Dictionary = _make_monster_stub(&"charging_beast", 200.0, 40.0, 2.0)
	monster["current_hp"] = 90.0
	var warrior: Dictionary = _make_actor(&"warrior")
	var hunter: Dictionary = _make_actor(&"hunter")
	var mage: Dictionary = _make_actor(&"mage")
	var characters: Array[Dictionary] = [warrior, hunter, mage]
	var log: Array[String] = []
	engine._handle_monster_hit_by_character(monster, warrior, characters, 20.0, 0.0, log)
	var damaged_count: int = 0
	for actor_variant in characters:
		var actor: Dictionary = actor_variant
		if float(actor["current_hp"]) < float(actor["max_hp"]):
			damaged_count += 1
	_assert(damaged_count == 1, "charging_beast should burst one random role for 50 damage when dropping below 50% HP")
	_assert(bool(monster.get("half_hp_burst_used", false)), "charging_beast should only trigger the half-HP burst once")

func _test_water_giant_rules(engine: CombatEngine) -> void:
	_assert(engine.has_method("_apply_monster_incoming_damage_modifiers"), "CombatEngine should expose _apply_monster_incoming_damage_modifiers for water_giant reduction")
	if engine.has_method("_apply_monster_incoming_damage_modifiers"):
		var monster: Dictionary = _make_monster_stub(&"water_giant", 300.0, 15.0, 2.0)
		monster["current_hp"] = 120.0
		var reduced: float = float(engine._apply_monster_incoming_damage_modifiers(monster, 10.0))
		_assert(is_equal_approx(reduced, 9.0), "water_giant should reduce each incoming hit by 1 below 50% HP")
	var monster_for_attack: Dictionary = _make_monster_stub(&"water_giant", 300.0, 15.0, 2.0)
	var target: Dictionary = _make_actor(&"warrior")
	target["current_hp"] = 120.0
	target["max_hp"] = 180.0
	var before_hp: float = float(target["current_hp"])
	var log: Array[String] = []
	engine._process_monster_attack(2.0, monster_for_attack, [target], {}, log)
	_assert(is_equal_approx(before_hp - float(target["current_hp"]), 18.0), "water_giant should deal +3 damage when hitting a target above 50% HP")

func _test_bread_knight_rules(engine: CombatEngine) -> void:
	var monster: Dictionary = _make_monster_stub(&"bread_knight", 340.0, 22.0, 2.5)
	monster["crumbs"] = 5
	var attacker: Dictionary = _make_actor(&"warrior")
	var log: Array[String] = []
	var consumed_damage: float = 0.0
	for _i in 5:
		consumed_damage += float(engine._apply_monster_incoming_damage_modifiers(monster, 12.0)) if engine.has_method("_apply_monster_incoming_damage_modifiers") else 12.0
	_assert(monster["crumbs"] == 0, "bread_knight should start with and consume exactly 5 crumbs")
	_assert(is_equal_approx(consumed_damage, 0.0), "bread_knight crumbs should fully negate damage while stacks remain")
	var target: Dictionary = _make_actor(&"warrior")
	engine._process_monster_attack(2.5, monster, [target], {}, log)
	_assert(int(target.get("armor_break_stacks", 0)) == 1, "bread_knight attacks should apply armor break")

func _test_spice_wizard_rules(engine: CombatEngine) -> void:
	var monster: Dictionary = _make_monster_stub(&"spice_wizard", 290.0, 22.0, 1.8)
	var warrior: Dictionary = _make_actor(&"warrior")
	var hunter: Dictionary = _make_actor(&"hunter")
	var mage: Dictionary = _make_actor(&"mage")
	var characters: Array[Dictionary] = [warrior, hunter, mage]
	var log: Array[String] = []
	engine._process_monster_timed_effects(5.0, monster, characters, log)
	var limited_count: int = 0
	for actor_variant in characters:
		var actor: Dictionary = actor_variant
		if float(actor.get("healing_reduction_until", 0.0)) > 5.0:
			limited_count += 1
			_assert(is_equal_approx(float(actor.get("healing_reduction_pct", 0.0)), 0.5), "spice_wizard should apply 50% healing reduction")
	_assert(limited_count == 1, "spice_wizard should apply healing reduction to one role every 5 seconds")
	var target: Dictionary = _make_actor(&"warrior")
	target["current_hp"] = 150.0
	target["max_hp"] = 180.0
	target["healing_reduction_until"] = 10.0
	target["healing_reduction_pct"] = 0.5
	var before_hp: float = float(target["current_hp"])
	var attack_log: Array[String] = []
	engine._process_monster_attack(1.8, monster, [target], {}, attack_log)
	_assert(is_equal_approx(before_hp - float(target["current_hp"]), 23.5), "spice_wizard should deal 1% current-HP bonus damage against healing-limited targets")

func _test_boss_rules(engine: CombatEngine) -> void:
	_assert(engine.has_method("_handle_monster_hit_by_character"), "CombatEngine should expose _handle_monster_hit_by_character for boss hit-count reactions")
	if not engine.has_method("_handle_monster_hit_by_character"):
		return
	var monster: Dictionary = _make_monster_stub(&"nc2_auto_cooker", 1000.0, 60.0, 5.0)
	monster["target_order"] = [&"warrior", &"hunter", &"mage"]
	var attacker: Dictionary = _make_actor(&"warrior")
	var characters: Array[Dictionary] = [_make_actor(&"warrior"), _make_actor(&"hunter"), _make_actor(&"mage")]
	var log: Array[String] = []
	for _i in 30:
		engine._handle_monster_hit_by_character(monster, attacker, characters, 5.0, 0.0, log)
	_assert(monster["target_order"] != [&"warrior", &"hunter", &"mage"], "boss should reshuffle target order every 30 hits received")
	var boss_target: Dictionary = _make_actor(&"warrior")
	var attack_log: Array[String] = []
	engine._process_monster_attack(5.0, monster, [boss_target], {}, attack_log)
	engine._process_monster_attack(10.0, monster, [boss_target], {}, attack_log)
	engine._process_monster_attack(15.0, monster, [boss_target], {}, attack_log)
	_assert(float(boss_target.get("disable_until", 0.0)) >= 18.0, "boss third attack should disable the target for 3 seconds")

func _make_actor(character_id: StringName) -> Dictionary:
	return {
		"id": character_id,
		"name": String(character_id),
		"max_hp": 180.0,
		"current_hp": 180.0,
		"base_hp": 180.0,
		"base_attack": 20.0,
		"attack_bonus": 0.0,
		"base_interval": 2.0,
		"attack_speed_bonus": 0.0,
		"bonus_damage": 0.0,
		"heal_per_second": 0.0,
		"execute_threshold": 0.0,
		"retaliate_damage": 0.0,
		"enemy_attack_slow": 0.0,
		"first_hit_reduction": 0.0,
		"first_hit_spent": false,
		"crit_chance": 0.0,
		"crit_multiplier": 2.0,
		"extra_meat_bonus": 0.0,
		"meat_double_below": 0.0,
		"revive_pct": 0.0,
		"revived": false,
		"disable_until": 0.0,
		"next_attack_time": 2.0,
		"temporary_speed_buffs": [],
		"team_aura_flags": {},
		"board_eval": {},
		"dynamic_execute_bonus": 0.0,
		"amber_cancel_chance": 0.0,
		"frozen_extra_slow_chance": 0.0,
		"forbidden_attack_reduction": 0.0,
		"economy_gold_bonus": 0.0,
		"adjacent_categories": {},
		"alive": true,
		"monster_attack_down_stacks": 0,
		"armor_break_stacks": 0,
		"healing_reduction_until": 0.0,
		"healing_reduction_pct": 0.0,
		"corrosion_until": 0.0,
		"corrosion_damage_per_second": 0.0,
	}

func _make_monster_stub(monster_id: StringName, hp: float, attack: float, interval: float) -> Dictionary:
	return {
		"id": monster_id,
		"name": String(monster_id),
		"category": &"",
		"max_hp": hp,
		"current_hp": hp,
		"base_attack": attack,
		"attack_multiplier": 1.0,
		"base_interval": interval,
		"attack_speed_slow": 0.0,
		"next_attack_time": interval,
		"corrosion_damage": 0.0,
		"damage_taken_window": 0.0,
		"next_satisfaction_tick": 5.0,
		"wave_active_until": -1.0,
		"wave_recorded_damage": 0.0,
		"next_wave_tick": 5.0,
		"skip_next_attack": false,
		"next_heal_lock_tick": 5.0,
		"target_order": [&"warrior", &"hunter", &"mage"],
		"crumbs": 0,
		"half_hp_burst_used": false,
		"received_hit_count": 0,
		"attack_count": 0,
	}

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("MONSTER_EFFECT_TEST_PASS")
		quit(0)
	else:
		printerr("MONSTER_EFFECT_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
