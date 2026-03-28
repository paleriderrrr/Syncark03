extends Control

@onready var gold_label: Label = %GoldLabel
@onready var route_label: Label = %RouteLabel
@onready var node_label: Label = %NodeLabel
@onready var risk_label: Label = %RiskLabel
@onready var selected_role_label: Label = %SelectedRoleLabel
@onready var selected_item_label: Label = %SelectedItemLabel
@onready var board_view: BentoBoardView = %BentoBoardView
@onready var market_list: ItemList = %MarketList
@onready var inventory_list: ItemList = %InventoryList
@onready var pending_expansion_list: ItemList = %PendingExpansionList
@onready var reroll_button: Button = %RerollButton
@onready var buy_button: Button = %BuyButton
@onready var rotate_button: Button = %RotateButton
@onready var clear_selection_button: Button = %ClearSelectionButton
@onready var restore_button: Button = %RestoreButton
@onready var action_button: Button = %ActionButton
@onready var battle_popup: BattlePopup = %BattlePopup
@onready var left_vbox: VBoxContainer = $Margin/RootVBox/MainHBox/LeftPanel/LeftVBox
@onready var board_title: Label = $Margin/RootVBox/MainHBox/CenterPanel/CenterVBox/BoardTitle
@onready var inventory_title: Label = $Margin/RootVBox/InventoryPanel/InventoryVBox/InventoryTitle
@onready var market_title: Label = $Margin/RootVBox/MainHBox/RightPanel/RightVBox/MarketTitle
@onready var role_title: Label = $Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/RoleTitle
@onready var pending_expansion_title: Label = $Margin/RootVBox/MainHBox/LeftPanel/LeftVBox/PendingExpansionTitle
@onready var tab_buttons: Dictionary = {
	&"warrior": %WarriorTabButton,
	&"hunter": %HunterTabButton,
	&"mage": %MageTabButton,
}

var _market_offer_ids: Array[StringName] = []
var _inventory_ids: Array[StringName] = []
var _pending_expansion_ids: Array[StringName] = []
var _role_preview_views: Dictionary = {}

func _run_state() -> Node:
	return get_node("/root/RunState")

