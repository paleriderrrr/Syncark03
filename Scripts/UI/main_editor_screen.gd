extends Control

@onready var gold_label: Label = %GoldLabel
@onready var route_label: Label = %RouteLabel
@onready var node_label: Label = %NodeLabel
@onready var risk_label: Label = %RiskLabel
@onready var selected_role_label: Label = %SelectedRoleLabel
@onready var selected_item_label: Label = %SelectedItemLabel
@onready var top_market_panel: Control = $TopMarketPanel
@onready var left_panel: Control = $LeftPanel
@onready var center_panel: Control = $CenterPanel
@onready var right_panel: Control = $RightPanel
@onready var bottom_inventory_panel: Control = $BottomInventoryPanel
@onready var board_view: BentoBoardView = %BentoBoardView
@onready var top_market_strip: ItemStrip = %TopMarketStrip
@onready var market_refresh_button: Button = %MarketRefreshButton
@onready var inventory_drop_zone: InventoryDropZone = %InventoryDropZone
@onready var inventory_strip: ItemStrip = %InventoryStrip
@onready var settings_button: Button = %SettingsButton
@onready var restore_button: Button = %RestoreButton
@onready var action_button: Button = %ActionButton
@onready var wanted_poster_rect: TextureRect = %WantedPosterRect
@onready var next_monster_name_label: Label = %NextMonsterNameLabel
@onready var next_monster_bounty_label: Label = %NextMonsterBountyLabel
@onready var next_monster_stage_label: Label = %NextMonsterStageLabel
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
var _market_panel_open_position := Vector2.ZERO
var _market_panel_closed_position := Vector2.ZERO
var _market_panel_is_open: bool = false
var _market_panel_tween: Tween
var _intro_tween: Tween
var _intro_animating: bool = false
var _last_node_type: StringName = &""
var _active_synergy_ids: Dictionary = {}

func _run_state() -> Node:
	return get_node("/root/RunState")

func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _ready() -> void:
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.01)
	_bgm_player().play_non_battle()
	_market_panel_open_position = top_market_panel.position
	_market_panel_closed_position = Vector2(_market_panel_open_position.x, -top_market_panel.size.y - 24.0)
	top_market_panel.position = _market_panel_closed_position
	top_market_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var run_state: Node = _run_state()
	run_state.ensure_initialized()
	_food_textures = FoodVisuals.build_food_texture_lookup()
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
	settings_button.pressed.connect(_on_settings_pressed)
	restore_button.pressed.connect(_on_restore_pressed)
	action_button.pressed.connect(_on_action_pressed)
	tab_buttons[&"warrior"].pressed.connect(func() -> void: _on_role_tab_pressed(&"warrior"))
	tab_buttons[&"hunter"].pressed.connect(func() -> void: _on_role_tab_pressed(&"hunter"))
	tab_buttons[&"mage"].pressed.connect(func() -> void: _on_role_tab_pressed(&"mage"))
	board_view.set_food_textures(_food_textures)
	wanted_poster_rect.mouse_entered.connect(_on_monster_hover_entered)
	wanted_poster_rect.mouse_exited.connect(_on_monster_hover_exited)
	monster_tooltip_panel.visible = false
	_refresh()
	_play_intro_animation()

func _refresh() -> void:
	var run_state: Node = _run_state()
	var current_node_type: StringName = run_state.get_current_node_type()
	if current_node_type == run_state.NODE_MARKET and _last_node_type != run_state.NODE_MARKET:
		_ui_sfx().play_shop_open()
	_last_node_type = current_node_type
	_role_names = run_state.get_character_display_names()
	_update_market_panel_state(run_state.get_current_node_type() == run_state.NODE_MARKET)
	gold_label.text = "Gold: %d" % run_state.current_gold
	route_label.text = _build_route_label(run_state)
	node_label.text = "Current Node: %s" % _display_name_for_node(current_node_type)
	risk_label.text = "Risk: %s" % _estimate_risk_label()
	selected_item_label.text = run_state.get_selected_item_summary()
	action_button.text = run_state.get_action_button_text()
	market_refresh_button.disabled = current_node_type != run_state.NODE_MARKET
	market_refresh_button.text = "Refresh (%dG)" % run_state.get_current_refresh_cost()
	restore_button.disabled = current_node_type != run_state.NODE_REST
	_refresh_selected_role(run_state.selected_character_id)
	_refresh_market_strip()
	_refresh_inventory_strip()
	_refresh_board()
	_refresh_next_monster_panel()
	_refresh_synergy_panel()

