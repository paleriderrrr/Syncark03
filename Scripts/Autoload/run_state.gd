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
const SAVE_FILE_PATH := "user://run_state.save"
const SAVE_FORMAT_VERSION := 1

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
var settings_return_scene_path: String = "res://Scenes/title_screen.tscn"
var master_volume_percent: float = 100.0
var tutorial_completed: bool = false

var _instance_counter: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _autosave_enabled: bool = false
var _has_persistable_run: bool = false
var _current_run_started_without_save: bool = true

func _ready() -> void:
	_rng.randomize()
	_load_static_data()
	state_changed.connect(_on_state_changed_autosave)
	_load_persistent_metadata()
	apply_master_volume()
	start_new_run(false)
	_autosave_enabled = true

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

func start_new_run(persist_run: bool = true) -> void:
	_current_run_started_without_save = not has_saved_run()
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
	_has_persistable_run = persist_run
	_init_character_states()
	_init_normal_monster_order()
	_generate_market_offers()
	state_changed.emit()
	selected_character_changed.emit(selected_character_id)
	selected_item_changed.emit()

func set_settings_return_scene(path: String) -> void:
	settings_return_scene_path = path

func consume_settings_return_scene(fallback_path: String) -> String:
	var path: String = settings_return_scene_path
	if path.is_empty():
		path = fallback_path
	settings_return_scene_path = fallback_path
	return path

func set_master_volume_percent(value: float) -> void:
	master_volume_percent = clampf(value, 0.0, 100.0)
	apply_master_volume()
	if _autosave_enabled:
		save_run()

func get_master_volume_percent() -> float:
	return master_volume_percent

func is_tutorial_completed() -> bool:
	return tutorial_completed

func mark_tutorial_completed() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	if _autosave_enabled:
		save_run()

func apply_master_volume() -> void:
	var bus_index: int = AudioServer.get_bus_index(&"Master")
	if bus_index < 0:
		return
	var linear_value: float = master_volume_percent / 100.0
	var db_value: float = linear_to_db(linear_value) if linear_value > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus_index, db_value)

func has_saved_run() -> bool:
	var payload: Dictionary = _read_persistence_payload()
	return bool(payload.get("has_run_data", false)) and payload.has("run_data")

func should_auto_open_tutorial_on_editor_entry() -> bool:
	return _current_run_started_without_save or not has_saved_run()

func save_run() -> bool:
	return _write_persistence_payload(_build_persistence_payload())

func ensure_persistable_run() -> void:
	if _has_persistable_run:
		return
	_has_persistable_run = true
	if _autosave_enabled:
		save_run()

func load_run() -> bool:
	var payload: Dictionary = _read_persistence_payload()
	if payload.is_empty() or not bool(payload.get("has_run_data", false)):
		return false
	var run_data_variant: Variant = payload.get("run_data", {})
	if not (run_data_variant is Dictionary):
		return false
	var run_data: Dictionary = run_data_variant
	_apply_persistent_metadata_from_payload(payload)
	if not _apply_run_snapshot(run_data):
		return false
	_current_run_started_without_save = false
	_has_persistable_run = true
	selected_item.clear()
	apply_master_volume()
	state_changed.emit()
	selected_character_changed.emit(selected_character_id)
	selected_item_changed.emit()
	return true

func delete_saved_run() -> void:
	_has_persistable_run = false
	_current_run_started_without_save = true
	_write_persistence_payload(_build_metadata_only_persistence_payload())

func _on_state_changed_autosave() -> void:
	if not _autosave_enabled or not _has_persistable_run:
		return
	save_run()

func _load_persistent_metadata() -> void:
	var payload: Dictionary = _read_persistence_payload()
	if payload.is_empty():
		return
	_apply_persistent_metadata_from_payload(payload)

func _apply_persistent_metadata_from_payload(payload: Dictionary) -> void:
	var settings_variant: Variant = payload.get("settings", {})
	if not (settings_variant is Dictionary):
		return
	var settings: Dictionary = settings_variant
	master_volume_percent = clampf(float(settings.get("master_volume_percent", master_volume_percent)), 0.0, 100.0)
	tutorial_completed = bool(settings.get("tutorial_completed", tutorial_completed))

func _build_persistence_payload() -> Dictionary:
	return {
		"version": SAVE_FORMAT_VERSION,
		"settings": {
			"master_volume_percent": master_volume_percent,
			"tutorial_completed": tutorial_completed,
		},
		"has_run_data": _has_persistable_run,
		"run_data": _build_run_snapshot() if _has_persistable_run else {},
	}

func _build_metadata_only_persistence_payload() -> Dictionary:
	return {
		"version": SAVE_FORMAT_VERSION,
		"settings": {
			"master_volume_percent": master_volume_percent,
			"tutorial_completed": tutorial_completed,
		},
		"has_run_data": false,
		"run_data": {},
	}

func _build_run_snapshot() -> Dictionary:
	return {
		"instance_counter": _instance_counter,
		"current_gold": current_gold,
		"current_route_index": current_route_index,
		"current_market_index": current_market_index,
		"current_reroll_count": current_reroll_count,
		"selected_character_id": selected_character_id,
		"shared_inventory": shared_inventory.duplicate(true),
		"character_states": character_states.duplicate(true),
		"current_market_offers": current_market_offers.duplicate(true),
		"normal_monster_order": normal_monster_order.duplicate(),
		"free_food_purchase_count": free_food_purchase_count,
		"spice_purchase_refund": spice_purchase_refund,
		"battle_reports": battle_reports.duplicate(true),
		"pre_battle_snapshot": pre_battle_snapshot.duplicate(true),
		"run_finished": run_finished,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
	}

func _apply_run_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if stage_flow_config == null or character_roster == null or monster_roster == null or food_catalog == null:
		return _reject_run_snapshot("static data is not loaded")
	var restored_character_states_variant: Variant = snapshot.get("character_states", {})
	if not (restored_character_states_variant is Dictionary):
		return _reject_run_snapshot("character_states must be a dictionary")
	var restored_character_states: Dictionary = restored_character_states_variant
	if restored_character_states.is_empty():
		return _reject_run_snapshot("character_states cannot be empty")
	var restored_route_index: int = int(snapshot.get("current_route_index", 0))
	var restored_market_index: int = int(snapshot.get("current_market_index", 1))
	var restored_reroll_count: int = int(snapshot.get("current_reroll_count", 0))
	if restored_route_index < 0 or restored_market_index < 0 or restored_reroll_count < 0:
		return _reject_run_snapshot("route, market, and reroll indexes must be non-negative")
	if restored_route_index >= stage_flow_config.route_nodes.size():
		return _reject_run_snapshot("current_route_index exceeds route length")
	if restored_market_index < 1 or restored_market_index > 4:
		return _reject_run_snapshot("current_market_index must be in tier range 1..4")
	if int(snapshot.get("instance_counter", 1)) <= 0:
		return _reject_run_snapshot("instance_counter must be positive")
	if int(snapshot.get("current_gold", 0)) < 0:
		return _reject_run_snapshot("current_gold must be non-negative")
	if int(snapshot.get("free_food_purchase_count", 0)) < 0 or int(snapshot.get("spice_purchase_refund", 0)) < 0:
		return _reject_run_snapshot("purchase side-effect counters must be non-negative")
	var restored_selected_character_id := StringName(snapshot.get("selected_character_id", &"warrior"))
	if not restored_character_states.has(restored_selected_character_id):
		return _reject_run_snapshot("selected character is missing from character_states")
	var restored_normal_monster_order: Array[StringName] = _duplicate_string_name_array(snapshot.get("normal_monster_order", []))
	if restored_normal_monster_order.is_empty():
		return _reject_run_snapshot("normal_monster_order cannot be empty")
	if not _validate_normal_monster_order(restored_normal_monster_order):
		return false
	var pre_battle_snapshot_variant: Variant = snapshot.get("pre_battle_snapshot", {})
	if not (pre_battle_snapshot_variant is Dictionary):
		return _reject_run_snapshot("pre_battle_snapshot must be a dictionary")
	var instance_ids: Dictionary = {}
	if not _validate_inventory_snapshot(snapshot.get("shared_inventory", []), instance_ids):
		return false
	if not _validate_character_states_snapshot(restored_character_states, instance_ids):
		return false
	if not _validate_market_offers_snapshot(snapshot.get("current_market_offers", [])):
		return false
	if not _validate_battle_reports_snapshot(snapshot.get("battle_reports", [])):
		return false
	current_gold = int(snapshot.get("current_gold", stage_flow_config.initial_gold if stage_flow_config else 30))
	current_route_index = restored_route_index
	current_market_index = restored_market_index
	current_reroll_count = restored_reroll_count
	selected_character_id = restored_selected_character_id
	shared_inventory = _duplicate_dictionary_array(snapshot.get("shared_inventory", []))
	character_states = restored_character_states.duplicate(true)
	current_market_offers = _duplicate_dictionary_array(snapshot.get("current_market_offers", []))
	normal_monster_order = restored_normal_monster_order
	free_food_purchase_count = int(snapshot.get("free_food_purchase_count", 0))
	spice_purchase_refund = int(snapshot.get("spice_purchase_refund", 0))
	battle_reports = _duplicate_dictionary_array(snapshot.get("battle_reports", []))
	var restored_pre_battle_snapshot: Dictionary = pre_battle_snapshot_variant
	pre_battle_snapshot = restored_pre_battle_snapshot.duplicate(true)
	run_finished = bool(snapshot.get("run_finished", false))
	_instance_counter = int(snapshot.get("instance_counter", 1))
	if snapshot.has("rng_seed"):
		_rng.seed = int(snapshot.get("rng_seed", _rng.seed))
	if snapshot.has("rng_state"):
		_rng.state = int(snapshot.get("rng_state", _rng.state))
	return true

