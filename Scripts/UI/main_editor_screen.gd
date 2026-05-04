extends Control

## Keep UI literals ASCII-only in this file via Unicode escapes.
## That avoids accidental recoding issues when editing around legacy-encoded assets/scenes.
const ACTION_BUTTON_TEXT_TEXTURES := {
	&"depart": preload("res://Art/UI/NewUI/UI1-3_slices/ui13_formal_depart_text.png"),
	&"continue": preload("res://Art/UI/NewUI/UI1-3_slices/ui13_formal_continue_text.png"),
	&"restart": preload("res://Art/UI/NewUI/UI1-3_slices/ui13_formal_restart_text.png"),
}
const ITEM_TOOLTIP_OVERLAY_SCENE := preload("res://Scenes/Components/immediate_item_tooltip_overlay.tscn")
const SYNERGY_TOOLTIP_OVERLAY_SCENE := preload("res://Scenes/Components/immediate_synergy_tooltip_overlay.tscn")
const DEFAULT_WANTED_POSTER_TEXTURE := preload("res://Art/UI/NewUI/ui1_2_wanted_poster.png")
const WANTED_POSTER_TEXTURES := {
	&"fruit_tree_king": preload("res://Art/Wanted/tree.png"),
	&"cream_overlord": preload("res://Art/Wanted/cream.png"),
	&"charging_beast": preload("res://Art/Wanted/cowdragon.png"),
	&"water_giant": preload("res://Art/Wanted/water.png"),
	&"bread_knight": preload("res://Art/Wanted/bread.png"),
	&"spice_wizard": preload("res://Art/Wanted/mushroom.png"),
}
const TEXT_GOLD := "\u91d1\u5e01\uff1a%d"
const TEXT_MARKET_REFRESH := "\u5237\u65b0\uff08%d\u91d1\uff09"
const TEXT_SELECTED_ROLE := "\u5f53\u524d\u89d2\u8272\uff1a%s  \u751f\u547d %d/%d"
const TEXT_EXPANSION_DEFAULT := "\u62d3\u5c55\u5757"
const TEXT_EXPANSION_TOOLTIP_BONUS := "\u6269\u5c55\u5f53\u524d\u89d2\u8272\u7684\u53ef\u653e\u7f6e\u533a\u57df"
const TEXT_EXPANSION_TOOLTIP_EFFECT := "\u62d6\u62fd\u5230\u68cb\u76d8\u4e0a\uff0c\u4e3a\u5bf9\u5e94\u89d2\u8272\u589e\u52a0\u65b0\u7684\u683c\u5b50\u3002"
const TEXT_BONUS_HP := "\u751f\u547d %s"
const TEXT_BONUS_ATTACK := "\u653b\u51fb %s"
const TEXT_BONUS_DAMAGE := "\u9644\u52a0\u4f24\u5bb3 %s"
const TEXT_BONUS_SPEED := "\u653b\u901f %s%%"
const TEXT_BONUS_HPS := "\u6bcf\u79d2\u56de\u590d %s"
const TEXT_BONUS_EXECUTE := "\u65a9\u6740\u7ebf %s%%"
const TEXT_BONUS_NONE := "\u65e0\u57fa\u7840\u52a0\u6210"
const TEXT_BONUS_SEPARATOR := "\uff0c"
const FOOD_RARITY_DISPLAY_NAMES := {
	&"common": "\u666e\u901a",
	&"rare": "\u7a00\u6709",
	&"epic": "\u53f2\u8bd7",
}
const TEXT_TOOLTIP_NONE := "\u65e0"
const TEXT_TOOLTIP_PRICE := "%d G"
const TEXT_TOOLTIP_SHAPE_SUMMARY := "\u5171%d\u683c\uff08%dx%d\uff09"
const GUIDE_TEXTURES: Array[Texture2D] = [
	preload("res://Art/UI/tutor1.png"),
	preload("res://Art/UI/tutor2.png"),
]
const TEXT_UNKNOWN := "\u672a\u77e5"
const TEXT_BOUNTY_EMPTY := "\u8d4f\u91d1\uff1a-"
const TEXT_STAGE_EMPTY := "\u9636\u6bb5\uff1a-"
const TEXT_BOUNTY := "\u8d4f\u91d1\uff1a%d\u91d1"
const TEXT_STAGE := "\u9636\u6bb5\uff1a%d / %d"
const TEXT_MONSTER_STATS := "\u751f\u547d %d  \u653b\u51fb %.1f  \u95f4\u9694 %.1f\u79d2"
const TEXT_ROUTE := "\u8282\u70b9 %d / %d\uff1a%s"
const TEXT_CURRENT_NODE := "\u5f53\u524d\u8282\u70b9\uff1a%s"
const TEXT_RISK := "\u5371\u9669\u5ea6\uff1a%s"
const TEXT_NODE_MARKET := "\u5e02\u573a"
const TEXT_NODE_BATTLE := "\u6218\u6597"
const TEXT_NODE_REST := "\u4f11\u6574"
const TEXT_NODE_BOSS := "Boss\u6218"
const TEXT_RISK_UNKNOWN := "\u672a\u77e5"
const TEXT_RISK_OVERWHELM := "\u6e38\u5203\u6709\u4f59"
const TEXT_RISK_STABLE := "\u7a33\u64cd\u80dc\u5238"
const TEXT_RISK_CLOSE := "\u52bf\u5747\u529b\u654c"
const TEXT_RISK_DANGEROUS := "\u9669\u8c61\u73af\u751f"
const TEXT_RISK_FATAL := "\u4e5d\u6b7b\u4e00\u751f"
const TEXT_ROLE_TAB_STATS_PLACEHOLDER := "HP 0/0\nATK 0\nINT 0.0s"
const TEXT_ROLE_TAB_STATS := "HP %d/%d\nATK %s\nINT %ss"
const ROLE_TAB_PEEK_WIDTH := 196.0
const ROLE_TAB_SLIDE_TIME := 0.18
const BATTLE_MODAL_BLOCKER_ALPHA := 0.56
const BATTLE_MODAL_BLOCKER_FADE_TIME := 0.18

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
@onready var help_button: Button = %HelpButton
@onready var restore_button: Button = %RestoreButton
@onready var action_button: Button = %ActionButton
@onready var action_button_text: TextureRect = %ActionButtonText
@onready var guide_overlay: Control = %GuideOverlay
@onready var guide_backdrop: ColorRect = %GuideBackdrop
@onready var guide_image: TextureRect = %GuideImage
@onready var wanted_poster_rect: TextureRect = %WantedPosterRect
@onready var next_monster_name_label: Label = %NextMonsterNameLabel
@onready var next_monster_bounty_label: Label = %NextMonsterBountyLabel
@onready var next_monster_stage_label: Label = %NextMonsterStageLabel
@onready var next_monster_stats_label: Label = %NextMonsterStatsLabel
@onready var next_monster_skill_label: Label = %NextMonsterSkillLabel
@onready var monster_tooltip_panel: PanelContainer = %MonsterTooltipPanel
@onready var synergy_panel: Control = %SynergyPanel
@onready var battle_modal_blocker: ColorRect = %BattleModalBlocker
@onready var battle_popup: BattlePopup = %BattlePopup
@onready var item_tooltip_anchor: Control = %ItemTooltipAnchor

