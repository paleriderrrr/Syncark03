extends PanelContainer
class_name ItemStrip

signal entry_clicked(entry: Dictionary)
signal entry_hover_started(entry: Dictionary, global_rect: Rect2)
signal entry_hover_ended

const CARD_SCENE := preload("res://Scenes/Components/item_icon_card.tscn")
const CARD_WIDTH := 132
const CARD_GAP := 14

@export var card_background_texture: Texture2D

@onready var title_label: Label = %TitleLabel
@onready var viewport_control: Control = %Viewport
@onready var card_row: HBoxContainer = %CardRow
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton

var _entry_count: int = 0
var _page_index: int = 0
var _cards: Array[ItemIconCard] = []
var card_drop_sources: Array[StringName] = []
var card_drop_target: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	prev_button.pressed.connect(_show_previous_page)
	next_button.pressed.connect(_show_next_page)
	viewport_control.resized.connect(_refresh_page_state)
	call_deferred("_refresh_page_state")

func set_title(text_value: String) -> void:
	title_label.text = text_value
	title_label.visible = not text_value.is_empty()

func set_entries(entries: Array[Dictionary], texture_lookup: Dictionary) -> void:
	for child in card_row.get_children():
		child.queue_free()
	_cards.clear()
	_entry_count = entries.size()
	_page_index = 0
	for entry in entries:
		var card: ItemIconCard = CARD_SCENE.instantiate() as ItemIconCard
		var texture: Texture2D = entry.get("icon_texture", null) as Texture2D
		if texture == null:
			texture = texture_lookup.get(entry.get("definition_id", &""), null) as Texture2D
		card_row.add_child(card)
		card.configure(entry, texture, entry.get("drag_payload", {}), card_drop_sources, card_drop_target, card_background_texture)
		card.clicked.connect(_on_card_clicked)
		card.hover_started.connect(_on_card_hover_started)
		card.hover_ended.connect(_on_card_hover_ended)
		_cards.append(card)
	call_deferred("_refresh_page_state")

func get_entry_count() -> int:
	return _entry_count

func _show_previous_page() -> void:
	if _page_index <= 0:
		return
	_page_index -= 1
	_ui_sfx().play_strip_slide()
	_refresh_page_state()

func _show_next_page() -> void:
	var max_page: int = _get_max_page_index()
	if _page_index >= max_page:
		return
	_page_index += 1
	_ui_sfx().play_strip_slide()
	_refresh_page_state()

func _refresh_page_state() -> void:
	if not is_inside_tree():
		return
	var visible_slots: int = _get_visible_slot_count()
	var max_page: int = _get_max_page_index_for_slots(visible_slots)
	_page_index = clampi(_page_index, 0, max_page)
	var visible_width: float = viewport_control.size.x
	var content_width: float = maxf(_entry_count * CARD_WIDTH + max(_entry_count - 1, 0) * CARD_GAP, 0.0)
	var max_offset: float = maxf(content_width - visible_width, 0.0)
	var page_stride: float = maxf(float(visible_slots * (CARD_WIDTH + CARD_GAP)), 1.0)
	var target_offset: float = minf(float(_page_index) * page_stride, max_offset)
	if content_width <= visible_width:
		card_row.position.x = 0.0
	else:
		card_row.position.x = -target_offset
	prev_button.disabled = _page_index <= 0
	next_button.disabled = _page_index >= max_page
	prev_button.visible = max_page > 0
	next_button.visible = max_page > 0

func _get_visible_slot_count() -> int:
	var slot_width: int = CARD_WIDTH + CARD_GAP
	if viewport_control.size.x <= 0.0:
		return 1
	return max(1, int(floor((viewport_control.size.x + CARD_GAP) / float(slot_width))))

func _get_max_page_index() -> int:
	return _get_max_page_index_for_slots(_get_visible_slot_count())

func _get_max_page_index_for_slots(visible_slots: int) -> int:
	if visible_slots <= 0:
		return 0
	return max(0, int(ceil(float(max(_entry_count - visible_slots, 0)) / float(visible_slots))))

func _on_card_clicked(entry: Dictionary) -> void:
	entry_clicked.emit(entry)

func _on_card_hover_started(entry: Dictionary, global_rect: Rect2) -> void:
	entry_hover_started.emit(entry, global_rect)

func _on_card_hover_ended() -> void:
	entry_hover_ended.emit()

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")