func _update_market_panel_state(should_open: bool) -> void:
	if _intro_animating:
		_market_panel_is_open = should_open
		top_market_panel.position = _market_panel_open_position if should_open else _market_panel_closed_position
		top_market_panel.mouse_filter = Control.MOUSE_FILTER_PASS if should_open else Control.MOUSE_FILTER_IGNORE
		return
	if _market_panel_is_open == should_open and _market_panel_tween == null:
		return
	_market_panel_is_open = should_open
	if is_instance_valid(_market_panel_tween):
		_market_panel_tween.kill()
	var target_position: Vector2 = _market_panel_open_position if should_open else _market_panel_closed_position
	top_market_panel.mouse_filter = Control.MOUSE_FILTER_PASS if should_open else Control.MOUSE_FILTER_IGNORE
	_market_panel_tween = create_tween()
	_market_panel_tween.set_trans(Tween.TRANS_CUBIC)
	_market_panel_tween.set_ease(Tween.EASE_OUT)
	_market_panel_tween.tween_property(top_market_panel, "position", target_position, 0.28)
	_market_panel_tween.finished.connect(func() -> void:
		_market_panel_tween = null
	)

func _play_intro_animation() -> void:
	if is_instance_valid(_intro_tween):
		_intro_tween.kill()
	_intro_animating = true
	if is_instance_valid(_market_panel_tween):
		_market_panel_tween.kill()
		_market_panel_tween = null
	var run_state: Node = _run_state()
	var market_should_open: bool = run_state.get_current_node_type() == run_state.NODE_MARKET
	var market_target_position: Vector2 = _market_panel_open_position if market_should_open else _market_panel_closed_position
	var panel_entries: Array[Dictionary] = [
		{
			"node": top_market_panel,
			"target": market_target_position,
			"start": market_target_position + Vector2(0.0, -180.0),
		},
		{
			"node": left_panel,
			"target": left_panel.position,
			"start": left_panel.position + Vector2(-220.0, 0.0),
		},
		{
			"node": center_panel,
			"target": center_panel.position,
			"start": center_panel.position + Vector2(0.0, 90.0),
		},
		{
			"node": right_panel,
			"target": right_panel.position,
			"start": right_panel.position + Vector2(220.0, 0.0),
		},
		{
			"node": bottom_inventory_panel,
			"target": bottom_inventory_panel.position,
			"start": bottom_inventory_panel.position + Vector2(0.0, 180.0),
		},
		{
			"node": settings_button,
			"target": settings_button.position,
			"start": settings_button.position + Vector2(-120.0, 120.0),
		},
	]
	for entry_variant in panel_entries:
		var entry: Dictionary = entry_variant
		var panel: Control = entry["node"]
		panel.position = entry["start"]
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	var step_delay := 0.05
	var duration := 0.46
	for index in range(panel_entries.size()):
		var entry: Dictionary = panel_entries[index]
		var panel: Control = entry["node"]
		var target_position: Vector2 = entry["target"]
		var move_track: PropertyTweener = _intro_tween.tween_property(panel, "position", target_position, duration)
		move_track.set_delay(index * step_delay)
		move_track.set_trans(Tween.TRANS_CUBIC)
		move_track.set_ease(Tween.EASE_OUT)
		var fade_track: PropertyTweener = _intro_tween.tween_property(panel, "modulate:a", 1.0, duration * 0.85)
		fade_track.set_delay(index * step_delay)
		fade_track.set_trans(Tween.TRANS_SINE)
		fade_track.set_ease(Tween.EASE_OUT)
	_intro_tween.finished.connect(func() -> void:
		_market_panel_is_open = market_should_open
		top_market_panel.position = market_target_position
		top_market_panel.mouse_filter = Control.MOUSE_FILTER_PASS if market_should_open else Control.MOUSE_FILTER_IGNORE
		_intro_animating = false
		_intro_tween = null
	)

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
		tab_buttons[role_id].text = ""

func _refresh_market_strip() -> void:
	var run_state: Node = _run_state()
	var entries: Array[Dictionary] = []
	for entry_variant in run_state.get_market_package_entries():
		var entry: Dictionary = entry_variant.duplicate(true)
		if entry.get("kind", &"") == &"food":
			var definition: FoodDefinition = run_state.get_food_definition(entry["definition_id"])
			_apply_food_tooltip(entry, definition)
			entry["drag_payload"] = {
				"source": &"market_offer",
				"offer_id": entry["offer_id"],
				"definition_id": entry["definition_id"],
				"shape_cells": definition.shape_cells,
				"rotation": 0,
			}
		elif entry.get("kind", &"") == &"expansion":
			_apply_expansion_tooltip(entry)
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
			_apply_expansion_tooltip(entry)
			entry["drag_payload"] = {
				"source": &"pending_expansion",
				"instance_id": entry["instance_id"],
				"target_character_id": entry["target_character_id"],
				"shape_cells": entry.get("shape_cells", []),
				"rotation": int(entry.get("rotation", 0)),
			}
		else:
			var definition: FoodDefinition = run_state.get_food_definition(entry["definition_id"])
			_apply_food_tooltip(entry, definition)
			entry["drag_payload"] = {
				"source": &"inventory",
				"group_key": entry["group_key"],
				"definition_id": entry["definition_id"],
				"shape_cells": definition.shape_cells,
				"rotation": 0,
			}
		entries.append(entry)
	inventory_strip.set_entries(entries, _food_textures)