@onready var tab_buttons: Dictionary = {
	&"warrior": %WarriorTabButton,
	&"hunter": %HunterTabButton,
	&"mage": %MageTabButton,
}
@onready var role_tab_stats_labels: Dictionary = {
	&"warrior": %WarriorTabStatsLabel,
	&"hunter": %HunterTabStatsLabel,
	&"mage": %MageTabStatsLabel,
}

var _food_textures: Dictionary = {}
var _food_board_textures: Dictionary = {}
var _base_lunchbox_textures: Dictionary = {}
var _expansion_lunchbox_textures: Dictionary = {}
var _role_names: Dictionary = {}
var _market_panel_open_position := Vector2.ZERO
var _market_panel_closed_position := Vector2.ZERO
var _market_panel_is_open: bool = false
var _market_panel_tween: Tween
var _intro_tween: Tween
var _intro_animating: bool = false
var _role_tab_open_positions: Dictionary = {}
var _role_tab_closed_positions: Dictionary = {}
var _role_tab_tweens: Dictionary = {}
var _hovered_role_id: StringName = &""
var _pinned_role_id: StringName = &""
var _last_node_type: StringName = &""
var _active_synergy_ids: Dictionary = {}
var _guide_page_index: int = 0
var _guide_marks_tutorial_complete: bool = false
var _battle_modal_blocker_tween: Tween
var item_tooltip_overlay: ImmediateItemTooltipOverlay
var synergy_tooltip_overlay: ImmediateSynergyTooltipOverlay

func _run_state() -> Node:
	return get_node("/root/RunState")

