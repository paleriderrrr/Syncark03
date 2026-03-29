extends RefCounted
class_name ShapeUtils

static func rotate_cells(cells: Array[Vector2i], steps: int) -> Array[Vector2i]:
	var normalized_steps := posmod(steps, 4)
	var rotated: Array[Vector2i] = []
	for cell in cells:
		var current := cell
		for _i in normalized_steps:
			current = Vector2i(-current.y, current.x)
		rotated.append(current)
	return normalize_cells(rotated)

static func normalize_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return []
	var min_x := cells[0].x
	var min_y := cells[0].y
	for cell in cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(Vector2i(cell.x - min_x, cell.y - min_y))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result

static func translate_cells(cells: Array[Vector2i], anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell + anchor)
	return result

static func cells_to_lookup(cells: Array[Vector2i]) -> Dictionary:
	var result := {}
	for cell in cells:
		result["%d:%d" % [cell.x, cell.y]] = true
	return result

static func shares_edge(cells_a: Array[Vector2i], cells_b: Array[Vector2i]) -> bool:
	var lookup := cells_to_lookup(cells_b)
	for cell in cells_a:
		var neighbors := [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
		]
		for neighbor in neighbors:
			if lookup.has("%d:%d" % [neighbor.x, neighbor.y]):
				return true
	return false

static func contains_all(container_cells: Array[Vector2i], candidate_cells: Array[Vector2i]) -> bool:
	var lookup := cells_to_lookup(container_cells)
	for cell in candidate_cells:
		if not lookup.has("%d:%d" % [cell.x, cell.y]):
			return false
	return true

static func overlaps(cells_a: Array[Vector2i], cells_b: Array[Vector2i]) -> bool:
	var lookup := cells_to_lookup(cells_a)
	for cell in cells_b:
		if lookup.has("%d:%d" % [cell.x, cell.y]):
			return true
	return false

static func within_bounds(cells: Array[Vector2i], width: int, height: int) -> bool:
	for cell in cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return false
	return true
