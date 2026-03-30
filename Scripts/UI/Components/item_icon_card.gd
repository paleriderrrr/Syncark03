extends Control
class_name ItemIconCard

signal clicked(entry: Dictionary)
signal hover_started(entry: Dictionary, global_rect: Rect2)
signal hover_ended

const CATEGORY_LABELS := {
	&"fruit": "\u852c\u679c",
	&"dessert": "\u751c\u54c1",
	&"meat": "\u8089\u7c7b",
	&"drink": "\u996e\u54c1",
	&"staple": "\u4e3b\u98df",
	&"spice": "\u9999\u6599",
}

@onready var background_rect: TextureRect = $Content/Background
@onready var rarity_bar: ColorRect = %RarityBar
@onready var rarity_badge: Panel = %RarityBadge
@onready var rarity_label: Label = %RarityLabel
@onready var category_badge: Panel = %CategoryBadge
@onready var category_label: Label = %CategoryLabel
@onready var discount_badge: Panel = %DiscountBadge
@onready var discount_label: Label = %DiscountLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var count_badge: Panel = %CountBadge
@onready var count_label: Label = %CountLabel
@onready var price_badge: Panel = %PriceBadge
@onready var price_label: Label = %PriceLabel

var entry: Dictionary = {}
var drag_payload: Dictionary = {}
var accepted_drop_sources: Array[StringName] = []
var drop_forward_target: Node = null
var _left_pressed: bool = false
var _drag_started: bool = false

func configure(
	new_entry: Dictionary,
	texture: Texture2D,
	new_drag_payload: Dictionary,
	new_accepted_drop_sources: Array[StringName] = [],
	new_drop_forward_target: Node = null,
	background_texture: Texture2D = null
) -> void:
	entry = new_entry.duplicate(true)
	drag_payload = new_drag_payload.duplicate(true)
	accepted_drop_sources = new_accepted_drop_sources.duplicate()
	drop_forward_target = new_drop_forward_target
	var resolved_texture: Texture2D = entry.get("icon_texture", texture) as Texture2D
	var is_food_card: bool = entry.get("kind", &"food") == &"food" and entry.get("entry_kind", &"food") == &"food"
	var category_id: StringName = entry.get("category", &"")
	name_label.text = String(entry.get("display_name", ""))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label.text = "x%d" % int(entry.get("count", 0))
	count_badge.visible = int(entry.get("count", 0)) > 0
	if entry.has("display_price"):
		price_label.text = "%d G" % int(entry["display_price"])
	elif entry.has("unit_price"):
		price_label.text = "%d G" % int(entry["unit_price"])
	else:
		price_label.text = ""
	price_badge.visible = not price_label.text.is_empty()
	var discount_percent: int = int(entry.get("discount_percent", 0))
	discount_badge.visible = discount_percent > 0
	discount_label.text = "-%d%%" % discount_percent if discount_percent > 0 else ""
	icon_rect.texture = resolved_texture
	icon_rect.visible = resolved_texture != null
	background_rect.texture = null
	background_rect.visible = false
	var rarity: StringName = entry.get("rarity", &"common")
	var rarity_color: Color = _rarity_color(rarity)
	rarity_bar.color = rarity_color
	rarity_badge.visible = not String(entry.get("rarity_label", _rarity_label(rarity))).is_empty()
	rarity_label.text = String(entry.get("rarity_label", _rarity_label(rarity)))
	category_badge.visible = is_food_card and CATEGORY_LABELS.has(category_id)
	category_label.text = String(CATEGORY_LABELS.get(category_id, ""))
	name_label.add_theme_color_override("font_color", Color.WHITE)
	rarity_label.add_theme_color_override("font_color", Color.WHITE)
	category_label.add_theme_color_override("font_color", Color.WHITE)
	discount_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	price_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_text = ""

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	hover_started.emit(entry.duplicate(true), get_global_rect())

func _on_mouse_exited() -> void:
	hover_ended.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_pressed = true
			_drag_started = false
		elif _left_pressed and not _drag_started:
			clicked.emit(entry)
			_left_pressed = false

func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	_begin_drag_action()
	_drag_started = true
	_left_pressed = false
	_ui_sfx().play_pickup()
	var preview: Control = _build_preview()
	set_drag_preview(preview)
	return drag_payload.duplicate(true)

func _begin_drag_action() -> void:
	var run_state: Node = get_node("/root/RunState")
	match drag_payload.get("source", &""):
		&"inventory":
			run_state.begin_inventory_drag(drag_payload.get("group_key", &""))
		&"market_offer":
			run_state.begin_market_offer_action(drag_payload.get("offer_id", &""))
		&"pending_expansion":
			if run_state.select_pending_expansion(drag_payload.get("instance_id", &""), drag_payload.get("target_character_id", &"")):
				run_state.selected_item["drag_session"] = true
				run_state.selected_item_changed.emit()
				run_state.state_changed.emit()
		&"market_expansion":
			run_state.begin_market_expansion_action(drag_payload.get("offer_id", &""))

func _build_preview() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72, 72)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var preview_icon := TextureRect.new()
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.custom_minimum_size = Vector2(56, 40)
	preview_icon.texture = icon_rect.texture
	vbox.add_child(preview_icon)
	var preview_label := Label.new()
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.text = "x1"
	vbox.add_child(preview_label)
	return panel

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data
	return accepted_drop_sources.has(payload.get("source", &""))

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	if drop_forward_target != null and drop_forward_target.has_method("handle_forwarded_drop"):
		drop_forward_target.call("handle_forwarded_drop", data)

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _rarity_color(rarity: StringName) -> Color:
	match rarity:
		&"common":
			return Color(0.74, 0.74, 0.74, 0.95)
		&"rare":
			return Color(0.27, 0.58, 0.93, 0.95)
		&"epic":
			return Color(0.82, 0.42, 0.91, 0.95)
		_:
			return Color(0.74, 0.74, 0.74, 0.95)

func _rarity_label(rarity: StringName) -> String:
	match rarity:
		&"common":
			return "Common"
		&"rare":
			return "Rare"
		&"epic":
			return "Epic"
		_:
			return ""