func _apply_food_tooltip(entry: Dictionary, definition: FoodDefinition) -> void:
	if definition == null:
		return
	entry["tooltip_name"] = definition.display_name
	entry["tooltip_base_bonus"] = _build_food_bonus_text(definition)
	entry["tooltip_special_effect"] = definition.passive_text.strip_edges()
	entry["tooltip_shape_cells"] = definition.shape_cells.duplicate()

func _apply_expansion_tooltip(entry: Dictionary) -> void:
	entry["tooltip_name"] = String(entry.get("display_name", "拓展"))
	entry["tooltip_base_bonus"] = "拓展当前角色的可放置区域"
	entry["tooltip_special_effect"] = "拖拽到棋盘上，为对应角色增加新的格子。"
	entry["tooltip_shape_cells"] = entry.get("shape_cells", []).duplicate()

func _build_food_bonus_text(definition: FoodDefinition) -> String:
	var parts: PackedStringArray = []
	if definition.hp_bonus != 0:
		parts.append("生命 %s" % _format_signed_value(float(definition.hp_bonus), 0))
	if not is_zero_approx(definition.attack_bonus):
		parts.append("攻击 %s" % _format_signed_value(definition.attack_bonus))
	if not is_zero_approx(definition.bonus_damage):
		parts.append("附加伤害 %s" % _format_signed_value(definition.bonus_damage))
	if not is_zero_approx(definition.attack_speed_percent):
		parts.append("攻速 %s%%" % _format_signed_value(definition.attack_speed_percent))
	if not is_zero_approx(definition.heal_per_second):
		parts.append("每秒回复 %s" % _format_signed_value(definition.heal_per_second))
	if not is_zero_approx(definition.execute_threshold_percent):
		parts.append("斩杀线 %s%%" % _format_signed_value(definition.execute_threshold_percent))
	if parts.is_empty():
		return "无基础加成"
	return "，".join(parts)

func _format_signed_value(value: float, decimals: int = 1) -> String:
	var abs_value: float = absf(value)
	var text := ""
	if decimals <= 0 or is_zero_approx(abs_value - round(abs_value)):
		text = str(int(round(abs_value)))
	else:
		text = str(snapped(abs_value, 0.1))
		if text.contains("."):
			while text.ends_with("0"):
				text = text.left(text.length() - 1)
			if text.ends_with("."):
				text = text.left(text.length() - 1)
	return ("+" if value >= 0.0 else "-") + text

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
		next_monster_bounty_label.text = "Bounty: -"
		next_monster_stage_label.text = "Stage: -"
		next_monster_stats_label.text = "-"
		next_monster_skill_label.text = "-"
		monster_tooltip_panel.visible = false
		return
	next_monster_name_label.text = "%s / %s" % [String(summary.get("display_name", "")), String(summary.get("category_name", ""))]
	next_monster_bounty_label.text = "Bounty: %d G" % _get_next_battle_reward()
	next_monster_stage_label.text = "Stage: %d / %d" % [_run_state().current_route_index + 1, _get_total_stage_count()]
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

func _get_total_stage_count() -> int:
	var run_state: Node = _run_state()
	if run_state.stage_flow_config == null:
		return 0
	return run_state.stage_flow_config.route_nodes.size()

func _get_next_battle_reward() -> int:
	var run_state: Node = _run_state()
	if run_state.stage_flow_config == null:
		return 0
	var battle_index: int = run_state.get_completed_battle_count()
	if battle_index < 0 or battle_index >= run_state.stage_flow_config.normal_battle_reward_gold.size():
		return 0
	return run_state.stage_flow_config.normal_battle_reward_gold[battle_index]

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
	var new_active_ids: Dictionary = {}
	for entry_variant in summary.get("entries", []):
		var entry: Dictionary = entry_variant
		if bool(entry.get("active", false)):
			new_active_ids[entry.get("category_id", &"")] = true
	for category_id in new_active_ids.keys():
		if not _active_synergy_ids.has(category_id):
			_ui_sfx().play_synergy_cue()
			break
	_active_synergy_ids = new_active_ids
	synergy_panel.set_summary(summary, role_name)

