extends Control

@onready var gold_label: Label = %GoldLabel
@onready var route_label: Label = %RouteLabel
@onready var node_label: Label = %NodeLabel
@onready var risk_label: Label = %RiskLabel
@onready var selected_role_label: Label = %SelectedRoleLabel
@onready var selected_item_label: Label = %SelectedItemLabel
@onready var board_view: BentoBoardView = %BentoBoardView
@onready var top_market_strip: ItemStrip = %TopMarketStrip
@onready var market_refresh_button: Button = %MarketRefreshButton
@onready var inventory_drop_zone: InventoryDropZone = %InventoryDropZone
@onready var inventory_strip: ItemStrip = %InventoryStrip
@onready var restore_button: Button = %RestoreButton
@onready var action_button: Button = %ActionButton
@onready var wanted_poster_rect: TextureRect = %WantedPosterRect
@onready var next_monster_name_label: Label = %NextMonsterNameLabel
@onready var next_monster_stats_label: Label = %NextMonsterStatsLabel
@onready var next_monster_skill_label: Label = %NextMonsterSkillLabel
@onready var monster_tooltip_panel: PanelContainer = %MonsterTooltipPanel
@onready var synergy_panel: Control = %SynergyPanel
@onready var battle_popup: BattlePopup = %BattlePopup

@onready var tab_buttons: Dictionary = {
	&"warrior": %WarriorTabButton,
	&"hunter": %HunterTabButton,
	&"mage": %MageTabButton,
}

var _food_textures: Dictionary = {}
var _role_names: Dictionary = {}

func _run_state() -> Node:
	return get_node("/root/RunState")

func _ready() -> void:
	var run_state: Node = _run_state()
	run_state.ensure_initialized()
	_food_textures = FoodVisuals.build_food_texture_lookup(run_state.food_catalog)
	_role_names = run_state.get_character_display_names()
	run_state.state_changed.connect(_refresh)
	run_state.selected_character_changed.connect(_on_selected_character_changed)
	run_state.selected_item_changed.connect(_refresh)
	run_state.battle_requested.connect(_on_battle_requested)
	board_view.cell_clicked.connect(_on_board_cell_clicked)
	board_view.cell_right_clicked.connect(_on_board_cell_right_clicked)
	board_view.board_drop_requested.connect(_on_board_drop_requested)
	top_market_strip.entry_clicked.connect(_on_market_entry_clicked)
	market_refresh_button.pressed.connect(_on_market_refresh_pressed)
	inventory_strip.entry_clicked.connect(_on_inventory_entry_clicked)
	inventory_drop_zone.drop_received.connect(_on_inventory_strip_drop_requested)
	inventory_drop_zone.accepted_sources = [&"market_offer", &"board_food", &"market_expansion"]
	inventory_strip.card_drop_sources = [&"market_offer", &"board_food", &"market_expansion"]
	inventory_strip.card_drop_target = inventory_drop_zone
	restore_button.pressed.connect(_on_restore_pressed)
	action_button.pressed.connect(_on_action_pressed)
	tab_buttons[&"warrior"].pressed.connect(func() -> void: _run_state().select_character(&"warrior"))
	tab_buttons[&"hunter"].pressed.connect(func() -> void: _run_state().select_character(&"hunter"))
	tab_buttons[&"mage"].pressed.connect(func() -> void: _run_state().select_character(&"mage"))
	board_view.set_food_textures(_food_textures)
	wanted_poster_rect.mouse_entered.connect(_on_monster_hover_entered)
	wanted_poster_rect.mouse_exited.connect(_on_monster_hover_exited)
	monster_tooltip_panel.visible = false
	_refresh()

func _refresh() -> void:
	var run_state: Node = _run_state()
	_role_names = run_state.get_character_display_names()
	gold_label.text = "Gold: %d" % run_state.current_gold
	route_label.text = _build_route_label(run_state)
	node_label.text = "Current Node: %s" % _display_name_for_node(run_state.get_current_node_type())
	risk_label.text = "Risk: %s" % _estimate_risk_label()
	selected_item_label.text = run_state.get_selected_item_summary()
	action_button.text = run_state.get_action_button_text()
	market_refresh_button.disabled = run_state.get_current_node_type() != run_state.NODE_MARKET
	restore_button.disabled = run_state.get_current_node_type() != run_state.NODE_REST
	_refresh_selected_role(run_state.selected_character_id)
	_refresh_market_strip()
	_refresh_inventory_strip()
	_refresh_board()
	_refresh_next_monster_panel()
	_refresh_synergy_panel()