func _reject_run_snapshot(reason: String) -> bool:
	push_warning("Invalid run snapshot: %s" % reason)
	return false

func _validate_normal_monster_order(order: Array[StringName]) -> bool:
	for monster_id in order:
		var monster: MonsterDefinition = get_monster_definition(monster_id)
		if monster == null:
			return _reject_run_snapshot("normal monster order references unknown monster: %s" % String(monster_id))
		if monster.category == &"boss":
			return _reject_run_snapshot("normal monster order cannot contain boss monster: %s" % String(monster_id))
	return true

func _validate_inventory_snapshot(value: Variant, instance_ids: Dictionary) -> bool:
	if not (value is Array):
		return _reject_run_snapshot("shared_inventory must be an array")
	var inventory: Array = value
	for item_variant in inventory:
		if not (item_variant is Dictionary):
			return _reject_run_snapshot("inventory entries must be dictionaries")
		var item: Dictionary = item_variant
		if not _register_instance_id(item.get("instance_id", &""), instance_ids, "inventory"):
			return false
		var definition_id := StringName(item.get("definition_id", &""))
		if get_food_definition(definition_id) == null:
			return _reject_run_snapshot("inventory references unknown food: %s" % String(definition_id))
		if not _is_valid_rotation(item.get("rotation", 0)):
			return _reject_run_snapshot("inventory item rotation is invalid")
		if int(item.get("reroll_bonus_count", 0)) < 0:
			return _reject_run_snapshot("inventory reroll bonus cannot be negative")
	return true

func _validate_character_states_snapshot(states: Dictionary, instance_ids: Dictionary) -> bool:
	for definition_variant in character_roster.characters:
		var definition: CharacterDefinition = definition_variant
		if not states.has(definition.id):
			return _reject_run_snapshot("missing character state: %s" % String(definition.id))
		var state_variant: Variant = states[definition.id]
		if not (state_variant is Dictionary):
			return _reject_run_snapshot("character state must be a dictionary: %s" % String(definition.id))
		var state: Dictionary = state_variant
		if StringName(state.get("id", definition.id)) != definition.id:
			return _reject_run_snapshot("character state id mismatch: %s" % String(definition.id))
		if float(state.get("hp_ratio", 1.0)) < 0.0 or float(state.get("hp_ratio", 1.0)) > 1.0:
			return _reject_run_snapshot("character hp_ratio must be in 0..1")
		if not _is_vector2i_array(state.get("base_shape", []), false):
			return _reject_run_snapshot("base_shape must be a non-empty Vector2i array")
		if not (state.get("base_anchor", null) is Vector2i):
			return _reject_run_snapshot("base_anchor must be Vector2i")
		if not _is_vector2i_array(state.get("active_cells", []), false):
			return _reject_run_snapshot("active_cells must be a non-empty Vector2i array")
		var base_cells: Array[Vector2i] = ShapeUtils.translate_cells(_typed_cells_from_variant(state["base_shape"]), state["base_anchor"])
		if not ShapeUtils.within_bounds(base_cells, GRID_WIDTH, GRID_HEIGHT):
			return _reject_run_snapshot("base cells are out of bounds")
		if not _validate_expansion_arrays_for_character(definition.id, state, instance_ids, base_cells):
			return false
		if not _validate_placed_foods_for_character(definition.id, state, instance_ids):
			return false
		var expected_active_cells: Array[Vector2i] = _build_active_cells_for_expansions(state, state.get("placed_expansions", []))
		if not _cell_sets_equal(_typed_cells_from_variant(state["active_cells"]), expected_active_cells):
			return _reject_run_snapshot("active_cells do not match base plus placed expansions")
		if not _are_expansions_connected_to_base(state, state.get("placed_expansions", [])):
			return _reject_run_snapshot("placed expansions are disconnected from base")
	return true

func _validate_expansion_arrays_for_character(character_id: StringName, state: Dictionary, instance_ids: Dictionary, base_cells: Array[Vector2i]) -> bool:
	if not (state.get("placed_expansions", []) is Array):
		return _reject_run_snapshot("placed_expansions must be an array")
	if not (state.get("pending_expansions", []) is Array):
		return _reject_run_snapshot("pending_expansions must be an array")
	var occupied_cells: Dictionary = ShapeUtils.cells_to_lookup(base_cells)
	for expansion_variant in state.get("placed_expansions", []):
		if not (expansion_variant is Dictionary):
			return _reject_run_snapshot("placed expansion entries must be dictionaries")
		var expansion: Dictionary = expansion_variant
		if not _validate_expansion_record(expansion, instance_ids, "placed expansion"):
			return false
		var cells: Array[Vector2i] = _typed_cells_from_variant(expansion["cells"])
		if not ShapeUtils.within_bounds(cells, GRID_WIDTH, GRID_HEIGHT):
			return _reject_run_snapshot("placed expansion cells are out of bounds")
		if not _cells_match_shape(expansion.get("shape_cells", []), int(expansion.get("rotation", 0)), expansion.get("anchor", Vector2i.ZERO), cells):
			return _reject_run_snapshot("placed expansion cells do not match shape, rotation, and anchor")
		for cell in cells:
			var key: String = "%d:%d" % [cell.x, cell.y]
			if occupied_cells.has(key):
				return _reject_run_snapshot("placed expansion cells overlap occupied board cells")
			occupied_cells[key] = true
	for pending_variant in state.get("pending_expansions", []):
		if not (pending_variant is Dictionary):
			return _reject_run_snapshot("pending expansion entries must be dictionaries")
		var pending: Dictionary = pending_variant
		if not _validate_expansion_record(pending, instance_ids, "pending expansion", false):
			return false
		if StringName(pending.get("target_character_id", &"")) != character_id:
			return _reject_run_snapshot("pending expansion target does not match owning character")
	return true

func _validate_expansion_record(expansion: Dictionary, instance_ids: Dictionary, label: String, require_cells: bool = true) -> bool:
	if not _register_instance_id(expansion.get("instance_id", &""), instance_ids, label):
		return false
	if String(expansion.get("label", "")).is_empty():
		return _reject_run_snapshot("%s label cannot be empty" % label)
	if not _is_vector2i_array(expansion.get("shape_cells", []), false):
		return _reject_run_snapshot("%s shape_cells must be a non-empty Vector2i array" % label)
	if not _is_valid_rotation(expansion.get("rotation", 0)):
		return _reject_run_snapshot("%s rotation is invalid" % label)
	if require_cells:
		if not (expansion.get("anchor", null) is Vector2i):
			return _reject_run_snapshot("%s anchor must be Vector2i" % label)
		if not _is_vector2i_array(expansion.get("cells", []), false):
			return _reject_run_snapshot("%s cells must be a non-empty Vector2i array" % label)
	return true

