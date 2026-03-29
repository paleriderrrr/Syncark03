extends PanelContainer
class_name ItemIconCard

signal clicked(entry: Dictionary)

const TOOLTIP_BASE_WIDTH := 150.0
const TOOLTIP_MAX_WIDTH := 240.0
const TOOLTIP_SHAPE_CELL := 14.0

class TooltipShapePreview:
	extends Control

	var cells: Array[Vector2i] = []
	var cell_size: float = TOOLTIP_SHAPE_CELL

	func set_cells(new_cells: Array[Vector2i]) -> void:
		cells = ShapeUtils.normalize_cells(new_cells)
		custom_minimum_size = _measure_size()
		queue_redraw()

	func _measure_size() -> Vector2:
		if cells.is_empty():
			return Vector2.ZERO
		var max_x: int = 0
		var max_y: int = 0
		for cell in cells:
			max_x = max(max_x, cell.x)
			max_y = max(max_y, cell.y)
		return Vector2((max_x + 1) * cell_size, (max_y + 1) * cell_size)

	func _draw() -> void:
		for cell in cells:
			var rect := Rect2(Vector2(cell.x, cell.y) * cell_size, Vector2.ONE * cell_size)
			draw_rect(rect, Color(0.92, 0.76, 0.34, 0.95))
			draw_rect(rect.grow(-1.0), Color(1.0, 0.93, 0.66, 0.95), false, 2.0)

@onready var background_rect: TextureRect = $Background
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
	background_rect.texture = background_texture
	background_rect.visible = background_texture != null
	tooltip_text = _build_tooltip_text()

func _build_tooltip_text() -> String:
	var title: String = String(entry.get("tooltip_name", entry.get("display_name", ""))).strip_edges()
	var base_bonus: String = String(entry.get("tooltip_base_bonus", "无基础加成")).strip_edges()
	var special_effect: String = String(entry.get("tooltip_special_effect", "无")).strip_edges()
	var lines: PackedStringArray = []
	if not title.is_empty():
		lines.append(title)
	lines.append("基础加成: %s" % base_bonus)
	lines.append("特殊效果: %s" % special_effect)
	if not _get_tooltip_shape_cells().is_empty():
		lines.append("形状")
	return "\n".join(lines)

func _make_custom_tooltip(_for_text: String) -> Object:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	vbox.add_child(_build_tooltip_label(String(entry.get("tooltip_name", entry.get("display_name", ""))), false))
	vbox.add_child(_build_tooltip_label("基础加成: %s" % String(entry.get("tooltip_base_bonus", "无基础加成")), true))
	vbox.add_child(_build_tooltip_label("特殊效果: %s" % String(entry.get("tooltip_special_effect", "无")), true))
	var shape_cells: Array[Vector2i] = _get_tooltip_shape_cells()
	if not shape_cells.is_empty():
		vbox.add_child(_build_tooltip_label("形状", false))
		var shape_preview := TooltipShapePreview.new()
		shape_preview.set_cells(shape_cells)
		vbox.add_child(shape_preview)
	return panel

func _build_tooltip_label(text_value: String, wrap_text: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	if wrap_text:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(TOOLTIP_BASE_WIDTH, 0.0)
		label.size.x = TOOLTIP_MAX_WIDTH
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func _get_tooltip_shape_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in entry.get("tooltip_shape_cells", []):
		if cell_variant is Vector2i:
			result.append(cell_variant)
	return result

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