func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _ready() -> void:
	_bgm_player().play_non_battle()
	item_tooltip_overlay = ITEM_TOOLTIP_OVERLAY_SCENE.instantiate() as ImmediateItemTooltipOverlay
	item_tooltip_overlay.name = "ItemTooltipOverlay"
	item_tooltip_overlay.use_fixed_slot = false
	add_child(item_tooltip_overlay)
	synergy_tooltip_overlay = SYNERGY_TOOLTIP_OVERLAY_SCENE.instantiate() as ImmediateSynergyTooltipOverlay
	synergy_tooltip_overlay.name = "SynergyTooltipOverlay"
	synergy_tooltip_overlay.use_fixed_slot = false
	add_child(synergy_tooltip_overlay)
	item_tooltip_anchor.visible = false
	gold_label.add_theme_color_override("font_color", Color.WHITE)
	selected_item_label.add_theme_color_override("font_color", Color.WHITE)
	market_refresh_button.add_theme_color_override("font_color", Color.WHITE)
	_market_panel_open_position = top_market_panel.position
	_market_panel_closed_position = Vector2(_market_panel_open_position.x, -top_market_panel.size.y - 24.0)
	top_market_panel.position = _market_panel_closed_position
	top_market_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var run_state: Node = _run_state()
	run_state.ensure_initialized()
	run_state.ensure_persistable_run()
	_food_textures = FoodVisuals.build_food_texture_lookup()
	_food_board_textures = FoodVisuals.build_food_board_texture_lookup()
	_base_lunchbox_textures = LunchboxVisuals.build_role_base_texture_lookup()
	_expansion_lunchbox_textures = LunchboxVisuals.build_role_expansion_texture_lookup()
	_role_names = run_state.get_character_display_names()
	run_state.state_changed.connect(_refresh)
	run_state.selected_character_changed.connect(_on_selected_character_changed)
	run_state.selected_item_changed.connect(_refresh)
	run_state.battle_requested.connect(_on_battle_requested)
	battle_popup.popup_hide.connect(_on_battle_popup_hidden)
	board_view.cell_clicked.connect(_on_board_cell_clicked)
	board_view.cell_right_clicked.connect(_on_board_cell_right_clicked)
	board_view.board_drop_requested.connect(_on_board_drop_requested)
	board_view.hover_food_changed.connect(_on_board_hover_food_changed)
	board_view.hover_food_cleared.connect(_on_board_hover_food_cleared)
	top_market_strip.entry_clicked.connect(_on_market_entry_clicked)
	top_market_strip.entry_hover_started.connect(_on_strip_item_hover_started)
	top_market_strip.entry_hover_ended.connect(_on_strip_item_hover_ended)
	market_refresh_button.pressed.connect(_on_market_refresh_pressed)
	inventory_strip.entry_clicked.connect(_on_inventory_entry_clicked)
	inventory_strip.entry_hover_started.connect(_on_strip_item_hover_started)
	inventory_strip.entry_hover_ended.connect(_on_strip_item_hover_ended)
	synergy_panel.synergy_hover_started.connect(_on_synergy_hover_started)
	synergy_panel.synergy_hover_ended.connect(_on_synergy_hover_ended)
	inventory_drop_zone.drop_received.connect(_on_inventory_strip_drop_requested)
	inventory_drop_zone.accepted_sources = [&"market_offer", &"board_food", &"market_expansion"]
	inventory_strip.card_drop_sources = [&"market_offer", &"board_food", &"market_expansion"]
	inventory_strip.card_drop_target = inventory_drop_zone
	settings_button.pressed.connect(_on_settings_pressed)
	help_button.pressed.connect(_on_help_pressed)
	restore_button.pressed.connect(_on_restore_pressed)
	action_button.pressed.connect(_on_action_pressed)
	guide_backdrop.gui_input.connect(_on_guide_backdrop_gui_input)
	_setup_role_tab_interaction()
	tab_buttons[&"warrior"].pressed.connect(func() -> void: _on_role_tab_pressed(&"warrior"))
	tab_buttons[&"hunter"].pressed.connect(func() -> void: _on_role_tab_pressed(&"hunter"))
	tab_buttons[&"mage"].pressed.connect(func() -> void: _on_role_tab_pressed(&"mage"))
	board_view.set_food_textures(_food_textures)
	board_view.set_food_board_textures(_food_board_textures)
	board_view.set_lunchbox_textures(_base_lunchbox_textures, _expansion_lunchbox_textures)
	wanted_poster_rect.mouse_entered.connect(_on_monster_hover_entered)
	wanted_poster_rect.mouse_exited.connect(_on_monster_hover_exited)
	monster_tooltip_panel.visible = false
	guide_overlay.visible = false
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	battle_modal_blocker.visible = false
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
	gold_label.text = TEXT_GOLD % run_state.current_gold
	route_label.text = _build_route_label(run_state)
	node_label.text = TEXT_CURRENT_NODE % _display_name_for_node(current_node_type)
	risk_label.text = TEXT_RISK % _estimate_risk_label()
	selected_item_label.text = run_state.get_selected_item_summary_safe()
	action_button.text = ""
	_refresh_action_button_visual()
	market_refresh_button.disabled = current_node_type != run_state.NODE_MARKET
	market_refresh_button.text = TEXT_MARKET_REFRESH % run_state.get_current_refresh_cost()
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
		{
			"node": help_button,
			"target": help_button.position,
			"start": help_button.position + Vector2(-120.0, 120.0),
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
		_maybe_show_first_time_tutorial()
	)

func _refresh_selected_role(character_id: StringName) -> void:
	var run_state: Node = _run_state()
	var health: Dictionary = run_state.get_character_health_display(character_id)
	selected_role_label.text = TEXT_SELECTED_ROLE % [
		String(_role_names.get(character_id, String(character_id))),
		int(health.get("current_hp", 0)),
		int(health.get("max_hp", 0)),
	]
	for role_id in tab_buttons.keys():
		tab_buttons[role_id].text = ""

	_refresh_role_tab_visual_state()
	_refresh_role_tab_stats()