func _validate_placed_foods_for_character(character_id: StringName, state: Dictionary, instance_ids: Dictionary) -> bool:
	if not (state.get("placed_foods", []) is Array):
		return _reject_run_snapshot("placed_foods must be an array")
	var active_cells: Array[Vector2i] = _typed_cells_from_variant(state["active_cells"])
	var occupied_food_cells: Dictionary = {}
	for item_variant in state.get("placed_foods", []):
		if not (item_variant is Dictionary):
			return _reject_run_snapshot("placed food entries must be dictionaries")
		var item: Dictionary = item_variant
		if not _register_instance_id(item.get("instance_id", &""), instance_ids, "placed food"):
			return false
		var definition_id := StringName(item.get("definition_id", &""))
		var definition: FoodDefinition = get_food_definition(definition_id)
		if definition == null:
			return _reject_run_snapshot("placed food references unknown food: %s" % String(definition_id))
		if not (item.get("anchor", null) is Vector2i):
			return _reject_run_snapshot("placed food anchor must be Vector2i")
		if not _is_valid_rotation(item.get("rotation", 0)):
			return _reject_run_snapshot("placed food rotation is invalid")
		if not _is_vector2i_array(item.get("cells", []), false):
			return _reject_run_snapshot("placed food cells must be a non-empty Vector2i array")
		if int(item.get("reroll_bonus_count", 0)) < 0:
			return _reject_run_snapshot("placed food reroll bonus cannot be negative")
		var cells: Array[Vector2i] = _typed_cells_from_variant(item["cells"])
		if not ShapeUtils.within_bounds(cells, GRID_WIDTH, GRID_HEIGHT):
			return _reject_run_snapshot("placed food cells are out of bounds")
		if not ShapeUtils.contains_all(active_cells, cells):
			return _reject_run_snapshot("placed food cells are outside active cells for %s" % String(character_id))
		if not _cells_match_shape(definition.shape_cells, int(item.get("rotation", 0)), item.get("anchor", Vector2i.ZERO), cells):
			return _reject_run_snapshot("placed food cells do not match definition shape, rotation, and anchor")
		for cell in cells:
			var key: String = "%d:%d" % [cell.x, cell.y]
			if occupied_food_cells.has(key):
				return _reject_run_snapshot("placed foods overlap")
			occupied_food_cells[key] = true
	return true

func _validate_market_offers_snapshot(value: Variant) -> bool:
	if not (value is Array):
		return _reject_run_snapshot("current_market_offers must be an array")
	var offer_ids: Dictionary = {}
	for offer_variant in value:
		if not (offer_variant is Dictionary):
			return _reject_run_snapshot("market offers must be dictionaries")
		var offer: Dictionary = offer_variant
		var offer_id := StringName(offer.get("offer_id", &""))
		if offer_id == &"":
			return _reject_run_snapshot("market offer id cannot be empty")
		if offer_ids.has(offer_id):
			return _reject_run_snapshot("duplicate market offer id: %s" % String(offer_id))
		offer_ids[offer_id] = true
		if int(offer.get("slot_index", 0)) < 0:
			return _reject_run_snapshot("market offer slot index must be non-negative")
		if int(offer.get("price", 0)) < 0:
			return _reject_run_snapshot("market offer price cannot be negative")
		match offer.get("kind", &""):
			&"food":
				var definition_id := StringName(offer.get("definition_id", &""))
				if get_food_definition(definition_id) == null:
					return _reject_run_snapshot("market food offer references unknown food: %s" % String(definition_id))
				if int(offer.get("quantity", 0)) <= 0:
					return _reject_run_snapshot("market food offer quantity must be positive")
				if float(offer.get("discount", 0.0)) <= 0.0:
					return _reject_run_snapshot("market food offer discount must be positive")
				if not [&"common", &"rare", &"epic"].has(StringName(offer.get("rarity", &""))):
					return _reject_run_snapshot("market food offer rarity is invalid")
			&"expansion":
				var target_id := StringName(offer.get("target_character_id", &""))
				if not character_states.has(target_id) and not _character_roster_has(target_id):
					return _reject_run_snapshot("market expansion offer targets unknown character: %s" % String(target_id))
				if String(offer.get("label", "")).is_empty():
					return _reject_run_snapshot("market expansion offer label cannot be empty")
				if not _is_vector2i_array(offer.get("shape_cells", []), false):
					return _reject_run_snapshot("market expansion offer shape must be non-empty")
			_:
				return _reject_run_snapshot("market offer kind is invalid")
	return true

func _validate_battle_reports_snapshot(value: Variant) -> bool:
	if not (value is Array):
		return _reject_run_snapshot("battle_reports must be an array")
	for report_variant in value:
		if not (report_variant is Dictionary):
			return _reject_run_snapshot("battle reports must be dictionaries")
		var report: Dictionary = report_variant
		var result: String = String(report.get("result", ""))
		if result != "win" and result != "lose":
			return _reject_run_snapshot("battle report result is invalid")
		var monster_id := StringName(report.get("monster_id", &""))
		if monster_id != &"" and get_monster_definition(monster_id) == null:
			return _reject_run_snapshot("battle report references unknown monster: %s" % String(monster_id))
	return true

func _register_instance_id(value: Variant, instance_ids: Dictionary, label: String) -> bool:
	var instance_id := StringName(value)
	if instance_id == &"":
		return _reject_run_snapshot("%s instance_id cannot be empty" % label)
	if instance_ids.has(instance_id):
		return _reject_run_snapshot("duplicate instance_id in snapshot: %s" % String(instance_id))
	instance_ids[instance_id] = true
	return true

func _character_roster_has(character_id: StringName) -> bool:
	if character_roster == null:
		return false
	for definition_variant in character_roster.characters:
		var definition: CharacterDefinition = definition_variant
		if definition.id == character_id:
			return true
	return false

func _is_vector2i_array(value: Variant, allow_empty: bool) -> bool:
	if not (value is Array):
		return false
	var cells: Array = value
	if not allow_empty and cells.is_empty():
		return false
	for cell_variant in cells:
		if not (cell_variant is Vector2i):
			return false
	return true

