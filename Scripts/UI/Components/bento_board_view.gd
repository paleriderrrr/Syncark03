extends Control
class_name BentoBoardView

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)
signal board_drop_requested(anchor_cell: Vector2i, drag_data: Dictionary)

const GRID_WIDTH := 8
const GRID_HEIGHT := 6
const BASE_CELL_COLOR := Color(0.88, 0.78, 0.62, 1.0)
const EXPANSION_CELL_COLOR := Color(0.62, 0.82, 0.9, 1.0)
const BLOCKED_CELL_COLOR := Color(0.22, 0.24, 0.28, 1.0)
const GRID_LINE_COLOR := Color(0.16, 0.16, 0.18, 1.0)
const VALID_PREVIEW_COLOR := Color(0.44, 0.9, 0.52, 0.55)
const INVALID_PREVIEW_COLOR := Color(0.92, 0.36, 0.36, 0.55)

@export var cell_pixel_size: int = 72
@export var read_only: bool = false

var _character_state: Dictionary = {}
var _preview_cells: Array[Vector2i] = []
var _food_lookup: Dictionary = {}
var _texture_lookup: Dictionary = {}
var _hover_cells: Array[Vector2i] = []
var _hover_valid: bool = false

func _ready() -> void:
	_apply_cell_metrics()

func set_cell_pixel_size(new_size: int) -> void:
	var clamped_size: int = max(new_size, 16)
	if clamped_size == cell_pixel_size:
		return
	cell_pixel_size = clamped_size
	_apply_cell_metrics()
	queue_redraw()

func set_food_textures(texture_lookup: Dictionary) -> void:
	_texture_lookup = texture_lookup.duplicate(false)
	queue_redraw()

func refresh_board(character_state: Dictionary, preview_cells: Array[Vector2i], food_lookup: Dictionary, texture_lookup: Dictionary = {}) -> void:
	_character_state = character_state.duplicate(true)
	_preview_cells = preview_cells.duplicate()
	_food_lookup = food_lookup
	if not texture_lookup.is_empty():
		_texture_lookup = texture_lookup.duplicate(false)
	_apply_cell_metrics()
	queue_redraw()

func _apply_cell_metrics() -> void:
	custom_minimum_size = Vector2(GRID_WIDTH * cell_pixel_size, GRID_HEIGHT * cell_pixel_size)

func _draw() -> void:
	var expansion_lookup: Dictionary = {}
	for expansion in _character_state.get("placed_expansions", []):
		for expansion_cell_variant in expansion.get("cells", []):
			var expansion_cell: Vector2i = expansion_cell_variant
			expansion_lookup["%d:%d" % [expansion_cell.x, expansion_cell.y]] = "expansion"
	var active_lookup: Dictionary = ShapeUtils.cells_to_lookup(_typed_cells(_character_state.get("active_cells", [])))
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell_rect := Rect2(Vector2(x * cell_pixel_size, y * cell_pixel_size), Vector2(cell_pixel_size, cell_pixel_size))
			var key := "%d:%d" % [x, y]
			var color: Color = BLOCKED_CELL_COLOR
			if active_lookup.has(key):
				color = BASE_CELL_COLOR
				if expansion_lookup.has(key):
					color = EXPANSION_CELL_COLOR
			draw_rect(cell_rect, color, true)
			draw_rect(cell_rect, GRID_LINE_COLOR, false, 2.0)
	for item in _character_state.get("placed_foods", []):
		_draw_food_item(item)
	var overlay_color: Color = VALID_PREVIEW_COLOR if _hover_valid else INVALID_PREVIEW_COLOR
	for cell in _hover_cells:
		_draw_overlay_cell(cell, overlay_color)
	for cell in _preview_cells:
		_draw_overlay_cell(cell, VALID_PREVIEW_COLOR)

func _draw_food_item(item: Dictionary) -> void:
	var bounds: Rect2 = _get_cells_bounds(item.get("cells", []))
	var definition: FoodDefinition = _food_lookup.get(item.get("definition_id", &""), null) as FoodDefinition
	var rarity_color: Color = _color_for_rarity(definition.rarity if definition != null else &"common")
	draw_rect(bounds.grow(-6.0), rarity_color, true)
	draw_rect(bounds.grow(-6.0), Color(0.1, 0.1, 0.1, 0.85), false, 2.0)
	var texture: Texture2D = _texture_lookup.get(item.get("definition_id", &""), null) as Texture2D
	if texture != null:
		draw_texture_rect(texture, bounds.grow(-10.0), false)
	elif definition != null and not definition.display_name.is_empty():
		draw_string(get_theme_default_font(), bounds.position + Vector2(10, bounds.size.y * 0.55), definition.display_name.left(2), HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x - 20, 18, Color.BLACK)