func _setup_role_tab_interaction() -> void:
	for role_id in tab_buttons.keys():
		var button: Button = tab_buttons.get(role_id) as Button
		if button == null:
			continue
		_role_tab_open_positions[role_id] = button.position
		_role_tab_closed_positions[role_id] = Vector2(
			minf(button.position.x, -button.size.x + ROLE_TAB_PEEK_WIDTH),
			button.position.y
		)
		button.mouse_entered.connect(_on_role_tab_hover_started.bind(role_id))
		button.mouse_exited.connect(_on_role_tab_hover_ended.bind(role_id))
	_refresh_role_tab_visual_state(true)

func _refresh_role_tab_visual_state(immediate: bool = false) -> void:
	for role_id in tab_buttons.keys():
		var button: Button = tab_buttons.get(role_id) as Button
		if button == null:
			continue
		var should_open: bool = role_id == _pinned_role_id or role_id == _hovered_role_id
		_set_role_tab_open_state(role_id, should_open, immediate)
		button.z_index = 2 if role_id == _pinned_role_id else (1 if role_id == _hovered_role_id else 0)

func _set_role_tab_open_state(role_id: StringName, should_open: bool, immediate: bool) -> void:
	var button: Button = tab_buttons.get(role_id) as Button
	if button == null:
		return
	var target_position: Vector2 = _role_tab_open_positions.get(role_id, button.position) if should_open else _role_tab_closed_positions.get(role_id, button.position)
	if immediate:
		button.position = target_position
		return
	if button.position.is_equal_approx(target_position):
		return
	var existing_tween: Tween = _role_tab_tweens.get(role_id) as Tween
	if is_instance_valid(existing_tween):
		existing_tween.kill()
	var tween: Tween = create_tween()
	_role_tab_tweens[role_id] = tween
	tween.tween_property(button, "position", target_position, ROLE_TAB_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_role_tab_hover_started(role_id: StringName) -> void:
	_hovered_role_id = role_id
	_refresh_role_tab_visual_state()

func _on_role_tab_hover_ended(role_id: StringName) -> void:
	if _hovered_role_id == role_id:
		_hovered_role_id = &""
	_refresh_role_tab_visual_state()

func _refresh_role_tab_stats() -> void:
	var run_state: Node = _run_state()
	for role_id in role_tab_stats_labels.keys():
		var stats_label: Label = role_tab_stats_labels.get(role_id) as Label
		if stats_label == null:
			continue
		var actor: Dictionary = CombatEngine.preview_character_actor(run_state, role_id)
		if actor.is_empty():
			stats_label.text = TEXT_ROLE_TAB_STATS_PLACEHOLDER
			continue
		var total_attack: float = float(actor.get("base_attack", 0.0)) + float(actor.get("attack_bonus", 0.0))
		var effective_interval: float = CombatEngine.preview_effective_interval(
			float(actor.get("base_interval", 1.0)),
			float(actor.get("attack_speed_bonus", 0.0))
		)
		stats_label.text = TEXT_ROLE_TAB_STATS % [
			int(round(float(actor.get("current_hp", 0.0)))),
			int(round(float(actor.get("max_hp", 0.0)))),
			_format_stat_value(total_attack),
			_format_stat_value(effective_interval),
		]

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
			}
		elif entry.get("kind", &"") == &"expansion":
			_apply_expansion_tooltip(entry)
			entry["icon_texture"] = _resolve_expansion_icon_texture(entry)
			entry["drag_payload"] = {
				"source": &"market_expansion",
				"offer_id": entry["offer_id"],
				"target_character_id": entry["target_character_id"],
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
			entry["icon_texture"] = _resolve_expansion_icon_texture(entry)
			entry["drag_payload"] = {
				"source": &"pending_expansion",
				"instance_id": entry["instance_id"],
				"target_character_id": entry["target_character_id"],
				"shape_cells": entry.get("shape_cells", []).duplicate(),
			}
		else:
			var definition: FoodDefinition = run_state.get_food_definition(entry["definition_id"])
			_apply_food_tooltip(entry, definition)
			entry["drag_payload"] = {
				"source": &"inventory",
				"group_key": entry["group_key"],
				"definition_id": entry["definition_id"],
			}
		entries.append(entry)
	inventory_strip.set_entries(entries, _food_textures)

func _apply_food_tooltip(entry: Dictionary, definition: FoodDefinition) -> void:
	if definition == null:
		return
	entry["tooltip_name"] = definition.display_name
	entry["tooltip_quantity"] = "x%d" % int(entry.get("count", 1))
	entry["tooltip_rarity"] = String(FOOD_RARITY_DISPLAY_NAMES.get(definition.rarity, String(definition.rarity)))
	entry["tooltip_category"] = _build_food_category_text(definition)
	entry["tooltip_price"] = TEXT_TOOLTIP_PRICE % _resolve_tooltip_price(entry, definition)
	entry["tooltip_shape_summary"] = _build_shape_summary(definition.shape_cells)
	entry["tooltip_base_bonus"] = _build_food_bonus_text(definition)
	entry["tooltip_special_effect"] = definition.passive_text.strip_edges() if not definition.passive_text.strip_edges().is_empty() else TEXT_TOOLTIP_NONE
	entry["tooltip_shape_cells"] = definition.shape_cells.duplicate()

func _apply_expansion_tooltip(entry: Dictionary) -> void:
	entry["tooltip_name"] = String(entry.get("display_name", TEXT_EXPANSION_DEFAULT))
	entry["tooltip_base_bonus"] = TEXT_EXPANSION_TOOLTIP_BONUS
	entry["tooltip_special_effect"] = TEXT_EXPANSION_TOOLTIP_EFFECT
	entry["tooltip_shape_cells"] = entry.get("shape_cells", []).duplicate()
func _resolve_expansion_icon_texture(entry: Dictionary) -> Texture2D:
	var role_lookup: Dictionary = _expansion_lunchbox_textures.get(entry.get("target_character_id", &""), {})
	if role_lookup.is_empty():
		return null
	return role_lookup.get(_shape_size_key(entry.get("shape_cells", [])), null) as Texture2D

func _shape_size_key(shape_cells: Array) -> StringName:
	if shape_cells.is_empty():
		return &""
	var min_x: int = int(shape_cells[0].x)
	var max_x: int = int(shape_cells[0].x)
	var min_y: int = int(shape_cells[0].y)
	var max_y: int = int(shape_cells[0].y)
	for cell_variant in shape_cells:
		var cell: Vector2i = cell_variant
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	return StringName("%dx%d" % [max_x - min_x + 1, max_y - min_y + 1])

func _build_food_bonus_text(definition: FoodDefinition) -> String:
	var parts: PackedStringArray = []
	if definition.hp_bonus != 0:
		parts.append(TEXT_BONUS_HP % _format_signed_value(float(definition.hp_bonus), 0))
	if not is_zero_approx(definition.attack_bonus):
		parts.append(TEXT_BONUS_ATTACK % _format_signed_value(definition.attack_bonus))
	if not is_zero_approx(definition.bonus_damage):
		parts.append(TEXT_BONUS_DAMAGE % _format_signed_value(definition.bonus_damage))
	if not is_zero_approx(definition.attack_speed_percent):
		parts.append(TEXT_BONUS_SPEED % _format_signed_value(definition.attack_speed_percent))
	if not is_zero_approx(definition.heal_per_second):
		parts.append(TEXT_BONUS_HPS % _format_signed_value(definition.heal_per_second))
	if not is_zero_approx(definition.execute_threshold_percent):
		parts.append(TEXT_BONUS_EXECUTE % _format_signed_value(definition.execute_threshold_percent))
	if parts.is_empty():
		return TEXT_BONUS_NONE
	return TEXT_BONUS_SEPARATOR.join(parts)

func _build_food_category_text(definition: FoodDefinition) -> String:
	var run_state: Node = _run_state()
	var categories: PackedStringArray = []
	for category_id in run_state.get_food_categories(definition):
		var category_name: String = String(run_state.CATEGORY_DISPLAY_NAMES.get(category_id, String(category_id)))
		if not categories.has(category_name):
			categories.append(category_name)
	return "/".join(categories)

func _resolve_tooltip_price(entry: Dictionary, definition: FoodDefinition) -> int:
	if entry.has("display_price"):
		return int(entry.get("display_price", 0))
	if entry.has("unit_price"):
		return int(entry.get("unit_price", 0))
	return definition.gold_value

func _build_shape_summary(shape_cells: Array) -> String:
	if shape_cells.is_empty():
		return TEXT_TOOLTIP_NONE
	var normalized_cells: Array[Vector2i] = ShapeUtils.normalize_cells(shape_cells)
	var max_x: int = 0
	var max_y: int = 0
	for cell in normalized_cells:
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	return TEXT_TOOLTIP_SHAPE_SUMMARY % [normalized_cells.size(), max_x + 1, max_y + 1]
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

func _format_stat_value(value: float, decimals: int = 1) -> String:
	var text := ""
	if decimals <= 0 or is_zero_approx(value - round(value)):
		text = str(int(round(value)))
	else:
		text = str(snapped(value, 0.1))
		if text.contains("."):
			while text.ends_with("0"):
				text = text.left(text.length() - 1)
			if text.ends_with("."):
				text = text.left(text.length() - 1)
	return text

func _refresh_board() -> void:
	var run_state: Node = _run_state()
	var preview_cells: Array[Vector2i] = []
	if not run_state.selected_item.is_empty() and not bool(run_state.selected_item.get("drag_session", false)):
		preview_cells = run_state.get_selected_item_cells()
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	board_view.refresh_board(run_state.get_selected_character_state(), preview_cells, run_state.food_lookup, _food_textures)


func _refresh_next_monster_panel() -> void:
	var summary: Dictionary = _run_state().get_next_monster_summary()
	if summary.is_empty():
		wanted_poster_rect.texture = DEFAULT_WANTED_POSTER_TEXTURE
		next_monster_name_label.text = TEXT_UNKNOWN
		next_monster_bounty_label.text = TEXT_BOUNTY_EMPTY
		next_monster_stage_label.text = TEXT_STAGE_EMPTY
		next_monster_stats_label.text = "-"
		next_monster_skill_label.text = "-"
		monster_tooltip_panel.visible = false
		return
	next_monster_name_label.text = "%s / %s" % [String(summary.get("display_name", "")), String(summary.get("category_name", ""))]
	next_monster_bounty_label.text = TEXT_BOUNTY % _get_next_battle_reward()
	next_monster_stage_label.text = TEXT_STAGE % [_run_state().current_route_index + 1, _get_total_stage_count()]
	next_monster_stats_label.text = TEXT_MONSTER_STATS % [
		int(summary.get("hp", 0)),
		float(summary.get("attack", 0.0)),
		float(summary.get("attack_interval", 0.0)),
	]
	next_monster_skill_label.text = String(summary.get("skill_summary", ""))
	wanted_poster_rect.texture = WANTED_POSTER_TEXTURES.get(summary.get("id", &""), DEFAULT_WANTED_POSTER_TEXTURE) as Texture2D
	monster_tooltip_panel.visible = false
func _build_route_label(run_state: Node) -> String:
	var total_nodes: int = 0
	if run_state.stage_flow_config != null:
		total_nodes = run_state.stage_flow_config.route_nodes.size()
	return TEXT_ROUTE % [
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
			return TEXT_NODE_MARKET
		&"battle":
			return TEXT_NODE_BATTLE
		&"rest":
			return TEXT_NODE_REST
		&"boss_battle":
			return TEXT_NODE_BOSS
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
	_pinned_role_id = character_id
	_refresh_selected_role(character_id)
	_refresh()

func _on_market_entry_clicked(entry: Dictionary) -> void:
	if entry.get("kind", &"") != &"food" and entry.get("kind", &"") != &"expansion":
		return
	var gained: Array[Dictionary] = _run_state().purchase_market_offer_package(entry.get("offer_id", &""))
	if gained.is_empty():
		_ui_sfx().play_purchase_denied()
	else:
		_ui_sfx().play_purchase_success()

func _on_inventory_entry_clicked(entry: Dictionary) -> void:
	if entry.get("entry_kind", &"food") == &"expansion":
		_run_state().select_pending_expansion(entry.get("instance_id", &""), entry.get("target_character_id", &""))
	else:
		_run_state().pick_inventory_instance(entry.get("group_key", &""))

func _on_board_cell_clicked(cell: Vector2i) -> void:
	var run_state: Node = _run_state()
	if not run_state.selected_item.is_empty():
		item_tooltip_overlay.hide_tooltip()
		synergy_tooltip_overlay.hide_tooltip()
		if run_state.try_place_selected_item(cell):
			_ui_sfx().play_place()

func _on_board_cell_right_clicked(cell: Vector2i) -> void:
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	if _run_state().remove_item_at_cell(cell):
		_ui_sfx().play_place()

func _on_board_drop_requested(anchor_cell: Vector2i, drag_data: Dictionary) -> void:
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	var run_state: Node = _run_state()
	match drag_data.get("source", &""):
		&"market_offer":
			if run_state.selected_item.is_empty() or run_state.selected_item.get("source", &"") != &"market_offer" or run_state.selected_item.get("offer_id", &"") != drag_data.get("offer_id", &""):
				run_state.begin_market_offer_action(drag_data.get("offer_id", &""))
			if run_state.try_place_selected_item(anchor_cell):
				_ui_sfx().play_place()
			else:
				_ui_sfx().play_purchase_denied()
				run_state.clear_selection()
		&"inventory":
			if run_state.selected_item.is_empty() or run_state.selected_item.get("source", &"") != &"inventory":
				run_state.begin_inventory_drag(drag_data.get("group_key", &""))
			if run_state.try_place_selected_item(anchor_cell):
				_ui_sfx().play_place()
			else:
				run_state.clear_selection()
		&"pending_expansion":
			if run_state.selected_item.is_empty() or run_state.selected_item.get("instance_id", &"") != drag_data.get("instance_id", &""):
				if not run_state.select_pending_expansion(drag_data.get("instance_id", &""), drag_data.get("target_character_id", &"")):
					run_state.clear_selection()
					_ui_sfx().play_purchase_denied()
					_refresh()
					return
				run_state.selected_item["drag_session"] = true
			if run_state.try_place_selected_item(anchor_cell):
				_ui_sfx().play_place()
			else:
				run_state.clear_selection()
		&"market_expansion":
			if run_state.selected_item.is_empty() or run_state.selected_item.get("source", &"") != &"market_expansion" or run_state.selected_item.get("offer_id", &"") != drag_data.get("offer_id", &""):
				run_state.begin_market_expansion_action(drag_data.get("offer_id", &""))
			if run_state.try_place_selected_item(anchor_cell):
				_ui_sfx().play_place()
			else:
				_ui_sfx().play_purchase_denied()
				run_state.clear_selection()
		&"board_food":
			if run_state.selected_item.is_empty() or run_state.selected_item.get("source", &"") != &"board_food" or run_state.selected_item.get("instance_id", &"") != drag_data.get("instance_id", &""):
				run_state.begin_board_food_action(drag_data.get("from_cell", Vector2i.ZERO))
			if run_state.try_place_selected_item(anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)):
				_ui_sfx().play_place()
		&"board_expansion":
			if run_state.selected_item.is_empty() or run_state.selected_item.get("source", &"") != &"board_expansion" or run_state.selected_item.get("instance_id", &"") != drag_data.get("instance_id", &""):
				if not run_state.begin_board_expansion_action(drag_data.get("from_cell", Vector2i.ZERO)):
					run_state.clear_selection()
					_ui_sfx().play_purchase_denied()
					_refresh()
					return
			if run_state.try_place_selected_item(anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)):
				_ui_sfx().play_place()
			else:
				run_state.clear_selection()
		&"board_base":
			var adjusted_anchor: Vector2i = anchor_cell - drag_data.get("grab_offset", Vector2i.ZERO)
			if run_state.move_base_board(adjusted_anchor):
				_ui_sfx().play_place()
	_refresh()

