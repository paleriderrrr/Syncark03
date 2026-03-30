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
	_validate_category_locked_candidates(run_state)
	_validate_granted_items_match_monster_category(run_state)
	_finish()

func _validate_category_locked_candidates(run_state: Node) -> void:
	for monster_variant in run_state.monster_roster.monsters:
		var monster: MonsterDefinition = monster_variant
		if monster.category == &"boss":
			continue
		var candidates: Array = run_state.get_battle_drop_candidates(monster)
		_assert(not candidates.is_empty(), "%s should have battle drop candidates" % monster.display_name)
		for definition_variant in candidates:
			var definition: FoodDefinition = definition_variant
			_assert(
				definition.category == monster.category,
				"%s should only expose %s drops, but included %s (%s)" % [
					monster.display_name,
					String(monster.category),
					definition.display_name,
					String(definition.category),
				]
			)

func _validate_granted_items_match_monster_category(run_state: Node) -> void:
	for monster_variant in run_state.monster_roster.monsters:
		var monster: MonsterDefinition = monster_variant
		if monster.category == &"boss":
			continue
		run_state.shared_inventory.clear()
		run_state.grant_battle_drops(monster, 0)
		_assert(not run_state.shared_inventory.is_empty(), "%s should grant at least one drop item" % monster.display_name)
		for item_variant in run_state.shared_inventory:
			var item: Dictionary = item_variant
			var definition: FoodDefinition = run_state.get_food_definition(item.get("definition_id", &"")) as FoodDefinition
			_assert(definition != null, "Granted drop should resolve to a food definition")
			if definition == null:
				continue
			_assert(
				definition.category == monster.category,
				"%s granted %s (%s), which does not align with monster category %s" % [
					monster.display_name,
					definition.display_name,
					String(definition.category),
					String(monster.category),
				]
			)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("BATTLE_DROP_TEST_PASS")
		quit(0)
	else:
		printerr("BATTLE_DROP_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