func _typed_cells_from_variant(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not (value is Array):
		return result
	var cells: Array = value
	for cell_variant in cells:
		result.append(cell_variant)
	return result

func _is_valid_rotation(value: Variant) -> bool:
	if not (value is int):
		return false
	var rotation: int = int(value)
	return rotation >= 0 and rotation < 4

func _cells_match_shape(shape_value: Variant, rotation: int, anchor: Vector2i, cells: Array[Vector2i]) -> bool:
	if not _is_vector2i_array(shape_value, false):
		return false
	var shape_cells: Array[Vector2i] = _typed_cells_from_variant(shape_value)
	var expected_cells: Array[Vector2i] = ShapeUtils.translate_cells(ShapeUtils.rotate_cells(shape_cells, rotation), anchor)
	return _cell_sets_equal(expected_cells, cells)

func _cell_sets_equal(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	var lookup: Dictionary = ShapeUtils.cells_to_lookup(a)
	if lookup.size() != a.size():
		return false
	var other_lookup: Dictionary = ShapeUtils.cells_to_lookup(b)
	if other_lookup.size() != b.size():
		return false
	for key in lookup.keys():
		if not other_lookup.has(key):
			return false
	return true

func combat_randf() -> float:
	return _rng.randf()

func combat_randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func _write_persistence_payload(payload: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(var_to_str(payload))
	return file.get_error() == OK

func _read_persistence_payload() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var payload_variant: Variant = str_to_var(file.get_as_text())
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		return payload
	return {}

func _duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry_variant in value:
		if entry_variant is Dictionary:
			result.append(entry_variant.duplicate(true))
	return result

func _duplicate_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for entry_variant in value:
		result.append(StringName(entry_variant))
	return result

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
	return stage_flow_config.route_nodes[clampi(current_route_index, 0, stage_flow_config.route_nodes.size() - 1)]

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
	if not character_states.has(character_id):
		push_error("Cannot select unknown character: %s" % String(character_id))
		return
	selected_character_id = character_id
	selected_character_changed.emit(selected_character_id)
	state_changed.emit()

func get_selected_character_state() -> Dictionary:
	return character_states.get(selected_character_id, {})

func get_character_state(character_id: StringName) -> Dictionary:
	return character_states.get(character_id, {})

func _capture_character_health_snapshot(character_id: StringName) -> Dictionary:
	var actor: Dictionary = CombatEngine.preview_character_actor(self, character_id)
	if actor.is_empty():
		return {}
	var max_hp: float = maxf(float(actor.get("max_hp", 0.0)), 1.0)
	var current_hp: float = clampf(float(actor.get("current_hp", 0.0)), 0.0, max_hp)
	return {
		"max_hp": max_hp,
		"current_hp": current_hp,
	}

func _reconcile_character_health_after_board_change(character_id: StringName, before_health: Dictionary) -> void:
	if before_health.is_empty() or not character_states.has(character_id):
		return
	var actor: Dictionary = CombatEngine.preview_character_actor(self, character_id)
	if actor.is_empty():
		return
	var new_max_hp: float = maxf(float(actor.get("max_hp", 0.0)), 1.0)
	var old_max_hp: float = maxf(float(before_health.get("max_hp", new_max_hp)), 1.0)
	var old_current_hp: float = clampf(float(before_health.get("current_hp", new_max_hp)), 0.0, old_max_hp)
	var preserved_missing_hp: float = maxf(0.0, old_max_hp - old_current_hp)
	var target_current_hp: float = clampf(new_max_hp - preserved_missing_hp, 0.0, new_max_hp)
	character_states[character_id]["hp_ratio"] = target_current_hp / new_max_hp

func get_food_definition(food_id: StringName) -> FoodDefinition:
	return food_lookup.get(food_id) as FoodDefinition

func get_monster_definition(monster_id: StringName) -> MonsterDefinition:
	return monster_lookup.get(monster_id) as MonsterDefinition

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

func get_current_battle_sequence_index() -> int:
	if get_current_node_type() == NODE_BOSS_BATTLE:
		return normal_monster_order.size()
	return get_completed_battle_count()

func get_current_monster_multipliers() -> Dictionary:
	var battle_index: int = get_current_battle_sequence_index()
	var hp_multiplier: float = 1.0
	var attack_multiplier: float = 1.0
	if stage_flow_config != null:
		if battle_index >= 0 and battle_index < stage_flow_config.monster_hp_multiplier_curve.size():
			hp_multiplier = float(stage_flow_config.monster_hp_multiplier_curve[battle_index])
		if battle_index >= 0 and battle_index < stage_flow_config.monster_attack_multiplier_curve.size():
			attack_multiplier = float(stage_flow_config.monster_attack_multiplier_curve[battle_index])
	return {
		"hp": hp_multiplier,
		"attack": attack_multiplier,
	}

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
	state["active_cells"] = _build_active_cells_for_expansions(state, state.get("placed_expansions", []))

func _build_active_cells_for_expansions(state: Dictionary, expansions: Array) -> Array[Vector2i]:
	var active_cells: Array[Vector2i] = ShapeUtils.translate_cells(_clone_cells(state.get("base_shape", [])), state.get("base_anchor", Vector2i.ZERO))
	for expansion in expansions:
		for cell_variant in expansion.get("cells", []):
			active_cells.append(cell_variant)
	return active_cells

func _are_expansions_connected_to_base(state: Dictionary, expansions: Array) -> bool:
	var active_cells: Array[Vector2i] = _build_active_cells_for_expansions(state, expansions)
	if active_cells.is_empty():
		return false
	var active_lookup: Dictionary = ShapeUtils.cells_to_lookup(active_cells)
	var base_cells: Array[Vector2i] = ShapeUtils.translate_cells(_clone_cells(state.get("base_shape", [])), state.get("base_anchor", Vector2i.ZERO))
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}
	for base_cell in base_cells:
		var base_key: String = "%d:%d" % [base_cell.x, base_cell.y]
		if active_lookup.has(base_key):
			queue.append(base_cell)
			visited[base_key] = true
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var cursor: int = 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for offset in offsets:
			var neighbor: Vector2i = current + offset
			var key: String = "%d:%d" % [neighbor.x, neighbor.y]
			if not active_lookup.has(key) or visited.has(key):
				continue
			visited[key] = true
			queue.append(neighbor)
	for active_cell in active_cells:
		if not visited.has("%d:%d" % [active_cell.x, active_cell.y]):
			return false
	return true

func _build_candidate_expansion_layout(state: Dictionary, moving_instance_id: StringName, anchor: Vector2i, cells: Array[Vector2i], rotation: int) -> Array:
	var result: Array = []
	var replaced: bool = false
	for expansion_variant in state.get("placed_expansions", []):
		var expansion: Dictionary = expansion_variant
		var candidate: Dictionary = expansion.duplicate(true)
		if expansion.get("instance_id", &"") == moving_instance_id:
			candidate["anchor"] = anchor
			candidate["cells"] = cells
			candidate["rotation"] = rotation
			replaced = true
		result.append(candidate)
	if not replaced and moving_instance_id != &"":
		result.append({
			"instance_id": moving_instance_id,
			"anchor": anchor,
			"cells": cells,
			"rotation": rotation,
		})
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
	if get_current_node_type() != NODE_MARKET:
		state_changed.emit()
		return
	var used_food_ids: Dictionary = {}
	for slot_index in market_config.slot_count:
		var offer: Dictionary = {}
		if _rng.randf() < market_config.expansion_slot_chance:
			offer = _roll_expansion_offer(slot_index)
		else:
			offer = _roll_food_offer(slot_index, used_food_ids)
		if not offer.is_empty():
			current_market_offers.append(offer)
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
		var offer: Dictionary = {}
		if _rng.randf() < market_config.expansion_slot_chance:
			offer = _roll_expansion_offer(slot_index)
		else:
			offer = _roll_food_offer(slot_index, used_food_ids)
		if not offer.is_empty():
			current_market_offers.append(offer)
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
	if market_config == null or market_config.expansion_offers.is_empty():
		push_error("Market config has no expansion offers.")
		return {}
	if character_roster == null or character_roster.characters.is_empty():
		push_error("Character roster has no characters for expansion offers.")
		return {}
	var total_weight: float = 0.0
	for entry_variant in market_config.expansion_offers:
		var entry: Dictionary = entry_variant
		total_weight += maxf(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		push_error("Market expansion offer weights must be positive.")
		return {}
	var roll: float = _rng.randf() * total_weight
	var accumulated: float = 0.0
	var picked: Dictionary = market_config.expansion_offers[0]
	for entry in market_config.expansion_offers:
		accumulated += maxf(0.0, float(entry.get("weight", 0.0)))
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
	if market_config == null or market_config.rarity_weights_by_market.is_empty():
		push_error("Market config has no rarity weights.")
		return {}
	for entry in market_config.rarity_weights_by_market:
		if int(entry["market"]) == get_current_market_tier():
			return entry
	return market_config.rarity_weights_by_market[0]

func _roll_food_offer(slot_index: int, used_food_ids: Dictionary = {}) -> Dictionary:
	var weights: Dictionary = _get_rarity_weights_for_market()
	if weights.is_empty():
		return {}
	if food_catalog == null or food_catalog.foods.is_empty():
		push_error("Food catalog has no foods for market offers.")
		return {}
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
	if candidates.is_empty():
		push_error("Food catalog has no candidates for market offer generation.")
		return {}
	var definition: FoodDefinition = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var quantity_range: Vector2i = market_config.quantity_ranges.get(String(rarity), Vector2i.ONE)
	var quantity: int = _rng.randi_range(quantity_range.x, quantity_range.y)
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
	var offer_definition: FoodDefinition = null
	if offer.get("kind", &"") == &"food":
		offer_definition = get_food_definition(offer.get("definition_id", &""))
		if offer_definition == null:
			return false
	var price: int = int(offer["price"])
	if offer["kind"] == &"food" and free_food_purchase_count > 0:
		price = 0
		free_food_purchase_count -= 1
	if current_gold < price:
		return false
	current_gold -= price
	current_market_offers.remove_at(index)
	if offer["kind"] == &"food":
		for _i in int(offer["quantity"]):
			var instance: Dictionary = generate_item_instance(offer["definition_id"])
			shared_inventory.append(instance)
			if offer_definition.id != &"travel_bento":
				_apply_food_purchase_side_effects(instance)
		if offer_definition.id == &"travel_bento":
			_apply_food_purchase_side_effects_for_package(offer_definition)
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
	state_changed.emit()
	return true

func purchase_market_offer_package(offer_id: StringName) -> Array[Dictionary]:
	var index: int = resolve_offer_index_by_id(offer_id)
	if index < 0 or index >= current_market_offers.size():
		return []
	var offer: Dictionary = current_market_offers[index]
	var offer_definition: FoodDefinition = null
	if offer.get("kind", &"") == &"food":
		offer_definition = get_food_definition(offer.get("definition_id", &""))
		if offer_definition == null:
			return []
	var gained_items: Array[Dictionary] = []
	var price: int = int(offer["price"])
	if offer["kind"] == &"food" and free_food_purchase_count > 0:
		price = 0
		free_food_purchase_count -= 1
	if current_gold < price:
		return []
	current_gold -= price
	current_market_offers.remove_at(index)
	if offer["kind"] == &"food":
		for _i in int(offer["quantity"]):
			var instance: Dictionary = generate_item_instance(offer["definition_id"])
			shared_inventory.append(instance)
			gained_items.append(instance)
			if offer_definition.id != &"travel_bento":
				_apply_food_purchase_side_effects(instance)
		if offer_definition.id == &"travel_bento":
			_apply_food_purchase_side_effects_for_package(offer_definition)
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
	if definition == null:
		push_error("Cannot apply purchase side effects for unknown food definition: %s" % String(instance.get("definition_id", &"")))
		return
	match definition.id:
		&"travel_bento":
			_apply_food_purchase_side_effects_for_package(definition)
		&"curry_can":
			current_gold += 3
			spice_purchase_refund += 1
		_:
			pass
	if definition.category == &"spice" and spice_purchase_refund > 0 and definition.id != &"curry_can":
		current_gold += spice_purchase_refund
	if definition.id == &"cellar_vintage":
		instance["reroll_bonus_count"] = 0

func _apply_food_purchase_side_effects_for_package(definition: FoodDefinition) -> void:
	match definition.id:
		&"travel_bento":
			free_food_purchase_count += 1
			_generate_market_offers()
		_:
			pass

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
				"drag_session": false,
			}
			selected_item_changed.emit()
			state_changed.emit()
			return

func pick_inventory_instance(group_key: StringName) -> Dictionary:
	var selected_inventory_item: Dictionary = {}
	for item in shared_inventory:
		if item.get("definition_id", &"") == group_key:
			if selected_inventory_item.is_empty() or int(item.get("reroll_bonus_count", 0)) > int(selected_inventory_item.get("reroll_bonus_count", 0)):
				selected_inventory_item = item
	if selected_inventory_item.is_empty():
		return {}
	selected_item = {
		"source": &"inventory",
		"instance_id": selected_inventory_item["instance_id"],
		"rotation": int(selected_inventory_item.get("rotation", 0)),
		"drag_session": false,
	}
	selected_item_changed.emit()
	state_changed.emit()
	return selected_item.duplicate(true)

func begin_inventory_drag(group_key: StringName) -> Dictionary:
	var action: Dictionary = pick_inventory_instance(group_key)
	if action.is_empty():
		return {}
	selected_item["drag_session"] = true
	selected_item_changed.emit()
	state_changed.emit()
	return selected_item.duplicate(true)

func begin_market_offer_action(offer_id: StringName) -> Dictionary:
	var offer: Dictionary = _find_market_offer(offer_id)
	if offer.is_empty() or offer.get("kind", &"") != &"food":
		return {}
	selected_item = {
		"source": &"market_offer",
		"offer_id": offer_id,
		"definition_id": offer.get("definition_id", &""),
		"rotation": 0,
		"drag_session": true,
	}
	selected_item_changed.emit()
	state_changed.emit()
	return selected_item.duplicate(true)

func begin_market_expansion_action(offer_id: StringName) -> Dictionary:
	var offer: Dictionary = _find_market_offer(offer_id)
	if offer.is_empty() or offer.get("kind", &"") != &"expansion":
		return {}
	selected_item = {
		"source": &"market_expansion",
		"offer_id": offer_id,
		"rotation": 0,
		"drag_session": true,
		"target_character_id": offer.get("target_character_id", &""),
	}
	selected_item_changed.emit()
	state_changed.emit()
	return selected_item.duplicate(true)

func begin_board_food_action(from_cell: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	var key: String = "%d:%d" % [from_cell.x, from_cell.y]
	for item_variant in state.get("placed_foods", []):
		var item: Dictionary = item_variant
		if not ShapeUtils.cells_to_lookup(item.get("cells", [])).has(key):
			continue
		selected_item = {
			"source": &"board_food",
			"instance_id": item.get("instance_id", &""),
			"definition_id": item.get("definition_id", &""),
			"rotation": int(item.get("rotation", 0)),
			"origin_anchor": item.get("anchor", Vector2i.ZERO),
			"drag_session": true,
		}
		selected_item_changed.emit()
		state_changed.emit()
		return true
	return false

func begin_board_expansion_action(from_cell: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	var key: String = "%d:%d" % [from_cell.x, from_cell.y]
	for item_variant in state.get("placed_expansions", []):
		var item: Dictionary = item_variant
		if not ShapeUtils.cells_to_lookup(item.get("cells", [])).has(key):
			continue
		selected_item = {
			"source": &"board_expansion",
			"instance_id": item.get("instance_id", &""),
			"rotation": int(item.get("rotation", 0)),
			"origin_anchor": item.get("anchor", Vector2i.ZERO),
			"drag_session": true,
		}
		selected_item_changed.emit()
		state_changed.emit()
		return true
	return false

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

func select_pending_expansion(instance_id: StringName, target_character_id: StringName = &"") -> bool:
	var owner_character_id: StringName = _resolve_pending_expansion_owner(instance_id, target_character_id)
	if owner_character_id == &"":
		return false
	var pending: Dictionary = _find_pending_expansion(owner_character_id, instance_id)
	if pending.is_empty():
		return false
	var character_changed: bool = selected_character_id != owner_character_id
	selected_character_id = owner_character_id
	selected_item = {
		"source": &"pending_expansion",
		"instance_id": instance_id,
		"rotation": int(pending.get("rotation", 0)),
		"drag_session": false,
		"target_character_id": owner_character_id,
	}
	if character_changed:
		selected_character_changed.emit(selected_character_id)
	selected_item_changed.emit()
	state_changed.emit()
	return true

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
		if definition == null:
			push_error("Missing food definition for selected inventory item: %s" % String(item.get("definition_id", &"")))
			return []
		return ShapeUtils.rotate_cells(definition.shape_cells, int(selected_item["rotation"]))
	if source == &"market_offer":
		var offer: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
		if offer.is_empty():
			return []
		var offer_definition: FoodDefinition = get_food_definition(offer.get("definition_id", &""))
		if offer_definition == null:
			return []
		return ShapeUtils.rotate_cells(offer_definition.shape_cells, int(selected_item["rotation"]))
	if source == &"board_food":
		var placed_food: Dictionary = _find_placed_food(selected_character_id, selected_item.get("instance_id", &""))
		if placed_food.is_empty():
			return []
		var placed_definition: FoodDefinition = get_food_definition(placed_food.get("definition_id", &""))
		if placed_definition == null:
			return []
		return ShapeUtils.rotate_cells(placed_definition.shape_cells, int(selected_item["rotation"]))
	if source == &"board_expansion":
		var placed_expansion: Dictionary = _find_placed_expansion(selected_character_id, selected_item.get("instance_id", &""))
		if placed_expansion.is_empty():
			return []
		var shape_cells: Array[Vector2i] = _clone_cells(placed_expansion.get("shape_cells", []))
		if shape_cells.is_empty():
			return []
		return ShapeUtils.rotate_cells(shape_cells, int(selected_item["rotation"]))
	if source == &"market_expansion":
		var offer_expansion: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
		if offer_expansion.is_empty():
			return []
		return ShapeUtils.rotate_cells(_clone_cells(offer_expansion.get("shape_cells", [])), int(selected_item["rotation"]))
	if source == &"pending_expansion" or source == &"expansion":
		var pending_character_id: StringName = selected_item.get("target_character_id", selected_character_id)
		var pending: Dictionary = _find_pending_expansion(pending_character_id, selected_item["instance_id"])
		if pending.is_empty():
			pending_character_id = _resolve_pending_expansion_owner(selected_item["instance_id"], pending_character_id)
			pending = _find_pending_expansion(pending_character_id, selected_item["instance_id"])
		if pending.is_empty():
			return []
		return ShapeUtils.rotate_cells(_clone_cells(pending["shape_cells"]), int(selected_item["rotation"]))
	return []

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

func _resolve_pending_expansion_owner(instance_id: StringName, preferred_character_id: StringName = &"") -> StringName:
	if preferred_character_id != &"":
		var preferred_pending: Dictionary = _find_pending_expansion(preferred_character_id, instance_id)
		if not preferred_pending.is_empty():
			return preferred_character_id
	for character_id_variant in character_states.keys():
		var character_id: StringName = character_id_variant
		var pending: Dictionary = _find_pending_expansion(character_id, instance_id)
		if not pending.is_empty():
			return character_id
	return &""

func _find_market_offer(offer_id: StringName) -> Dictionary:
	for offer_variant in current_market_offers:
		var offer: Dictionary = offer_variant
		if offer.get("offer_id", &"") == offer_id:
			return offer
	return {}

func _find_placed_food(character_id: StringName, instance_id: StringName) -> Dictionary:
	var state: Dictionary = get_character_state(character_id)
	for item_variant in state.get("placed_foods", []):
		var item: Dictionary = item_variant
		if item.get("instance_id", &"") == instance_id:
			return item
	return {}

func _find_placed_expansion(character_id: StringName, instance_id: StringName) -> Dictionary:
	var state: Dictionary = get_character_state(character_id)
	for item_variant in state.get("placed_expansions", []):
		var item: Dictionary = item_variant
		if item.get("instance_id", &"") == instance_id:
			return item
	return {}

func can_place_selected_item(anchor: Vector2i) -> bool:
	if selected_item.is_empty():
		return false
	var local_cells: Array[Vector2i] = get_selected_item_cells()
	if local_cells.is_empty():
		return false
	var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(local_cells, anchor)
	if not ShapeUtils.within_bounds(placed_cells, GRID_WIDTH, GRID_HEIGHT):
		return false
	var state: Dictionary = get_selected_character_state()
	match selected_item.get("source", &""):
		&"inventory", &"market_offer":
			if not ShapeUtils.contains_all(state["active_cells"], placed_cells):
				return false
			return not ShapeUtils.overlaps(get_board_item_cells(selected_character_id), placed_cells)
		&"board_food":
			if not ShapeUtils.contains_all(state["active_cells"], placed_cells):
				return false
			var moving_item: Dictionary = _find_placed_food(selected_character_id, selected_item.get("instance_id", &""))
			if moving_item.is_empty():
				return false
			var occupied_by_others: Array[Vector2i] = []
			for other_variant in state.get("placed_foods", []):
				var other_item: Dictionary = other_variant
				if other_item.get("instance_id", &"") == moving_item.get("instance_id", &""):
					continue
				for other_cell_variant in other_item.get("cells", []):
					var other_cell: Vector2i = other_cell_variant
					occupied_by_others.append(other_cell)
			return not ShapeUtils.overlaps(occupied_by_others, placed_cells)
		&"board_expansion":
			var moving_expansion: Dictionary = _find_placed_expansion(selected_character_id, selected_item.get("instance_id", &""))
			if moving_expansion.is_empty():
				return false
			var active_without_self: Array[Vector2i] = _clone_cells(state["active_cells"])
			for owned_cell in moving_expansion.get("cells", []):
				_remove_active_cell(active_without_self, owned_cell)
			if ShapeUtils.overlaps(active_without_self, placed_cells):
				return false
			if not ShapeUtils.shares_edge(placed_cells, active_without_self):
				return false
			var candidate_layout: Array = _build_candidate_expansion_layout(state, moving_expansion.get("instance_id", &""), anchor, placed_cells, int(selected_item["rotation"]))
			return _are_expansions_connected_to_base(state, candidate_layout)
		&"pending_expansion", &"expansion", &"market_expansion":
			if selected_item.get("target_character_id", selected_character_id) != selected_character_id:
				return false
			if ShapeUtils.overlaps(state["active_cells"], placed_cells):
				return false
			if not ShapeUtils.shares_edge(placed_cells, state["active_cells"]):
				return false
			var expansion_id: StringName = selected_item.get("instance_id", &"")
			var new_layout: Array = _build_candidate_expansion_layout(state, expansion_id, anchor, placed_cells, int(selected_item["rotation"]))
			return _are_expansions_connected_to_base(state, new_layout)
		_:
			return false

func try_place_selected_item(anchor: Vector2i) -> bool:
	if not can_place_selected_item(anchor):
		return false
	var local_cells: Array[Vector2i] = get_selected_item_cells()
	var placed_cells: Array[Vector2i] = ShapeUtils.translate_cells(local_cells, anchor)
	var state: Dictionary = get_selected_character_state()
	var health_before_change: Dictionary = _capture_character_health_snapshot(selected_character_id)
	if selected_item["source"] == &"inventory":
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
	elif selected_item["source"] == &"market_offer":
		var market_offer: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
		if market_offer.is_empty():
			return false
		var gained_items: Array[Dictionary] = purchase_market_offer_package(market_offer.get("offer_id", &""))
		if gained_items.is_empty():
			return false
		var placed_instance: Dictionary = gained_items[0]
		placed_instance["rotation"] = int(selected_item["rotation"])
		state["placed_foods"].append({
			"instance_id": placed_instance["instance_id"],
			"definition_id": placed_instance["definition_id"],
			"rotation": int(selected_item["rotation"]),
			"anchor": anchor,
			"cells": placed_cells,
			"reroll_bonus_count": int(placed_instance.get("reroll_bonus_count", 0)),
		})
		_remove_inventory_item(placed_instance["instance_id"])
	elif selected_item["source"] == &"board_food":
		var moving_item: Dictionary = _find_placed_food(selected_character_id, selected_item.get("instance_id", &""))
		if moving_item.is_empty():
			return false
		for index in range(state["placed_foods"].size()):
			var placed_variant: Dictionary = state["placed_foods"][index]
			if placed_variant.get("instance_id", &"") != moving_item.get("instance_id", &""):
				continue
			placed_variant["rotation"] = int(selected_item["rotation"])
			placed_variant["anchor"] = anchor
			placed_variant["cells"] = placed_cells
			state["placed_foods"][index] = placed_variant
			_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
			state_changed.emit()
			clear_selection()
			return true
		return false
	elif selected_item["source"] == &"board_expansion":
		var moving_expansion: Dictionary = _find_placed_expansion(selected_character_id, selected_item.get("instance_id", &""))
		if moving_expansion.is_empty():
			return false
		for index in range(state["placed_expansions"].size()):
			var placed_variant: Dictionary = state["placed_expansions"][index]
			if placed_variant.get("instance_id", &"") != moving_expansion.get("instance_id", &""):
				continue
			placed_variant["rotation"] = int(selected_item["rotation"])
			placed_variant["anchor"] = anchor
			placed_variant["cells"] = placed_cells
			state["placed_expansions"][index] = placed_variant
			_rebuild_active_cells(state)
			_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
			state_changed.emit()
			clear_selection()
			return true
		return false
	elif selected_item["source"] == &"market_expansion":
		var expansion_offer: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
		if expansion_offer.is_empty():
			return false
		var gained_expansions: Array[Dictionary] = purchase_market_offer_package(expansion_offer.get("offer_id", &""))
		if gained_expansions.is_empty():
			return false
		var placed_expansion: Dictionary = gained_expansions[0]
		state["placed_expansions"].append({
			"instance_id": placed_expansion["instance_id"],
			"label": placed_expansion["label"],
			"shape_cells": _clone_cells(placed_expansion.get("shape_cells", [])),
			"rotation": int(selected_item["rotation"]),
			"anchor": anchor,
			"cells": placed_cells,
		})
		_remove_pending_expansion(selected_character_id, placed_expansion["instance_id"])
		_rebuild_active_cells(state)
	elif selected_item["source"] == &"pending_expansion" or selected_item["source"] == &"expansion":
		var pending_owner_id: StringName = selected_item.get("target_character_id", selected_character_id)
		var pending: Dictionary = _find_pending_expansion(pending_owner_id, selected_item["instance_id"])
		if pending.is_empty():
			return false
		state["placed_expansions"].append({
			"instance_id": pending["instance_id"],
			"label": pending["label"],
			"shape_cells": _clone_cells(pending.get("shape_cells", [])),
			"rotation": int(selected_item["rotation"]),
			"anchor": anchor,
			"cells": placed_cells,
		})
		_remove_pending_expansion(pending_owner_id, pending["instance_id"])
		_rebuild_active_cells(state)
	else:
		return false
	_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
	state_changed.emit()
	clear_selection()
	return true

func get_item_at_cell(cell: Vector2i) -> Dictionary:
	var state: Dictionary = get_selected_character_state()
	var key: String = "%d:%d" % [cell.x, cell.y]
	for item_variant in state.get("placed_foods", []):
		var item: Dictionary = item_variant
		if ShapeUtils.cells_to_lookup(item.get("cells", [])).has(key):
			return item
	return {}

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
	var health_before_change: Dictionary = _capture_character_health_snapshot(selected_character_id)
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
			_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
			state_changed.emit()
			return true
	for index in state["placed_expansions"].size():
		var item: Dictionary = state["placed_expansions"][index]
		if ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [cell.x, cell.y]):
			if _has_food_on_cells(selected_character_id, item["cells"]):
				return false
			var remaining_expansions: Array = []
			for other_index in range(state["placed_expansions"].size()):
				if other_index == index:
					continue
				remaining_expansions.append((state["placed_expansions"][other_index] as Dictionary).duplicate(true))
			if not _are_expansions_connected_to_base(state, remaining_expansions):
				return false
			state["pending_expansions"].append({
				"instance_id": item["instance_id"],
				"label": item["label"],
				"shape_cells": _clone_cells(item.get("shape_cells", _derive_shape_from_placed_cells(item["cells"], item["anchor"]))),
				"rotation": int(item.get("rotation", 0)),
				"target_character_id": selected_character_id,
			})
			state["placed_expansions"].remove_at(index)
			_rebuild_active_cells(state)
			_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
			state_changed.emit()
			return true
	return false

func move_placed_food(from_cell: Vector2i, to_anchor: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	var health_before_change: Dictionary = _capture_character_health_snapshot(selected_character_id)
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
		_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
		state_changed.emit()
		return true
	return false

func move_placed_expansion(from_cell: Vector2i, to_anchor: Vector2i) -> bool:
	var state: Dictionary = get_selected_character_state()
	var health_before_change: Dictionary = _capture_character_health_snapshot(selected_character_id)
	for index in range(state["placed_expansions"].size()):
		var item: Dictionary = state["placed_expansions"][index]
		if not ShapeUtils.cells_to_lookup(item["cells"]).has("%d:%d" % [from_cell.x, from_cell.y]):
			continue
		if _has_food_on_cells(selected_character_id, item["cells"]):
			return false
		var shape_cells: Array[Vector2i] = _clone_cells(item.get("shape_cells", []))
		if shape_cells.is_empty():
			return false
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
		var candidate_layout: Array = _build_candidate_expansion_layout(state, item.get("instance_id", &""), to_anchor, placed_cells, int(item.get("rotation", 0)))
		if not _are_expansions_connected_to_base(state, candidate_layout):
			return false
		item["anchor"] = to_anchor
		item["cells"] = placed_cells
		state["placed_expansions"][index] = item
		_rebuild_active_cells(state)
		_reconcile_character_health_after_board_change(selected_character_id, health_before_change)
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
		if definition == null:
			push_error("Missing food definition for selected inventory summary: %s" % String(item.get("definition_id", &"")))
			return "未知食物"
		return "放置食物: %s" % definition.display_name
	if selected_item["source"] == &"market_expansion":
		var market_expansion: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
		if market_expansion.is_empty():
			return "未找到拓展"
		return "市场拓展: %s" % str(market_expansion.get("label", ""))
	if selected_item["source"] == &"board_expansion":
		var board_expansion: Dictionary = _find_placed_expansion(selected_character_id, selected_item.get("instance_id", &""))
		if board_expansion.is_empty():
			return "未选择物品"
		return "已放置拓展: %s" % board_expansion.get("label", "")
	var expansion_owner_id: StringName = selected_item.get("target_character_id", selected_character_id)
	var expansion: Dictionary = _find_pending_expansion(expansion_owner_id, selected_item["instance_id"])
	if expansion.is_empty():
		return "未选择物品"
	return "待放置拓展: %s" % expansion["label"]

func get_inventory_display_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item in shared_inventory:
		var definition: FoodDefinition = get_food_definition(item["definition_id"])
		if definition == null:
			push_error("Missing food definition for inventory entry: %s" % String(item.get("definition_id", &"")))
			continue
		entries.append({
			"instance_id": item["instance_id"],
			"label": "%s [%s]" % [definition.display_name, definition.category],
			"definition_id": item["definition_id"],
		})
	return entries

func get_selected_item_summary_safe() -> String:
	if selected_item.is_empty():
		return "未选择物品"
	match selected_item.get("source", &""):
		&"inventory":
			var inventory_item: Dictionary = _find_inventory_item(selected_item.get("instance_id", &""))
			if inventory_item.is_empty():
				return "未选择物品"
			var inventory_definition: FoodDefinition = get_food_definition(inventory_item.get("definition_id", &""))
			return "食物: %s" % (inventory_definition.display_name if inventory_definition != null else "")
		&"market_offer":
			var market_offer: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
			if market_offer.is_empty():
				return "未选择物品"
			var market_definition: FoodDefinition = get_food_definition(market_offer.get("definition_id", &""))
			return "市场食物: %s" % (market_definition.display_name if market_definition != null else "")
		&"board_food":
			var placed_food: Dictionary = _find_placed_food(selected_character_id, selected_item.get("instance_id", &""))
			if placed_food.is_empty():
				return "未选择物品"
			var placed_definition: FoodDefinition = get_food_definition(placed_food.get("definition_id", &""))
			return "已放置食物: %s" % (placed_definition.display_name if placed_definition != null else "")
		&"board_expansion":
			var placed_expansion: Dictionary = _find_placed_expansion(selected_character_id, selected_item.get("instance_id", &""))
			if placed_expansion.is_empty():
				return "未选择物品"
			return "已放置拓展: %s" % str(placed_expansion.get("label", ""))
		&"pending_expansion", &"expansion":
			var pending_owner_id: StringName = selected_item.get("target_character_id", selected_character_id)
			var pending_expansion: Dictionary = _find_pending_expansion(pending_owner_id, selected_item.get("instance_id", &""))
			if pending_expansion.is_empty():
				return "未选择物品"
			return "待放置拓展: %s" % str(pending_expansion.get("label", ""))
		&"market_expansion":
			var offer_expansion: Dictionary = _find_market_offer(selected_item.get("offer_id", &""))
			if offer_expansion.is_empty():
				return "未选择物品"
			return "市场拓展: %s" % str(offer_expansion.get("label", ""))
		_:
			return "未选择物品"

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
				"reroll_bonus_count": 0,
			}
		grouped[key]["count"] = int(grouped[key]["count"]) + 1
		grouped[key]["reroll_bonus_count"] = max(
			int(grouped[key].get("reroll_bonus_count", 0)),
			int(item.get("reroll_bonus_count", 0))
		)
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
			if definition == null:
				push_error("Missing food definition for market offer: %s" % String(offer.get("definition_id", &"")))
				continue
			entries.append({
				"offer_id": offer["offer_id"],
				"label": "%s x%d [%s] - %d金币" % [definition.display_name, offer["quantity"], offer["rarity"], offer["price"]],
			})
		else:
			var names: Dictionary = get_character_display_names()
			entries.append({
				"offer_id": offer["offer_id"],
				"label": "%s 售给%s - %d金币" % [offer["label"], names.get(offer["target_character_id"], String(offer["target_character_id"])), offer["price"]],
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
				"discount_percent": int(round((1.0 - float(offer.get("discount", 1.0))) * 100.0)),
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
				"discount_percent": 0,
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
	var multipliers: Dictionary = get_current_monster_multipliers()
	var hp_multiplier: float = float(multipliers.get("hp", 1.0))
	var attack_multiplier: float = float(multipliers.get("attack", 1.0))
	return {
		"id": monster.id,
		"display_name": monster.display_name,
		"category": monster.category,
		"category_name": CATEGORY_DISPLAY_NAMES.get(monster.category, String(monster.category)),
		"hp": float(monster.base_hp) * hp_multiplier,
		"attack": float(monster.base_attack) * attack_multiplier,
		"attack_interval": monster.attack_interval,
		"skill_summary": monster.skill_summary,
		"hp_multiplier": hp_multiplier,
		"attack_multiplier": attack_multiplier,
	}

func get_synergy_summary(character_id: StringName) -> Dictionary:
	var actor: Dictionary = CombatEngine.preview_character_actor(self, character_id)
	var board_eval: Dictionary = actor.get("board_eval", {}) if not actor.is_empty() else {}
	var category_layers: Dictionary = board_eval.get("category_layers", {})
	var active_bonds: Dictionary = board_eval.get("active_category_bonds", {})
	var entries: Array[Dictionary] = []
	for category_id in CATEGORY_ORDER:
		var count: int = int(category_layers.get(category_id, 0))
		entries.append({
			"category_id": category_id,
			"category_name": CATEGORY_DISPLAY_NAMES.get(category_id, String(category_id)),
			"synergy_name": CATEGORY_SYNERGY_NAMES.get(category_id, ""),
			"effect_text": CATEGORY_SYNERGY_EFFECTS.get(category_id, ""),
			"count": count,
			"active": bool(active_bonds.get(category_id, false)),
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
			_request_battle_for_current_node()
			return true
		NODE_BATTLE, NODE_BOSS_BATTLE:
			_request_battle_for_current_node()
			return true
		_:
			return false

func advance_to_next_node() -> void:
	if current_route_index < stage_flow_config.route_nodes.size() - 1:
		current_route_index += 1
		_apply_route_arrival_state()
	state_changed.emit()

func _request_battle_for_current_node() -> void:
	match get_current_node_type():
		NODE_BATTLE, NODE_BOSS_BATTLE:
			battle_requested.emit()

func _apply_route_arrival_state() -> void:
	if get_current_node_type() == NODE_MARKET:
		current_market_index = min(current_market_index + 1, 4)
		current_reroll_count = 0
		_generate_market_offers()

func prepare_battle() -> void:
	pre_battle_snapshot = _capture_snapshot()
	if _autosave_enabled and _has_persistable_run:
		save_run()

func _capture_snapshot() -> Dictionary:
	var result: Dictionary = {
		"character_food_layouts": {},
	}
	for character_id in character_states.keys():
		var layouts: Array[Dictionary] = []
		for placed in character_states[character_id]["placed_foods"]:
			layouts.append({
				"instance_id": placed["instance_id"],
				"definition_id": placed["definition_id"],
				"anchor": placed["anchor"],
				"rotation": placed["rotation"],
				"cells": _clone_cells(placed["cells"]),
				"reroll_bonus_count": int(placed.get("reroll_bonus_count", 0)),
			})
		result["character_food_layouts"][character_id] = layouts
	return result

func apply_battle_report(report: Dictionary) -> void:
	if report.get("result", "") == "error":
		state_changed.emit()
		battle_finished.emit(report)
		return
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
	var defeated_monster: MonsterDefinition = _resolve_defeated_monster(report, battle_index)
	if battle_index >= 0 and battle_index < stage_flow_config.normal_battle_reward_gold.size():
		current_gold += stage_flow_config.normal_battle_reward_gold[battle_index]
	current_gold += int(report.get("bonus_gold", 0))
	if defeated_monster != null:
		grant_battle_drops(defeated_monster, battle_index)
	_apply_victory_character_recovery(report)
	for character_id in character_states.keys():
		character_states[character_id]["placed_foods"].clear()
	pre_battle_snapshot.clear()
	if current_route_index >= stage_flow_config.route_nodes.size() - 1:
		run_finished = true
	else:
		current_route_index += 1
		_apply_route_arrival_state()

func _resolve_defeated_monster(report: Dictionary, battle_index: int) -> MonsterDefinition:
	var monster_id: StringName = report.get("monster_id", &"")
	if monster_id != &"":
		var report_monster: MonsterDefinition = get_monster_definition(monster_id)
		if report_monster != null:
			return report_monster
	if battle_index >= 0 and battle_index < normal_monster_order.size():
		return get_monster_definition(normal_monster_order[battle_index])
	return get_current_monster_definition()

func _apply_victory_character_recovery(report: Dictionary) -> void:
	if not report.has("characters"):
		return
	for actor_variant in report["characters"]:
		var actor: Dictionary = actor_variant
		var character_id: StringName = actor.get("id", &"")
		if character_id == &"" or not character_states.has(character_id):
			continue
		var recovered_ratio: float = float(character_states[character_id].get("hp_ratio", 0.0))
		if bool(actor.get("alive", false)):
			recovered_ratio += 0.25
		else:
			recovered_ratio = 0.25
		character_states[character_id]["hp_ratio"] = clampf(recovered_ratio, 0.0, 1.0)

func grant_battle_drops(monster: MonsterDefinition, battle_index: int) -> void:
	if monster == null:
		return
	var target_value: int = 8
	if battle_index >= 0 and battle_index < stage_flow_config.normal_drop_value_curve.size():
		target_value = stage_flow_config.normal_drop_value_curve[battle_index]
	var candidates: Array[FoodDefinition] = get_battle_drop_candidates(monster)
	if candidates.is_empty():
		return
	var current_value: int = 0
	while current_value < target_value:
		var definition: FoodDefinition = candidates[_rng.randi_range(0, candidates.size() - 1)]
		shared_inventory.append(generate_item_instance(definition.id))
		current_value += definition.gold_value

func get_battle_drop_candidates(monster: MonsterDefinition) -> Array[FoodDefinition]:
	var candidates: Array[FoodDefinition] = []
	if monster == null or food_catalog == null:
		return candidates
	for definition in food_catalog.foods:
		if monster.category == &"boss" or definition.category == monster.category:
			candidates.append(definition)
	return candidates

func try_restore_snapshot() -> bool:
	if pre_battle_snapshot.is_empty():
		return false
	if not pre_battle_snapshot.has("character_food_layouts"):
		return false
	var snapshot_layouts: Dictionary = pre_battle_snapshot["character_food_layouts"]
	if snapshot_layouts.is_empty():
		return false
	var inventory_pool: Array[Dictionary] = shared_inventory.duplicate(true)
	for character_id in character_states.keys():
		for placed_variant in character_states[character_id].get("placed_foods", []):
			var placed: Dictionary = placed_variant
			inventory_pool.append({
				"instance_id": placed["instance_id"],
				"definition_id": placed["definition_id"],
				"rotation": int(placed.get("rotation", 0)),
				"reroll_bonus_count": int(placed.get("reroll_bonus_count", 0)),
			})
	var restored_layouts: Dictionary = {}
	for character_id in snapshot_layouts.keys():
		var character_layouts: Array[Dictionary] = []
		for layout in snapshot_layouts[character_id]:
			var found_index: int = -1
			for index in inventory_pool.size():
				if layout.has("instance_id") and inventory_pool[index]["instance_id"] == layout["instance_id"]:
					found_index = index
					break
				if not layout.has("instance_id") and inventory_pool[index]["definition_id"] == layout["definition_id"]:
					found_index = index
					break
			if found_index == -1:
				return false
			var item: Dictionary = inventory_pool[found_index]
			inventory_pool.remove_at(found_index)
			character_layouts.append({
				"instance_id": item["instance_id"],
				"definition_id": item["definition_id"],
				"rotation": int(layout["rotation"]),
				"anchor": layout["anchor"],
				"cells": _clone_cells(layout["cells"]),
				"reroll_bonus_count": int(item.get("reroll_bonus_count", 0)),
			})
		restored_layouts[character_id] = character_layouts
	for character_id in character_states.keys():
		character_states[character_id]["placed_foods"].clear()
	for character_id in restored_layouts.keys():
		character_states[character_id]["placed_foods"] = restored_layouts[character_id]
	shared_inventory = inventory_pool
	state_changed.emit()
	return true
