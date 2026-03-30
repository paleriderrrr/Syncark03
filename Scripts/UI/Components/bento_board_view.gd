extends Control
class_name BentoBoardView

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)
signal board_drop_requested(anchor_cell: Vector2i, drag_data: Dictionary)
signal hover_food_changed(item: Dictionary, global_rect: Rect2)
signal hover_food_cleared

const GRID_WIDTH := 8
const GRID_HEIGHT := 6
const BOARD_RANGE_BACKGROUND_COLOR := Color(1.0, 1.0, 1.0, 0.085)
const GRID_CELL_COLOR := Color(1.0, 1.0, 1.0, 0.02)
const VALID_PREVIEW_COLOR := Color(0.44, 0.9, 0.52, 0.55)
const INVALID_PREVIEW_COLOR := Color(0.92, 0.36, 0.36, 0.55)
const FOOD_BACKGROUND_ALPHA := 0.18
const CELL_CORNER_RADIUS := 14.0
const BOARD_RANGE_CORNER_RADIUS := 24.0
const BOARD_RANGE_INSET := 6.0
const FOOD_TEXTURE_INSET_RATIO := 0.08
const FOOD_TEXTURE_INSET_MIN := 4.0

@export var cell_pixel_size: int = 72
@export var read_only: bool = false
@export var allow_base_drag: bool = true

var _character_state: Dictionary = {}
var _preview_cells: Array[Vector2i] = []
var _food_lookup: Dictionary = {}
var _texture_lookup: Dictionary = {}
var _food_board_texture_lookup: Dictionary = {}
var _base_lunchbox_textures: Dictionary = {}
var _expansion_lunchbox_textures: Dictionary = {}
var _hover_cells: Array[Vector2i] = []
var _hover_valid: bool = false
var _hovered_food_instance_id: StringName = &""

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

func set_food_board_textures(texture_lookup: Dictionary) -> void:
	_food_board_texture_lookup = texture_lookup.duplicate(true)
	queue_redraw()

func set_lunchbox_textures(base_lookup: Dictionary, expansion_lookup: Dictionary) -> void:
	_base_lunchbox_textures = base_lookup.duplicate(false)
	_expansion_lunchbox_textures = expansion_lookup.duplicate(true)
	queue_redraw()

func has_base_lunchbox_texture(character_id: StringName) -> bool:
	return _base_lunchbox_textures.has(character_id)

func has_expansion_lunchbox_texture(character_id: StringName, size_key: StringName) -> bool:
	var role_lookup: Dictionary = _expansion_lunchbox_textures.get(character_id, {})
	return role_lookup.has(size_key)

func refresh_board(character_state: Dictionary, preview_cells: Array[Vector2i], food_lookup: Dictionary, texture_lookup: Dictionary = {}) -> void:
	_character_state = character_state.duplicate(true)
	_preview_cells = preview_cells.duplicate()
	_food_lookup = food_lookup
	_clear_food_hover()
	if not texture_lookup.is_empty():
		_texture_lookup = texture_lookup.duplicate(false)
	_apply_cell_metrics()
	queue_redraw()

func _apply_cell_metrics() -> void:
	custom_minimum_size = Vector2(GRID_WIDTH * cell_pixel_size, GRID_HEIGHT * cell_pixel_size)

func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * cell_pixel_size, GRID_HEIGHT * cell_pixel_size))
	_draw_board_range_background(board_rect)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell_rect := Rect2(Vector2(x * cell_pixel_size, y * cell_pixel_size), Vector2(cell_pixel_size, cell_pixel_size))
			_draw_rounded_cell(cell_rect, GRID_CELL_COLOR)
	var character_id: StringName = _character_state.get("id", &"")
	_draw_base_lunchbox(character_id)
	for expansion in _character_state.get("placed_expansions", []):
		_draw_expansion_lunchbox(character_id, expansion)
	for item in _character_state.get("placed_foods", []):
		_draw_food_item(item)
	var overlay_color: Color = VALID_PREVIEW_COLOR if _hover_valid else INVALID_PREVIEW_COLOR
	for cell in _hover_cells:
		_draw_overlay_cell(cell, overlay_color)
	for cell in _preview_cells:
		_draw_overlay_cell(cell, VALID_PREVIEW_COLOR)

