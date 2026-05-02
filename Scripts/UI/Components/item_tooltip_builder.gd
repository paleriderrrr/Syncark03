extends RefCounted
class_name ItemTooltipBuilder

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

static func build_tooltip_panel(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	vbox.add_child(_build_tooltip_label("\u57fa\u7840\u52a0\u6210: %s" % String(entry.get("tooltip_base_bonus", "\u65e0\u57fa\u7840\u52a0\u6210")), true))
	vbox.add_child(_build_tooltip_label("\u7279\u6b8a\u6548\u679c: %s" % String(entry.get("tooltip_special_effect", "\u65e0")), true))
	var shape_cells: Array[Vector2i] = _get_tooltip_shape_cells(entry)
	if not shape_cells.is_empty():
		vbox.add_child(_build_tooltip_label("\u5f62\u72b6", false))
		var shape_preview := TooltipShapePreview.new()
		shape_preview.set_cells(shape_cells)
		vbox.add_child(shape_preview)
	return panel

static func apply_to_labels(
	entry: Dictionary,
	title_label: Label,
	base_bonus_label: Label,
	special_effect_label: Label,
	shape_title_label: Label,
	shape_preview: TooltipShapePreview
) -> void:
	title_label.text = String(entry.get("tooltip_name", entry.get("display_name", "")))
	base_bonus_label.text = "\u57fa\u7840\u52a0\u6210: %s" % String(entry.get("tooltip_base_bonus", "\u65e0\u57fa\u7840\u52a0\u6210"))
	special_effect_label.text = "\u7279\u6b8a\u6548\u679c: %s" % String(entry.get("tooltip_special_effect", "\u65e0"))
	var shape_cells: Array[Vector2i] = _get_tooltip_shape_cells(entry)
	shape_title_label.visible = not shape_cells.is_empty()
	shape_preview.visible = not shape_cells.is_empty()
	shape_preview.set_cells(shape_cells)

static func _build_tooltip_label(text_value: String, wrap_text: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Color.WHITE)
	if wrap_text:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(TOOLTIP_BASE_WIDTH, 0.0)
		label.size.x = TOOLTIP_MAX_WIDTH
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

static func _get_tooltip_shape_cells(entry: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in entry.get("tooltip_shape_cells", []):
		if cell_variant is Vector2i:
			result.append(cell_variant)
	return result