func _on_selected_character_changed(character_id: StringName) -> void:
	_refresh_selected_role(character_id)
	_refresh()

func _on_market_entry_clicked(entry: Dictionary) -> void:
	if entry.get("kind", &"") == &"expansion":
		var gained: Array[Dictionary] = _run_state().purchase_market_offer_package(entry.get("offer_id", &""))
		if gained.is_empty():
			_ui_sfx().play_purchase_denied()
		else:
			_ui_sfx().play_purchase_success()

func _on_inventory_entry_clicked(entry: Dictionary) -> void:
	if entry.get("entry_kind", &"food") == &"expansion":
		_run_state().select_pending_expansion(entry.get("instance_id", &""))
	else:
		_run_state().pick_inventory_instance(entry.get("group_key", &""))

func _on_board_cell_clicked(cell: Vector2i) -> void:
	var run_state: Node = _run_state()
	if not run_state.selected_item.is_empty():
		if run_state.try_place_selected_item(cell):
			_ui_sfx().play_place()

func _on_board_cell_right_clicked(cell: Vector2i) -> void:
	if _run_state().remove_item_at_cell(cell):
		_ui_sfx().play_place()

func _on_board_drop_requested(anchor_cell: Vector2i, drag_data: Dictionary) -> void:
	var run_state: Node = _run_state()
	match drag_data.get("source", &""):
		&"market_offer":
			var gained_items: Array[Dictionary] = run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
			if gained_items.is_empty():
				_ui_sfx().play_purchase_denied()
			elif drag_data.has("definition_id"):
				var first_instance: Dictionary = gained_items[0]
				run_state.select_inventory_item(first_instance["instance_id"])
				if run_state.try_place_selected_item(anchor_cell):
					_ui_sfx().play_place()
				else:
					_ui_sfx().play_purchase_success()
					run_state.clear_selection()
			else:
				_ui_sfx().play_purchase_success()
		&"inventory":
			var picked_item: Dictionary = run_state.pick_inventory_instance(drag_data.get("group_key", &""))
			if not picked_item.is_empty():
				if run_state.try_place_selected_item(anchor_cell):
					_ui_sfx().play_place()
				else:
					run_state.clear_selection()
		&"pending_expansion":
			run_state.select_pending_expansion(drag_data.get("instance_id", &""))
			if run_state.try_place_selected_item(anchor_cell):
				_ui_sfx().play_place()
			else:
				run_state.clear_selection()
		&"board_food":
			if run_state.move_placed_food(drag_data.get("from_cell", Vector2i.ZERO), anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)):
				_ui_sfx().play_place()
		&"board_expansion":
			if run_state.move_placed_expansion(drag_data.get("from_cell", Vector2i.ZERO), anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)):
				_ui_sfx().play_place()
		&"board_base":
			var adjusted_anchor: Vector2i = anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)
			if run_state.move_base_board(adjusted_anchor):
				_ui_sfx().play_place()
	_refresh()

func _on_inventory_strip_drop_requested(drag_data: Dictionary) -> void:
	var run_state: Node = _run_state()
	match drag_data.get("source", &""):
		&"market_offer":
			var gained_items: Array[Dictionary] = run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
			if gained_items.is_empty():
				_ui_sfx().play_purchase_denied()
			else:
				_ui_sfx().play_purchase_success()
		&"market_expansion":
			var gained_expansions: Array[Dictionary] = run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
			if gained_expansions.is_empty():
				_ui_sfx().play_purchase_denied()
			else:
				_ui_sfx().play_purchase_success()
		&"board_food":
			if run_state.store_placed_food(drag_data.get("from_cell", Vector2i.ZERO)):
				_ui_sfx().play_place()
	_refresh()

func _on_restore_pressed() -> void:
	_ui_sfx().play_button()
	_run_state().try_restore_snapshot()

func _on_settings_pressed() -> void:
	_ui_sfx().play_button()
	get_tree().change_scene_to_file("res://Scenes/settings_screen.tscn")

func _on_action_pressed() -> void:
	_ui_sfx().play_button()
	_run_state().perform_primary_action()

func _on_market_refresh_pressed() -> void:
	if _run_state().refresh_market_offers():
		_ui_sfx().play_button()
	else:
		_ui_sfx().play_purchase_denied()

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

func _on_role_tab_pressed(character_id: StringName) -> void:
	_ui_sfx().play_button()
	_run_state().select_character(character_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_run_state().rotate_selected_item()
		get_viewport().set_input_as_handled()
