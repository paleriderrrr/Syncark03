extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://Scenes/food_effect_lab.tscn")
	_assert(scene != null, "Food effect lab scene should load")
	if scene == null:
		_finish()
		return
	var lab: Node = scene.instantiate()
	root.add_child(lab)
	await process_frame
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/LeftPanel/LeftMargin/LeftVBox/FoodCatalogStrip") != null, "Food catalog strip should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/CenterPanel/CenterMargin/CenterVBox/BoardCenter/BentoBoardView") != null, "Lab board should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/TopHBox/RightPanel/RightMargin/RightVBox/ActualSummary") != null, "Actual summary should exist")
	_assert(lab.get_node_or_null("Margin/RootVBox/ExpectedPanel/ExpectedMargin/ExpectedVBox/ExpectedScroll/CompareGrid") != null, "Compare grid should exist")
	if lab.has_method("get_catalog_entry_count"):
		_assert(int(lab.call("get_catalog_entry_count")) == 54, "Food effect lab should expose all 54 foods in the catalog")
	var summary: String = lab.call("_build_actual_summary_text", {
		"current_hp": 100.0,
		"max_hp": 100.0,
		"base_hp": 100.0,
		"base_attack": 10.0,
		"attack_bonus": 0.0,
		"bonus_damage": 0.0,
		"attack_speed_bonus": 0.0,
		"heal_per_second": 0.0,
		"execute_threshold": 0.0,
		"retaliate_damage": 0.0,
		"enemy_attack_slow": 0.0,
		"revive_pct": 0.0,
		"crit_chance": 0.0,
		"amber_cancel_chance": 0.0,
		"team_aura_flags": {
			"mixed_feast": true,
			"dessert_pulse_amount": 8.0,
		},
	}, {
		"entries": [{
			"category_name": "Spice",
			"count": 0,
			"active": false,
		}],
	})
	_assert(summary.contains("Spice: 0 type(s)  [OFF]"), "Actual summary should include inactive spice synergy lines")
	_assert(summary.contains("mixed_feast: true"), "Actual summary should stringify boolean team aura flags")
	_assert(summary.contains("dessert_pulse_amount: 8"), "Actual summary should stringify numeric team aura flags")
	lab.queue_free()
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FOOD_EFFECT_LAB_TEST_PASS")
		quit(0)
	else:
		printerr("FOOD_EFFECT_LAB_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