func _on_board_hover_food_changed(item: Dictionary, global_rect: Rect2) -> void:
	var run_state: Node = _run_state()
	var definition: FoodDefinition = run_state.get_food_definition(item.get("definition_id", &""))
	if definition == null:
		item_tooltip_overlay.hide_tooltip()
		board_view.clear_synergy_highlights()
		return
	board_view.set_synergy_highlights_for_item(run_state, run_state.selected_character_id, item.get("instance_id", &""))
	synergy_tooltip_overlay.hide_tooltip()
	var entry: Dictionary = {
		"display_name": definition.display_name,
		"definition_id": definition.id,
	}
	_apply_food_tooltip(entry, definition)
	item_tooltip_overlay.show_entry(entry, global_rect)
	_position_item_tooltip_overlay()

func _on_board_hover_food_cleared() -> void:
	board_view.clear_synergy_highlights()
	item_tooltip_overlay.hide_tooltip()

func _on_strip_item_hover_started(entry: Dictionary, global_rect: Rect2) -> void:
	synergy_tooltip_overlay.hide_tooltip()
	item_tooltip_overlay.show_entry(entry, global_rect)
	_position_item_tooltip_overlay()

func _on_strip_item_hover_ended() -> void:
	item_tooltip_overlay.hide_tooltip()