func _refresh_selected_role(character_id: StringName) -> void:
	var run_state: Node = _run_state()
	var health: Dictionary = run_state.get_character_health_display(character_id)
	selected_role_label.text = "Current Role: %s  HP %d/%d" % [
		String(_role_names.get(character_id, String(character_id))),
		int(health.get("current_hp", 0)),
		int(health.get("max_hp", 0)),
	]
	for role_id in tab_buttons.keys():
		tab_buttons[role_id].disabled = role_id == character_id
		var role_health: Dictionary = run_state.get_character_health_display(role_id)
		tab_buttons[role_id].text = "%s\nHP %d/%d" % [
			String(_role_names.get(role_id, String(role_id))),
			int(role_health.get("current_hp", 0)),
			int(role_health.get("max_hp", 0)),
		]

func _refresh_market_strip() -> void:
	var run_state: Node = _run_state()
	var entries: Array[Dictionary] = []
	for entry_variant in run_state.get_market_package_entries():
		var entry: Dictionary = entry_variant.duplicate(true)
		if entry.get("kind", &"") == &"food":
			var definition: FoodDefinition = run_state.get_food_definition(entry["definition_id"])
			entry["drag_payload"] = {
				"source": &"market_offer",
				"offer_id": entry["offer_id"],
				"definition_id": entry["definition_id"],
				"shape_cells": definition.shape_cells,
				"rotation": 0,
			}
		elif entry.get("kind", &"") == &"expansion":
			entry["drag_payload"] = {
				"source": &"market_expansion",
				"offer_id": entry["offer_id"],
				"target_character_id": entry["target_character_id"],
				"shape_cells": entry.get("shape_cells", []),
				"rotation": 0,
			}
		else:
			entry["drag_payload"] = {}
		entries.append(entry)
	top_market_strip.set_entries(entries, _food_textures)

func _refresh_inventory_strip() -> void:
	var run_state: Node = _run_state()
	var entries: Array[Dictionary] = []
	for entry_variant in run_state.get_grouped_inventory_entries():
		var entry: Dictionary = entry_variant.duplicate(true)
		if entry.get("entry_kind", &"food") == &"expansion":
			entry["drag_payload"] = {
				"source": &"pending_expansion",
				"instance_id": entry["instance_id"],
				"target_character_id": entry["target_character_id"],
				"shape_cells": entry.get("shape_cells", []),
				"rotation": int(entry.get("rotation", 0)),
			}
		else:
			var definition: FoodDefinition = run_state.get_food_definition(entry["definition_id"])
			entry["drag_payload"] = {
				"source": &"inventory",
				"group_key": entry["group_key"],
				"definition_id": entry["definition_id"],
				"shape_cells": definition.shape_cells,
				"rotation": 0,
			}
		entries.append(entry)
	inventory_strip.set_entries(entries, _food_textures)

func _refresh_board() -> void:
	var run_state: Node = _run_state()
	var preview_cells: Array[Vector2i] = []
	if not run_state.selected_item.is_empty():
		preview_cells = run_state.get_selected_item_cells()
	board_view.refresh_board(run_state.get_selected_character_state(), preview_cells, run_state.food_lookup, _food_textures)

func _refresh_next_monster_panel() -> void:
	var summary: Dictionary = _run_state().get_next_monster_summary()
	if summary.is_empty():
		next_monster_name_label.text = "Unknown"
		next_monster_stats_label.text = "-"
		next_monster_skill_label.text = "-"
		monster_tooltip_panel.visible = false
		return
	next_monster_name_label.text = "%s / %s" % [String(summary.get("display_name", "")), String(summary.get("category_name", ""))]
	next_monster_stats_label.text = "HP %d  ATK %.1f  Interval %.1fs" % [
		int(summary.get("hp", 0)),
		float(summary.get("attack", 0.0)),
		float(summary.get("attack_interval", 0.0)),
	]
	next_monster_skill_label.text = String(summary.get("skill_summary", ""))
	monster_tooltip_panel.visible = false

func _build_route_label(run_state: Node) -> String:
	var total_nodes: int = 0
	if run_state.stage_flow_config != null:
		total_nodes = run_state.stage_flow_config.route_nodes.size()
	return "NODE %d / %d: %s" % [
		int(run_state.current_route_index) + 1,
		total_nodes,
		_display_name_for_node(run_state.get_current_node_type()),
	]

func _display_name_for_node(node_type: StringName) -> String:
	match node_type:
		&"market":
			return "Market"
		&"battle":
			return "Battle"
		&"rest":
			return "Rest"
		&"boss_battle":
			return "Boss Battle"
		_:
			return String(node_type)

func _refresh_synergy_panel() -> void:
	var run_state: Node = _run_state()
	var summary: Dictionary = run_state.get_synergy_summary(run_state.selected_character_id)
	var role_name: String = String(_role_names.get(run_state.selected_character_id, String(run_state.selected_character_id)))
	synergy_panel.set_summary(summary, role_name)