func _draw_food_item(item: Dictionary) -> void:
	var cells: Array[Vector2i] = _typed_cells(item.get("cells", []))
	var bounds: Rect2 = _get_cells_bounds(cells)
	var definition: FoodDefinition = _food_lookup.get(item.get("definition_id", &""), null) as FoodDefinition
	var rarity_color: Color = _color_for_rarity(definition.rarity if definition != null else &"common")
	_draw_food_shape_background(cells, rarity_color)
	var rotation_lookup: Dictionary = _food_board_texture_lookup.get(item.get("definition_id", &""), {})
	var baked_texture: Texture2D = rotation_lookup.get(posmod(int(item.get("rotation", 0)), 4), null) as Texture2D
	var texture_rect: Rect2 = compute_food_texture_draw_rect(bounds, cell_pixel_size)
	if baked_texture != null:
		draw_texture_rect(baked_texture, texture_rect, false)
	elif _texture_lookup.has(item.get("definition_id", &"")):
		draw_texture_rect(_texture_lookup[item.get("definition_id", &"")], texture_rect, false)
	elif definition != null and not definition.display_name.is_empty():
			draw_string(get_theme_default_font(), bounds.position + Vector2(10, bounds.size.y * 0.55), definition.display_name.left(2), HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x - 20, 18, Color.BLACK)

func _draw_board_range_background(board_rect: Rect2) -> void:
	_draw_rounded_rect_with_radius(board_rect.grow(-BOARD_RANGE_INSET), BOARD_RANGE_BACKGROUND_COLOR, BOARD_RANGE_CORNER_RADIUS)

func _draw_base_lunchbox(character_id: StringName) -> void:
	var texture: Texture2D = _base_lunchbox_textures.get(character_id, null) as Texture2D
	if texture == null:
		return
	var base_cells: Array[Vector2i] = ShapeUtils.translate_cells(_typed_cells(_character_state.get("base_shape", [])), _character_state.get("base_anchor", Vector2i.ZERO))
	var bounds: Rect2 = _get_cells_bounds(base_cells)
	draw_texture_rect(texture, bounds, false)

func _draw_expansion_lunchbox(character_id: StringName, expansion: Dictionary) -> void:
	var role_lookup: Dictionary = _expansion_lunchbox_textures.get(character_id, {})
	if role_lookup.is_empty():
		return
	var size_key: StringName = _size_key_for_cells(expansion.get("cells", []))
	var texture: Texture2D = role_lookup.get(size_key, null) as Texture2D
	if texture == null:
		return
	draw_texture_rect(texture, _get_cells_bounds(expansion.get("cells", [])), false)

func _size_key_for_cells(cells: Array) -> StringName:
	if cells.is_empty():
		return &""
	var bounds: Rect2 = _get_cells_bounds(cells)
	var width_cells: int = int(round(bounds.size.x / float(cell_pixel_size)))
	var height_cells: int = int(round(bounds.size.y / float(cell_pixel_size)))
	return StringName("%dx%d" % [width_cells, height_cells])

func _draw_overlay_cell(cell: Vector2i, color: Color) -> void:
	var cell_rect := Rect2(Vector2(cell.x * cell_pixel_size, cell.y * cell_pixel_size), Vector2(cell_pixel_size, cell_pixel_size))
	_draw_rounded_cell(cell_rect.grow(-4.0), color)

func _draw_food_shape_background(cells: Array[Vector2i], rarity_color: Color) -> void:
	for cell in cells:
		var rect: Rect2 = _food_cell_rect(cell)
		var fill_color := rarity_color
		fill_color.a = FOOD_BACKGROUND_ALPHA
		_draw_rounded_cell(rect, fill_color)

func _food_cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell.x * cell_pixel_size, cell.y * cell_pixel_size), Vector2(cell_pixel_size, cell_pixel_size))