func _position_item_tooltip_overlay() -> void:
	if item_tooltip_overlay == null or item_tooltip_anchor == null:
		return
	var anchor_rect: Rect2 = item_tooltip_anchor.get_global_rect()
	item_tooltip_overlay.place_at_global_point(Vector2(anchor_rect.get_center().x, anchor_rect.position.y))

func _on_synergy_hover_started(entry: Dictionary, global_rect: Rect2) -> void:
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.show_entry(entry, global_rect)
	_position_synergy_tooltip_overlay()

func _on_synergy_hover_ended() -> void:
	synergy_tooltip_overlay.hide_tooltip()

func _hide_tooltip_overlays() -> void:
	if item_tooltip_overlay != null:
		item_tooltip_overlay.hide_tooltip()
	if synergy_tooltip_overlay != null:
		synergy_tooltip_overlay.hide_tooltip()

func _position_synergy_tooltip_overlay() -> void:
	if synergy_tooltip_overlay == null or item_tooltip_anchor == null:
		return
	var anchor_rect: Rect2 = item_tooltip_anchor.get_global_rect()
	synergy_tooltip_overlay.place_at_global_point(Vector2(anchor_rect.get_center().x, anchor_rect.position.y))

func _on_inventory_strip_drop_requested(drag_data: Dictionary) -> void:
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	var run_state: Node = _run_state()
	match drag_data.get("source", &""):
		&"market_offer":
			var gained_items: Array[Dictionary] = run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
			if gained_items.is_empty():
				_ui_sfx().play_purchase_denied()
			else:
				_ui_sfx().play_purchase_success()
			run_state.clear_selection()
		&"market_expansion":
			var gained_expansions: Array[Dictionary] = run_state.purchase_market_offer_package(drag_data.get("offer_id", &""))
			if gained_expansions.is_empty():
				_ui_sfx().play_purchase_denied()
			else:
				_ui_sfx().play_purchase_success()
			run_state.clear_selection()
		&"board_food":
			if run_state.store_placed_food(drag_data.get("from_cell", Vector2i.ZERO)):
				_ui_sfx().play_place()
			run_state.clear_selection()
	_refresh()