func _ready() -> void:
	var run_state: Node = _run_state()
	run_state.ensure_initialized()
	_apply_static_texts()
	_build_role_previews()
	run_state.state_changed.connect(_refresh)
	run_state.selected_character_changed.connect(_on_selected_character_changed)
	run_state.selected_item_changed.connect(_refresh)
	run_state.battle_requested.connect(_on_battle_requested)
	board_view.cell_clicked.connect(_on_board_cell_clicked)
	market_list.item_selected.connect(_on_market_selected)
	inventory_list.item_selected.connect(_on_inventory_selected)
	pending_expansion_list.item_selected.connect(_on_pending_expansion_selected)
	reroll_button.pressed.connect(_on_reroll_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	rotate_button.pressed.connect(func() -> void: _run_state().rotate_selected_item())
	clear_selection_button.pressed.connect(func() -> void: _run_state().clear_selection())
	restore_button.pressed.connect(_on_restore_pressed)
	action_button.pressed.connect(_on_action_pressed)
	tab_buttons[&"warrior"].pressed.connect(func() -> void: _run_state().select_character(&"warrior"))
	tab_buttons[&"hunter"].pressed.connect(func() -> void: _run_state().select_character(&"hunter"))
	tab_buttons[&"mage"].pressed.connect(func() -> void: _run_state().select_character(&"mage"))
	_refresh()

func _apply_static_texts() -> void:
	role_title.text = "角色饭盒"
	pending_expansion_title.text = "待放置拓展"
	board_title.text = "当前角色饭盒编辑"
	inventory_title.text = "共享仓库"
	market_title.text = "市场"
	selected_role_label.text = "当前编辑角色"
	selected_item_label.text = "未选择物品"
	rotate_button.text = "旋转"
	clear_selection_button.text = "清除选择"
	restore_button.text = "恢复上一战方案"
	buy_button.text = "购买选中商品"
	reroll_button.text = "刷新商店"
	tab_buttons[&"warrior"].text = "战士"
	tab_buttons[&"hunter"].text = "猎人"
	tab_buttons[&"mage"].text = "法师"

func _build_role_previews() -> void:
	if not _role_preview_views.is_empty():
		return
	var order: Array[StringName] = [&"warrior", &"hunter", &"mage"]
	for role_id in order:
		var preview_board := BentoBoardView.new()
		preview_board.name = "%sPreviewBoard" % String(role_id)
		preview_board.read_only = true
		preview_board.cell_pixel_size = 18
		preview_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_board.cell_clicked.connect(func(_cell: Vector2i) -> void:
			_run_state().select_character(role_id)
		)
		left_vbox.add_child(preview_board)
		var button_index: int = left_vbox.get_children().find(tab_buttons[role_id])
		left_vbox.move_child(preview_board, button_index + 1)
		_role_preview_views[role_id] = preview_board

func _refresh() -> void:
	var run_state: Node = _run_state()
	gold_label.text = "金币: %d" % run_state.current_gold
	route_label.text = run_state.get_route_label()
	node_label.text = "当前节点: %s" % run_state.get_node_display_name(run_state.get_current_node_type())
	risk_label.text = "危险度评级: %s" % _estimate_risk_label()
	selected_item_label.text = run_state.get_selected_item_summary()
	action_button.text = run_state.get_action_button_text()
	restore_button.disabled = run_state.get_current_node_type() != run_state.NODE_REST
	_refresh_selected_role(run_state.selected_character_id)
	_refresh_lists()
	_refresh_board()
	_refresh_role_previews()

func _refresh_selected_role(character_id: StringName) -> void:
	var names: Dictionary = _run_state().get_character_display_names()
	selected_role_label.text = "当前编辑: %s" % names.get(character_id, String(character_id))
	for id in tab_buttons.keys():
		tab_buttons[id].disabled = id == character_id

func _refresh_lists() -> void:
	var run_state: Node = _run_state()
	market_list.clear()
	_market_offer_ids.clear()
	for entry in run_state.get_market_display_entries():
		market_list.add_item(entry["label"])
		_market_offer_ids.append(entry["offer_id"])
	var is_market: bool = run_state.get_current_node_type() == run_state.NODE_MARKET
	market_list.mouse_filter = Control.MOUSE_FILTER_STOP if is_market else Control.MOUSE_FILTER_IGNORE
	reroll_button.disabled = not is_market
	buy_button.disabled = not is_market

	inventory_list.clear()
	_inventory_ids.clear()
	for entry in run_state.get_inventory_display_entries():
		inventory_list.add_item(entry["label"])
		_inventory_ids.append(entry["instance_id"])

	pending_expansion_list.clear()
	_pending_expansion_ids.clear()
	for entry in run_state.get_pending_expansion_entries(run_state.selected_character_id):
		pending_expansion_list.add_item(entry["label"])
		_pending_expansion_ids.append(entry["instance_id"])

func _refresh_board() -> void:
	var run_state: Node = _run_state()
	var preview_cells: Array[Vector2i] = []
	if not run_state.selected_item.is_empty():
		preview_cells = run_state.get_selected_item_cells()
	board_view.refresh_board(run_state.get_selected_character_state(), preview_cells, run_state.food_lookup)

func _refresh_role_previews() -> void:
	var run_state: Node = _run_state()
	for role_id in _role_preview_views.keys():
		var preview_board: BentoBoardView = _role_preview_views[role_id]
		preview_board.refresh_board(run_state.get_character_state(role_id), [], run_state.food_lookup)
		preview_board.modulate = Color(1.0, 1.0, 1.0, 1.0) if role_id == run_state.selected_character_id else Color(0.82, 0.82, 0.82, 1.0)

func _on_selected_character_changed(character_id: StringName) -> void:
	_refresh_selected_role(character_id)
	_refresh()

func _on_market_selected(index: int) -> void:
	if index < 0 or index >= _market_offer_ids.size():
		return

func _on_inventory_selected(index: int) -> void:
	if index < 0 or index >= _inventory_ids.size():
		return
	_run_state().select_inventory_item(_inventory_ids[index])

func _on_pending_expansion_selected(index: int) -> void:
	if index < 0 or index >= _pending_expansion_ids.size():
		return
	_run_state().select_pending_expansion(_pending_expansion_ids[index])

func _on_reroll_pressed() -> void:
	_run_state().refresh_market_offers()

func _on_buy_pressed() -> void:
	var selected: PackedInt32Array = market_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index >= 0 and index < _market_offer_ids.size():
		_run_state().buy_market_offer(index)

func _on_board_cell_clicked(cell: Vector2i) -> void:
	var run_state: Node = _run_state()
	if run_state.selected_item.is_empty():
		run_state.remove_item_at_cell(cell)
	else:
		run_state.try_place_selected_item(cell)

func _on_restore_pressed() -> void:
	_run_state().try_restore_snapshot()

func _on_action_pressed() -> void:
	_run_state().perform_primary_action()

func _on_battle_requested() -> void:
	battle_popup.open_battle()

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
		for placed in state["placed_foods"]:
			var food: FoodDefinition = run_state.get_food_definition(placed["definition_id"])
			total_power += food.attack_bonus * 1.5
			total_power += food.hp_bonus / 8.0
			total_power += food.bonus_damage
			total_power += food.attack_speed_percent / 10.0
	var monster: MonsterDefinition = run_state.get_current_monster_definition()
	if monster == null:
		return "未知"
	var monster_power: float = monster.base_attack * 2.0 + monster.base_hp / 6.0
	var ratio: float = total_power / maxf(monster_power, 1.0)
	if ratio >= 1.8:
		return "碾压"
	if ratio >= 1.2:
		return "稳定"
	if ratio >= 0.85:
		return "胶着"
	if ratio >= 0.6:
		return "危险"
	return "送死"