func _draw_overlay_cell(cell: Vector2i, color: Color) -> void:
	var cell_rect := Rect2(Vector2(cell.x * cell_pixel_size, cell.y * cell_pixel_size), Vector2(cell_pixel_size, cell_pixel_size))
	draw_rect(cell_rect.grow(-4.0), color, true)

func _get_cells_bounds(cells: Array) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var min_x: int = int(cells[0].x)
	var max_x: int = int(cells[0].x)
	var min_y: int = int(cells[0].y)
	var max_y: int = int(cells[0].y)
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	return Rect2(
		Vector2(min_x * cell_pixel_size, min_y * cell_pixel_size),
		Vector2((max_x - min_x + 1) * cell_pixel_size, (max_y - min_y + 1) * cell_pixel_size)
	)

func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	if event is InputEventMouseButton and event.pressed:
		var cell: Vector2i = _position_to_cell(event.position)
		if not _is_cell_in_bounds(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			cell_clicked.emit(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cell_right_clicked.emit(cell)

func _get_drag_data(at_position: Vector2) -> Variant:
	if read_only:
		return null
	var cell: Vector2i = _position_to_cell(at_position)
	var payload: Dictionary = _build_drag_payload(cell)
	if payload.is_empty():
		return null
	set_drag_preview(_build_drag_preview(payload))
	return payload

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		_hover_cells.clear()
		queue_redraw()
		return false
	var payload: Dictionary = data
	var anchor: Vector2i = _position_to_cell(at_position)
	var cells: Array[Vector2i] = _payload_cells_for_anchor(payload, anchor)
	var valid: bool = _validate_payload_cells(payload, cells)
	_hover_cells = cells
	_hover_valid = valid
	queue_redraw()
	return valid

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var anchor: Vector2i = _position_to_cell(at_position)
	board_drop_requested.emit(anchor, data)
	_hover_cells.clear()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hover_cells.clear()
		_hover_valid = false
		queue_redraw()

func _build_drag_payload(cell: Vector2i) -> Dictionary:
	for item in _character_state.get("placed_foods", []):
		if ShapeUtils.cells_to_lookup(item.get("cells", [])).has("%d:%d" % [cell.x, cell.y]):
			var definition: FoodDefinition = _food_lookup.get(item.get("definition_id", &""), null) as FoodDefinition
			if definition == null:
				return {}
			return {
				"source": &"board_food",
				"instance_id": item["instance_id"],
				"definition_id": item["definition_id"],
				"rotation": int(item.get("rotation", 0)),
				"shape_cells": ShapeUtils.rotate_cells(definition.shape_cells, int(item.get("rotation", 0))),
				"from_cell": cell,
				"anchor": item["anchor"],
				"grab_offset": cell - item["anchor"],
			}
	for item in _character_state.get("placed_expansions", []):
		if ShapeUtils.cells_to_lookup(item.get("cells", [])).has("%d:%d" % [cell.x, cell.y]):
			return {
				"source": &"board_expansion",
				"instance_id": item["instance_id"],
				"rotation": int(item.get("rotation", 0)),
				"shape_cells": ShapeUtils.normalize_cells(_derive_shape_from_cells(item["cells"], item["anchor"])),
				"from_cell": cell,
				"anchor": item["anchor"],
				"grab_offset": cell - item["anchor"],
			}
	var base_lookup: Dictionary = ShapeUtils.cells_to_lookup(_typed_cells(_character_state.get("active_cells", [])))
	if base_lookup.has("%d:%d" % [cell.x, cell.y]):
		var expansion_cell_lookup: Dictionary = {}
		for expansion in _character_state.get("placed_expansions", []):
			for cell_variant in expansion.get("cells", []):
				var expansion_cell: Vector2i = cell_variant
				expansion_cell_lookup["%d:%d" % [expansion_cell.x, expansion_cell.y]] = true
		if not expansion_cell_lookup.has("%d:%d" % [cell.x, cell.y]):
			var base_anchor: Vector2i = _character_state.get("base_anchor", Vector2i.ZERO)
			return {
				"source": &"board_base",
				"shape_cells": _typed_cells(_character_state.get("base_shape", [])),
				"anchor": base_anchor,
				"from_cell": cell,
				"grab_offset": cell - base_anchor,
			}
	return {}

func _build_drag_preview(payload: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(90, 54)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.text = String(payload.get("definition_id", payload.get("instance_id", "拖拽")))
	panel.add_child(label)
	return panel

func _payload_cells_for_anchor(payload: Dictionary, anchor: Vector2i) -> Array[Vector2i]:
	var local_cells: Array[Vector2i] = []
	for cell_variant in payload.get("shape_cells", []):
		local_cells.append(cell_variant)
	var adjusted_anchor: Vector2i = anchor
	if payload.has("grab_offset"):
		adjusted_anchor -= payload.get("grab_offset", Vector2i.ZERO)
	return ShapeUtils.translate_cells(local_cells, adjusted_anchor)

func _validate_payload_cells(payload: Dictionary, cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	if not ShapeUtils.within_bounds(cells, GRID_WIDTH, GRID_HEIGHT):
		return false
	var active_cells: Array[Vector2i] = _typed_cells(_character_state.get("active_cells", []))
	match payload.get("source", &""):
		&"inventory", &"market_offer":
			if not ShapeUtils.contains_all(active_cells, cells):
				return false
			return not ShapeUtils.overlaps(_occupied_food_cells_except(&""), cells)
		&"board_food":
			if not ShapeUtils.contains_all(active_cells, cells):
				return false
			return not ShapeUtils.overlaps(_occupied_food_cells_except(payload.get("instance_id", &"")), cells)
		&"pending_expansion", &"market_expansion":
			if payload.get("target_character_id", _character_state.get("id", &"")) != _character_state.get("id", &""):
				return false
			if ShapeUtils.overlaps(active_cells, cells):
				return false
			return ShapeUtils.shares_edge(cells, active_cells)
		&"board_expansion":
			var active_without_self: Array[Vector2i] = active_cells.duplicate()
			var existing_cells: Array[Vector2i] = _cells_for_expansion(payload.get("instance_id", &""))
			if existing_cells.is_empty():
				return false
			for owned_cell in existing_cells:
				_remove_cell(active_without_self, owned_cell)
			if ShapeUtils.overlaps(active_without_self, cells):
				return false
			return ShapeUtils.shares_edge(cells, active_without_self)
		&"board_base":
			var delta: Vector2i = cells[0] - _character_state.get("base_anchor", Vector2i.ZERO)
			for expansion in _character_state.get("placed_expansions", []):
				var shifted_expansion_cells: Array[Vector2i] = ShapeUtils.translate_cells(_typed_cells(expansion.get("cells", [])), delta)
				if not ShapeUtils.within_bounds(shifted_expansion_cells, GRID_WIDTH, GRID_HEIGHT):
					return false
			for food in _character_state.get("placed_foods", []):
				var shifted_food_cells: Array[Vector2i] = ShapeUtils.translate_cells(_typed_cells(food.get("cells", [])), delta)
				if not ShapeUtils.within_bounds(shifted_food_cells, GRID_WIDTH, GRID_HEIGHT):
					return false
			return true
		_:
			return false

func _occupied_food_cells_except(excluded_instance_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for item in _character_state.get("placed_foods", []):
		if item.get("instance_id", &"") == excluded_instance_id:
			continue
		for cell_variant in item.get("cells", []):
			result.append(cell_variant)
	return result

func _cells_for_expansion(instance_id: StringName) -> Array[Vector2i]:
	for expansion in _character_state.get("placed_expansions", []):
		if expansion.get("instance_id", &"") == instance_id:
			return _typed_cells(expansion.get("cells", []))
	return []

func _typed_cells(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in cells:
		result.append(cell_variant)
	return result

func _derive_shape_from_cells(cells: Array, anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		result.append(cell - anchor)
	return result

func _remove_cell(cells: Array[Vector2i], target: Vector2i) -> void:
	for index in range(cells.size() - 1, -1, -1):
		if cells[index] == target:
			cells.remove_at(index)
			return

func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(position.x / cell_pixel_size), 0, GRID_WIDTH - 1),
		clampi(int(position.y / cell_pixel_size), 0, GRID_HEIGHT - 1)
	)

func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT

func _color_for_rarity(rarity: StringName) -> Color:
	match rarity:
		&"common":
			return Color(0.9, 0.9, 0.9, 0.95)
		&"rare":
			return Color(0.68, 0.83, 1.0, 0.95)
		&"epic":
			return Color(0.92, 0.68, 1.0, 0.95)
		_:
			return Color(1.0, 1.0, 1.0, 0.95)