func _on_selected_character_changed(character_id: StringName) -> void:
	_refresh_selected_role(character_id)
	_refresh()

func _on_market_entry_clicked(entry: Dictionary) -> void:
	if entry.get("kind", &"") == &"expansion":
		_run_state().purchase_market_offer_package(entry.get("offer_id", &""))

func _on_inventory_entry_clicked(entry: Dictionary) -> void:
	if entry.get("entry_kind", &"food") == &"expansion":
		_run_state().select_pending_expansion(entry.get("instance_id", &""))
	else:
		_run_state().pick_inventory_instance(entry.get("group_key", &""))

func _on_board_cell_clicked(cell: Vector2i) -> void:
	var run_state: Node = _run_state()
	if not run_state.selected_item.is_empty():
		run_state.try_place_selected_item(cell)

func _on_board_cell_right_clicked(cell: Vector2i) -> void:
	_run_state().remove_item_at_cell(cell)

func _on_board_drop_requested(anchor_cell: Vector2i, drag_data: Dictionary) -> void:
	var run_state: Node = _run_state()
	match drag_data.get("source", &""):
		&"market_offer":
			var gained_items: Array[Dictionary] = run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
			if not gained_items.is_empty() and drag_data.has("definition_id"):
				var first_instance: Dictionary = gained_items[0]
				run_state.select_inventory_item(first_instance["instance_id"])
				if not run_state.try_place_selected_item(anchor_cell):
					run_state.clear_selection()
		&"inventory":
			var picked_item: Dictionary = run_state.pick_inventory_instance(drag_data.get("group_key", &""))
			if not picked_item.is_empty():
				if not run_state.try_place_selected_item(anchor_cell):
					run_state.clear_selection()
		&"pending_expansion":
			run_state.select_pending_expansion(drag_data.get("instance_id", &""))
			if not run_state.try_place_selected_item(anchor_cell):
				run_state.clear_selection()
		&"board_food":
			run_state.move_placed_food(drag_data.get("from_cell", Vector2i.ZERO), anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO))
		&"board_expansion":
			run_state.move_placed_expansion(drag_data.get("from_cell", Vector2i.ZERO), anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO))
		&"board_base":
			var adjusted_anchor: Vector2i = anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)
			run_state.move_base_board(adjusted_anchor)
	_refresh()

func _on_inventory_strip_drop_requested(drag_data: Dictionary) -> void:
	var run_state: Node = _run_state()
	match drag_data.get("source", &""):
		&"market_offer":
			run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
		&"market_expansion":
			run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
		&"board_food":
			run_state.store_placed_food(drag_data.get("from_cell", Vector2i.ZERO))
	_refresh()

func _on_restore_pressed() -> void:
	_run_state().try_restore_snapshot()

func _on_action_pressed() -> void:
	_run_state().perform_primary_action()

func _on_market_refresh_pressed() -> void:
	_run_state().refresh_market_offers()

func _on_battle_requested() -> void:
	battle_popup.open_battle()

func _on_monster_hover_entered() -> void:
	if next_monster_stats_label.text == "-" and next_monster_skill_label.text == "-":
		return
	monster_tooltip_panel.visible = true

func _on_monster_hover_exited() -> void:
	monster_tooltip_panel.visible = false

func _estimate_risk_label() -> String:
	var total_power: float = 0.0
	var run_state: Node = _run_state()
	for character_id in run_state.character_states.keys():
		var state: Dictionary = run_state.character_states[character_id]
		var base_attack: float = 0.0
		var base_hp: float = 0.0
		for definition in run_state.character_roster.characters:
			if definition.id == character_id:
				base_attack = definition.base_attack
				base_hp = definition.base_hp
				break
		total_power += base_attack + base_hp / 8.0
		for placed_variant in state["placed_foods"]:
			var placed: Dictionary = placed_variant
			var food: FoodDefinition = run_state.get_food_definition(placed["definition_id"])
			total_power += food.attack_bonus * 1.5
			total_power += food.hp_bonus / 8.0
			total_power += food.bonus_damage
			total_power += food.attack_speed_percent / 10.0
	var monster: MonsterDefinition = run_state.get_current_monster_definition()
	if monster == null:
		return "Unknown"
	var monster_power: float = monster.base_attack * 2.0 + monster.base_hp / 6.0
	var ratio: float = total_power / maxf(monster_power, 1.0)
	if ratio >= 1.8:
		return "Crush"
	if ratio >= 1.2:
		return "Stable"
	if ratio >= 0.85:
		return "Close"
	if ratio >= 0.6:
		return "Risky"
	return "Fatal"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_run_state().rotate_selected_item()
		get_viewport().set_input_as_handled()
