extends PanelContainer
class_name ItemIconCard

signal clicked(entry: Dictionary)

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel
@onready var price_label: Label = %PriceLabel

var entry: Dictionary = {}
var drag_payload: Dictionary = {}
var accepted_drop_sources: Array[StringName] = []
var drop_forward_target: Node = null
var _left_pressed: bool = false
var _drag_started: bool = false

func configure(new_entry: Dictionary, texture: Texture2D, new_drag_payload: Dictionary, new_accepted_drop_sources: Array[StringName] = [], new_drop_forward_target: Node = null) -> void:
	entry = new_entry.duplicate(true)
	drag_payload = new_drag_payload.duplicate(true)
	accepted_drop_sources = new_accepted_drop_sources.duplicate()
	drop_forward_target = new_drop_forward_target
	name_label.text = String(entry.get("display_name", ""))
	count_label.text = "x%d" % int(entry.get("count", 0))
	if entry.has("display_price"):
		price_label.text = "%d G" % int(entry["display_price"])
	elif entry.has("unit_price"):
		price_label.text = "%d G" % int(entry["unit_price"])
	else:
		price_label.text = ""
	icon_rect.texture = texture
	icon_rect.visible = texture != null

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
	_drag_started = true
	_left_pressed = false
	_ui_sfx().play_pickup()
	var preview: Control = _build_preview()
	set_drag_preview(preview)
	return drag_payload.duplicate(true)

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