func _on_restore_pressed() -> void:
	_ui_sfx().play_button()
	_run_state().try_restore_snapshot()

func _on_help_pressed() -> void:
	_ui_sfx().play_button()
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	_show_guide_overlay(false)

func _maybe_show_first_time_tutorial() -> void:
	if _run_state().is_tutorial_completed():
		return
	_show_guide_overlay(true)

func _show_guide_overlay(mark_tutorial_complete_on_finish: bool) -> void:
	_guide_page_index = 0
	_guide_marks_tutorial_complete = mark_tutorial_complete_on_finish
	_apply_guide_page()
	guide_overlay.visible = true

func _hide_guide_overlay() -> void:
	guide_overlay.visible = false
	_guide_marks_tutorial_complete = false

func _advance_guide_overlay() -> void:
	_guide_page_index += 1
	if _guide_page_index >= GUIDE_TEXTURES.size():
		_complete_guide_overlay()
		return
	_apply_guide_page()

func _complete_guide_overlay() -> void:
	if _guide_marks_tutorial_complete:
		_run_state().mark_tutorial_completed()
	guide_overlay.visible = false
	_guide_marks_tutorial_complete = false

func _apply_guide_page() -> void:
	if GUIDE_TEXTURES.is_empty():
		return
	guide_image.texture = GUIDE_TEXTURES[_guide_page_index]