func _draw_rounded_cell(rect: Rect2, color: Color) -> void:
	_draw_rounded_rect_with_radius(rect, color, CELL_CORNER_RADIUS)

func _draw_rounded_rect_with_radius(rect: Rect2, color: Color, corner_radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.draw_center = true
	style.set_corner_radius_all(int(corner_radius))
	draw_style_box(style, rect)

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

static func compute_food_cover_source_region(texture_size: Vector2, target_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2(Vector2.ZERO, texture_size)
	var texture_ratio: float = texture_size.x / texture_size.y
	var target_ratio: float = target_size.x / target_size.y
	if texture_ratio > target_ratio:
		var crop_width: float = texture_size.y * target_ratio
		var crop_x: float = (texture_size.x - crop_width) * 0.5
		return Rect2(Vector2(crop_x, 0.0), Vector2(crop_width, texture_size.y))
	var crop_height: float = texture_size.x / target_ratio
	var crop_y: float = (texture_size.y - crop_height) * 0.5
	return Rect2(Vector2(0.0, crop_y), Vector2(texture_size.x, crop_height))

static func compute_food_cell_source_region(cell: Vector2i, cells: Array[Vector2i], source_region: Rect2) -> Rect2:
	if cells.is_empty():
		return source_region
	var min_x: int = cells[0].x
	var max_x: int = cells[0].x
	var min_y: int = cells[0].y
	var max_y: int = cells[0].y
	for occupied_cell in cells:
		min_x = min(min_x, occupied_cell.x)
		max_x = max(max_x, occupied_cell.x)
		min_y = min(min_y, occupied_cell.y)
		max_y = max(max_y, occupied_cell.y)
	var width_cells: float = float(max_x - min_x + 1)
	var height_cells: float = float(max_y - min_y + 1)
	var relative_x: float = float(cell.x - min_x) / width_cells
	var relative_y: float = float(cell.y - min_y) / height_cells
	var width_fraction: float = 1.0 / width_cells
	var height_fraction: float = 1.0 / height_cells
	return Rect2(
		Vector2(
			source_region.position.x + source_region.size.x * relative_x,
			source_region.position.y + source_region.size.y * relative_y
		),
		Vector2(
			source_region.size.x * width_fraction,
			source_region.size.y * height_fraction
		)
	)

static func compute_food_texture_draw_rect(bounds: Rect2, cell_size: int) -> Rect2:
	var inset: float = max(FOOD_TEXTURE_INSET_MIN, round(float(cell_size) * FOOD_TEXTURE_INSET_RATIO))
	var max_inset_x: float = max(0.0, (bounds.size.x - 1.0) * 0.5)
	var max_inset_y: float = max(0.0, (bounds.size.y - 1.0) * 0.5)
	var clamped_inset: float = min(inset, min(max_inset_x, max_inset_y))
	return bounds.grow_individual(-clamped_inset, -clamped_inset, -clamped_inset, -clamped_inset)

func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	if event is InputEventMouseMotion:
		_update_food_hover(event.position)
		return
	if event is InputEventMouseButton and event.pressed:
		var cell: Vector2i = _position_to_cell(event.position)
		if not _is_cell_in_bounds(cell):
			_clear_food_hover()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			cell_clicked.emit(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_clear_food_hover()
			cell_right_clicked.emit(cell)

func _get_drag_data(at_position: Vector2) -> Variant:
	if read_only:
		return null
	var cell: Vector2i = _position_to_cell(at_position)
	var payload: Dictionary = _build_drag_payload(cell)
	if payload.is_empty():
		return null
	_clear_food_hover()
	_ui_sfx().play_pickup()
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
		_clear_food_hover()
	elif what == NOTIFICATION_DRAG_BEGIN:
		_clear_food_hover()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_clear_food_hover()

func _build_drag_payload(cell: Vector2i) -> Dictionary:
	for item in _character_state.get("placed_foods", []):
		if ShapeUtils.cells_to_lookup(item.get("cells", [])).has("%d:%d" % [cell.x, cell.y]):
			var definition_id: StringName = item.get("definition_id", &"")
			if not _food_lookup.has(definition_id):
				return {}
			_run_state().begin_board_food_action(cell)
			return {
				"source": &"board_food",
				"instance_id": item["instance_id"],
				"definition_id": definition_id,
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
	if allow_base_drag and base_lookup.has("%d:%d" % [cell.x, cell.y]):
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
	var local_cells: Array[Vector2i] = _resolve_payload_shape_cells(payload)
	var adjusted_anchor: Vector2i = anchor
	if payload.has("grab_offset"):
		adjusted_anchor -= payload.get("grab_offset", Vector2i.ZERO)
	return ShapeUtils.translate_cells(local_cells, adjusted_anchor)

func _resolve_payload_shape_cells(payload: Dictionary) -> Array[Vector2i]:
	var run_state: Node = _run_state()
	if _payload_uses_selected_item(payload, run_state):
		return run_state.get_selected_item_cells()
	var local_cells: Array[Vector2i] = []
	for cell_variant in payload.get("shape_cells", []):
		var cell: Vector2i = cell_variant
		local_cells.append(cell)
	return local_cells

func _payload_uses_selected_item(payload: Dictionary, run_state: Node) -> bool:
	if run_state.selected_item.is_empty():
		return false
	var selected_source: StringName = run_state.selected_item.get("source", &"")
	var payload_source: StringName = payload.get("source", &"")
	if selected_source != payload_source:
		return false
	match payload_source:
		&"inventory":
			var inventory_item: Dictionary = run_state._find_inventory_item(run_state.selected_item.get("instance_id", &""))
			return inventory_item.get("definition_id", &"") == payload.get("definition_id", &"")
		&"market_offer", &"market_expansion":
			return run_state.selected_item.get("offer_id", &"") == payload.get("offer_id", &"")
		&"pending_expansion":
			return run_state.selected_item.get("instance_id", &"") == payload.get("instance_id", &"")
		&"board_food":
			return run_state.selected_item.get("instance_id", &"") == payload.get("instance_id", &"")
		_:
			return false

func _validate_payload_cells(payload: Dictionary, cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	if not ShapeUtils.within_bounds(cells, GRID_WIDTH, GRID_HEIGHT):
		return false
	var active_cells: Array[Vector2i] = _typed_cells(_character_state.get("active_cells", []))
	match payload.get("source", &""):
		&"inventory", &"market_offer", &"lab_catalog":
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

func _update_food_hover(position: Vector2) -> void:
	var cell: Vector2i = _position_to_cell(position)
	if not _is_cell_in_bounds(cell):
		_clear_food_hover()
		return
	var item: Dictionary = _find_food_at_cell(cell)
	if item.is_empty():
		_clear_food_hover()
		return
	var instance_id: StringName = item.get("instance_id", &"")
	if _hovered_food_instance_id == instance_id:
		return
	_hovered_food_instance_id = instance_id
	var local_rect: Rect2 = _get_cells_bounds(item.get("cells", []))
	var global_rect := Rect2(get_global_position() + local_rect.position, local_rect.size)
	hover_food_changed.emit(item.duplicate(true), global_rect)

func _clear_food_hover() -> void:
	if _hovered_food_instance_id == &"":
		return
	_hovered_food_instance_id = &""
	hover_food_cleared.emit()

func _find_food_at_cell(cell: Vector2i) -> Dictionary:
	var key: String = "%d:%d" % [cell.x, cell.y]
	for item_variant in _character_state.get("placed_foods", []):
		var item: Dictionary = item_variant
		if ShapeUtils.cells_to_lookup(item.get("cells", [])).has(key):
			return item
	return {}

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

func get_food_background_alpha() -> float:
	return FOOD_BACKGROUND_ALPHA

func get_board_range_background_alpha() -> float:
	return BOARD_RANGE_BACKGROUND_COLOR.a

func get_grid_background_alpha() -> float:
	return GRID_CELL_COLOR.a

func get_cell_corner_radius() -> float:
	return CELL_CORNER_RADIUS

func draws_food_outline() -> bool:
	return false

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _run_state() -> Node:
	return get_node("/root/RunState")
