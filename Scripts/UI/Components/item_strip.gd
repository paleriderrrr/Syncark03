extends PanelContainer
class_name ItemStrip

signal entry_clicked(entry: Dictionary)

const CARD_SCENE := preload("res://Scenes/Components/item_icon_card.tscn")

@onready var title_label: Label = %TitleLabel
@onready var card_row: HBoxContainer = %CardRow

var _entry_count: int = 0
var card_drop_sources: Array[StringName] = []
var card_drop_target: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_title(text_value: String) -> void:
	title_label.text = text_value

func set_entries(entries: Array[Dictionary], texture_lookup: Dictionary) -> void:
	for child in card_row.get_children():
		child.queue_free()
	_entry_count = entries.size()
	for entry in entries:
		var card: ItemIconCard = CARD_SCENE.instantiate() as ItemIconCard
		var texture: Texture2D = texture_lookup.get(entry.get("definition_id", &""), null) as Texture2D
		card_row.add_child(card)
		card.configure(entry, texture, entry.get("drag_payload", {}), card_drop_sources, card_drop_target)
		card.clicked.connect(_on_card_clicked)

func get_entry_count() -> int:
	return _entry_count

func _on_card_clicked(entry: Dictionary) -> void:
	entry_clicked.emit(entry)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data
	return accepted_sources.has(payload.get("source", &""))

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	strip_drop_requested.emit(data)