func _on_guide_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_guide_overlay()
		get_viewport().set_input_as_handled()

func _on_settings_pressed() -> void:
	_ui_sfx().play_button()
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	_run_state().set_settings_return_scene("res://Scenes/main_editor_screen.tscn")
	get_tree().change_scene_to_file("res://Scenes/settings_screen.tscn")

func _on_action_pressed() -> void:
	_ui_sfx().play_button()
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	_run_state().perform_primary_action()

func _refresh_action_button_visual() -> void:
	var visual_key: StringName = _run_state().get_action_button_visual_key()
	action_button_text.texture = ACTION_BUTTON_TEXT_TEXTURES.get(visual_key, ACTION_BUTTON_TEXT_TEXTURES[&"continue"])

func _on_market_refresh_pressed() -> void:
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	if _run_state().refresh_market_offers():
		_ui_sfx().play_button()
	else:
		_ui_sfx().play_purchase_denied()

func _on_battle_requested() -> void:
	_show_battle_modal_blocker()
	battle_popup.open_battle()

func _on_battle_popup_hidden() -> void:
	_hide_battle_modal_blocker()

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
		return TEXT_RISK_UNKNOWN
	var monster_multipliers: Dictionary = run_state.get_current_monster_multipliers()
	var scaled_monster_attack: float = float(monster.base_attack) * float(monster_multipliers.get("attack", 1.0))
	var scaled_monster_hp: float = float(monster.base_hp) * float(monster_multipliers.get("hp", 1.0))
	var monster_power: float = scaled_monster_attack * 2.0 + scaled_monster_hp / 6.0
	var ratio: float = total_power / maxf(monster_power, 1.0)
	if ratio >= 1.8:
		return TEXT_RISK_OVERWHELM
	if ratio >= 1.2:
		return TEXT_RISK_STABLE
	if ratio >= 0.85:
		return TEXT_RISK_CLOSE
	if ratio >= 0.6:
		return TEXT_RISK_DANGEROUS
	return TEXT_RISK_FATAL

func _show_battle_modal_blocker() -> void:
	if is_instance_valid(_battle_modal_blocker_tween):
		_battle_modal_blocker_tween.kill()
	battle_modal_blocker.visible = true
	battle_modal_blocker.color.a = 0.0
	_battle_modal_blocker_tween = create_tween()
	_battle_modal_blocker_tween.tween_property(
		battle_modal_blocker,
		"color:a",
		BATTLE_MODAL_BLOCKER_ALPHA,
		BATTLE_MODAL_BLOCKER_FADE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hide_battle_modal_blocker() -> void:
	if is_instance_valid(_battle_modal_blocker_tween):
		_battle_modal_blocker_tween.kill()
		_battle_modal_blocker_tween = null
	if not battle_modal_blocker.visible:
		return
	_battle_modal_blocker_tween = create_tween()
	_battle_modal_blocker_tween.tween_property(
		battle_modal_blocker,
		"color:a",
		0.0,
		BATTLE_MODAL_BLOCKER_FADE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _battle_modal_blocker_tween.finished
	battle_modal_blocker.visible = false
	_battle_modal_blocker_tween = null
func _on_role_tab_pressed(character_id: StringName) -> void:
	_ui_sfx().play_button()
	item_tooltip_overlay.hide_tooltip()
	synergy_tooltip_overlay.hide_tooltip()
	_pinned_role_id = character_id
	_refresh_role_tab_visual_state()
	_run_state().select_character(character_id)

func _unhandled_input(event: InputEvent) -> void:
	if guide_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_hide_guide_overlay()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_run_state().rotate_selected_item()
		get_viewport().set_input_as_handled()
