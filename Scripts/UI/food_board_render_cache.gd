extends RefCounted
class_name FoodBoardRenderCache

const ANGLE_SEARCH_STEPS := 360
const STRETCH_SEARCH_STEPS := 20

var _raw_textures: Dictionary = {}
var _food_lookup: Dictionary = {}
var _cache: Dictionary = {}
var _cached_cell_pixel_size: int = -1

func prime(texture_lookup: Dictionary, food_lookup: Dictionary, cell_pixel_size: int) -> void:
	_raw_textures = texture_lookup.duplicate(false)
	_food_lookup = food_lookup.duplicate(false)
	ensure_cell_size(cell_pixel_size)

func ensure_cell_size(cell_pixel_size: int) -> void:
	var target_size: int = max(cell_pixel_size, 1)
	if _cached_cell_pixel_size == target_size and not _cache.is_empty():
		return
	_cached_cell_pixel_size = target_size
	_rebuild_cache()

func get_texture(definition_id: StringName, rotation: int, cell_pixel_size: int = -1) -> Texture2D:
	if cell_pixel_size > 0:
		ensure_cell_size(cell_pixel_size)
	if not _cache.has(definition_id):
		return null
	var rotation_lookup: Dictionary = _cache[definition_id]
	return rotation_lookup.get(posmod(rotation, 4), null) as Texture2D

func _rebuild_cache() -> void:
	_cache.clear()
	for definition_id_variant in _food_lookup.keys():
		var definition_id: StringName = definition_id_variant
		var definition: FoodDefinition = _food_lookup[definition_id] as FoodDefinition
		var source_texture: Texture2D = _raw_textures.get(definition_id, null) as Texture2D
		if definition == null or source_texture == null:
			continue
		var rotation_lookup: Dictionary = {}
		for rotation in range(4):
			rotation_lookup[rotation] = _bake_shape_texture(source_texture, definition.shape_cells, rotation, _cached_cell_pixel_size)
		_cache[definition_id] = rotation_lookup

func _bake_shape_texture(source_texture: Texture2D, base_shape_cells: Array[Vector2i], rotation: int, cell_pixel_size: int) -> Texture2D:
	var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(base_shape_cells, rotation)
	var bounds: Rect2i = _get_shape_bounds(rotated_cells)
	var output_size := Vector2i(bounds.size.x * cell_pixel_size, bounds.size.y * cell_pixel_size)
	if output_size.x <= 0 or output_size.y <= 0:
		return null
	var source_image: Image = source_texture.get_image()
	if source_image == null:
		return null
	var visible_region: Rect2 = _compute_visible_alpha_region(source_image)
	var solution: Dictionary = compute_best_solution_for_shape(visible_region.size, base_shape_cells, rotation, cell_pixel_size)
	var target_rect: Rect2 = solution.get("dest_rect", Rect2(Vector2.ZERO, Vector2(output_size)))
	var rotation_radians: float = float(solution.get("rotation_radians", 0.0))
	var scale_x: float = float(solution.get("scale_x", 1.0))
	var scale_y: float = float(solution.get("scale_y", 1.0))
	var contain_scale: float = float(solution.get("contain_scale", 1.0))
	var target_center := target_rect.position + target_rect.size * 0.5
	var source_center := visible_region.position + visible_region.size * 0.5
	var baked := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	baked.fill(Color(0.0, 0.0, 0.0, 0.0))
	for cell in rotated_cells:
		var local_cell := Vector2i(cell.x - bounds.position.x, cell.y - bounds.position.y)
		for local_y in range(cell_pixel_size):
			var pixel_y: int = local_cell.y * cell_pixel_size + local_y
			for local_x in range(cell_pixel_size):
				var pixel_x: int = local_cell.x * cell_pixel_size + local_x
				var pixel_position := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
				if not target_rect.has_point(pixel_position):
					continue
				var transformed: Vector2 = (pixel_position - target_center) / max(contain_scale, 0.0001)
				var unrotated: Vector2 = transformed.rotated(-rotation_radians)
				var sample_x_float: float = source_center.x + unrotated.x / max(scale_x, 0.0001)
				var sample_y_float: float = source_center.y + unrotated.y / max(scale_y, 0.0001)
				if sample_x_float < visible_region.position.x or sample_x_float >= visible_region.end.x or sample_y_float < visible_region.position.y or sample_y_float >= visible_region.end.y:
					continue
				var sample_x: int = clampi(int(floor(sample_x_float)), 0, source_image.get_width() - 1)
				var sample_y: int = clampi(int(floor(sample_y_float)), 0, source_image.get_height() - 1)
				baked.set_pixel(pixel_x, pixel_y, source_image.get_pixel(sample_x, sample_y))
	return ImageTexture.create_from_image(baked)

func compute_best_solution_for_shape(source_size: Vector2, base_shape_cells: Array[Vector2i], rotation: int, cell_pixel_size: int, stretch_limit: float = 0.2) -> Dictionary:
	var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(base_shape_cells, rotation)
	var bounds: Rect2i = _get_shape_bounds(rotated_cells)
	var target_size := Vector2(bounds.size.x * cell_pixel_size, bounds.size.y * cell_pixel_size)
	if not _is_irregular_shape(rotated_cells) or posmod(rotation, 4) != 0:
		var regular_solution: Dictionary = compute_best_zero_crop_solution(source_size, target_size, stretch_limit)
		regular_solution["fits_occupied_mask"] = true
		return regular_solution
	return _compute_best_masked_zero_crop_solution(source_size, target_size, rotated_cells, cell_pixel_size, stretch_limit)

func solution_intersects_empty_cells(solution: Dictionary, base_shape_cells: Array[Vector2i], rotation: int, cell_pixel_size: int) -> bool:
	var rotated_cells: Array[Vector2i] = ShapeUtils.rotate_cells(base_shape_cells, rotation)
	var empty_rects: Array[Rect2] = _build_empty_cell_rects(rotated_cells, cell_pixel_size)
	if empty_rects.is_empty():
		return false
	var target_rect: Rect2 = solution.get("dest_rect", Rect2())
	var rotation_radians: float = float(solution.get("rotation_radians", 0.0))
	return _rotated_rect_intersects_any_empty_cell(target_rect, rotation_radians, empty_rects)

func compute_zero_crop_dest_rect(source_size: Vector2, target_size: Vector2, stretch_limit: float = 0.2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2(Vector2.ZERO, target_size)
	var low: float = max(0.0, 1.0 - stretch_limit)
	var high: float = 1.0 + stretch_limit
	var source_ratio: float = source_size.x / source_size.y
	var target_ratio: float = target_size.x / target_size.y
	var ratio_low: float = source_ratio * (low / high)
	var ratio_high: float = source_ratio * (high / low)
	var solved_ratio: float = clamp(target_ratio, ratio_low, ratio_high)
	var ratio_multiplier: float = solved_ratio / source_ratio
	var stretch := _resolve_bounded_stretch_pair(ratio_multiplier, low, high)
	var adjusted_size := Vector2(source_size.x * stretch.x, source_size.y * stretch.y)
	var contain_scale: float = min(target_size.x / adjusted_size.x, target_size.y / adjusted_size.y)
	var fitted_size := adjusted_size * contain_scale
	var fitted_position := (target_size - fitted_size) * 0.5
	return Rect2(fitted_position, fitted_size)

func compute_best_zero_crop_solution(source_size: Vector2, target_size: Vector2, stretch_limit: float = 0.2) -> Dictionary:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return {
			"rotation_radians": 0.0,
			"scale_x": 1.0,
			"scale_y": 1.0,
			"contain_scale": 1.0,
			"dest_rect": Rect2(Vector2.ZERO, target_size),
		}
	var low: float = max(0.0, 1.0 - stretch_limit)
	var high: float = 1.0 + stretch_limit
	var best_solution := {
		"rotation_radians": 0.0,
		"scale_x": 1.0,
		"scale_y": 1.0,
		"contain_scale": 1.0,
		"dest_rect": compute_zero_crop_dest_rect(source_size, target_size, stretch_limit),
	}
	var best_subject_area: float = -1.0
	var best_bbox_area: float = -1.0
	var best_distortion: float = INF
	for angle_step in range(ANGLE_SEARCH_STEPS + 1):
		var angle: float = (PI * 0.5) * (float(angle_step) / float(ANGLE_SEARCH_STEPS))
		var cosine: float = absf(cos(angle))
		var sine: float = absf(sin(angle))
		for stretch_x_step in range(STRETCH_SEARCH_STEPS + 1):
			var scale_x: float = lerpf(low, high, float(stretch_x_step) / float(STRETCH_SEARCH_STEPS))
			for stretch_y_step in range(STRETCH_SEARCH_STEPS + 1):
				var scale_y: float = lerpf(low, high, float(stretch_y_step) / float(STRETCH_SEARCH_STEPS))
				var rotated_width: float = source_size.x * scale_x * cosine + source_size.y * scale_y * sine
				var rotated_height: float = source_size.x * scale_x * sine + source_size.y * scale_y * cosine
				if rotated_width <= 0.0 or rotated_height <= 0.0:
					continue
				var contain_scale: float = min(target_size.x / rotated_width, target_size.y / rotated_height)
				var fitted_size := Vector2(rotated_width, rotated_height) * contain_scale
				var subject_area: float = source_size.x * source_size.y * scale_x * scale_y * contain_scale * contain_scale
				var bbox_area: float = fitted_size.x * fitted_size.y
				var distortion: float = absf(scale_x - 1.0) + absf(scale_y - 1.0)
				if subject_area > best_subject_area + 0.0001 \
				or (is_equal_approx(subject_area, best_subject_area) and bbox_area > best_bbox_area + 0.0001) \
				or (is_equal_approx(subject_area, best_subject_area) and is_equal_approx(bbox_area, best_bbox_area) and distortion < best_distortion - 0.0001):
					best_subject_area = subject_area
					best_bbox_area = bbox_area
					best_distortion = distortion
					best_solution = {
						"rotation_radians": angle,
						"scale_x": scale_x,
						"scale_y": scale_y,
						"contain_scale": contain_scale,
						"dest_rect": Rect2((target_size - fitted_size) * 0.5, fitted_size),
					}
	return best_solution

func _compute_best_masked_zero_crop_solution(source_size: Vector2, target_size: Vector2, shape_cells: Array[Vector2i], cell_pixel_size: int, stretch_limit: float = 0.2) -> Dictionary:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return {
			"rotation_radians": 0.0,
			"scale_x": 1.0,
			"scale_y": 1.0,
			"contain_scale": 1.0,
			"dest_rect": Rect2(Vector2.ZERO, target_size),
			"fits_occupied_mask": false,
		}
	var empty_rects: Array[Rect2] = _build_empty_cell_rects(shape_cells, cell_pixel_size)
	if empty_rects.is_empty():
		var trivial_solution: Dictionary = compute_best_zero_crop_solution(source_size, target_size, stretch_limit)
		trivial_solution["fits_occupied_mask"] = true
		return trivial_solution
	var low: float = max(0.0, 1.0 - stretch_limit)
	var high: float = 1.0 + stretch_limit
	var best_solution := {
		"rotation_radians": 0.0,
		"scale_x": 1.0,
		"scale_y": 1.0,
		"contain_scale": 0.0,
		"dest_rect": Rect2(target_size * 0.5, Vector2.ZERO),
		"fits_occupied_mask": false,
	}
	var best_subject_area: float = -1.0
	var best_bbox_area: float = -1.0
	var best_distortion: float = INF
	for angle_step in range(ANGLE_SEARCH_STEPS + 1):
		var angle: float = (PI * 0.5) * (float(angle_step) / float(ANGLE_SEARCH_STEPS))
		var cosine: float = absf(cos(angle))
		var sine: float = absf(sin(angle))
		for stretch_x_step in range(STRETCH_SEARCH_STEPS + 1):
			var scale_x: float = lerpf(low, high, float(stretch_x_step) / float(STRETCH_SEARCH_STEPS))
			for stretch_y_step in range(STRETCH_SEARCH_STEPS + 1):
				var scale_y: float = lerpf(low, high, float(stretch_y_step) / float(STRETCH_SEARCH_STEPS))
				var rotated_width: float = source_size.x * scale_x * cosine + source_size.y * scale_y * sine
				var rotated_height: float = source_size.x * scale_x * sine + source_size.y * scale_y * cosine
				if rotated_width <= 0.0 or rotated_height <= 0.0:
					continue
				var bbox_contain_scale: float = min(target_size.x / rotated_width, target_size.y / rotated_height)
				var contain_scale: float = _find_max_masked_contain_scale(rotated_width, rotated_height, angle, target_size, empty_rects, bbox_contain_scale)
				if contain_scale <= 0.0001:
					continue
				var fitted_size := Vector2(rotated_width, rotated_height) * contain_scale
				var subject_area: float = source_size.x * source_size.y * scale_x * scale_y * contain_scale * contain_scale
				var bbox_area: float = fitted_size.x * fitted_size.y
				var distortion: float = absf(scale_x - 1.0) + absf(scale_y - 1.0)
				if subject_area > best_subject_area + 0.0001 \
				or (is_equal_approx(subject_area, best_subject_area) and bbox_area > best_bbox_area + 0.0001) \
				or (is_equal_approx(subject_area, best_subject_area) and is_equal_approx(bbox_area, best_bbox_area) and distortion < best_distortion - 0.0001):
					best_subject_area = subject_area
					best_bbox_area = bbox_area
					best_distortion = distortion
					best_solution = {
						"rotation_radians": angle,
						"scale_x": scale_x,
						"scale_y": scale_y,
						"contain_scale": contain_scale,
						"dest_rect": Rect2((target_size - fitted_size) * 0.5, fitted_size),
						"fits_occupied_mask": true,
					}
	return best_solution

func _find_max_masked_contain_scale(rotated_width: float, rotated_height: float, angle: float, target_size: Vector2, empty_rects: Array[Rect2], max_scale: float) -> float:
	if max_scale <= 0.0:
		return 0.0
	var best_scale: float = 0.0
	var low: float = 0.0
	var high: float = max_scale
	for _step in range(20):
		var mid: float = (low + high) * 0.5
		var fitted_size := Vector2(rotated_width, rotated_height) * mid
		var dest_rect := Rect2((target_size - fitted_size) * 0.5, fitted_size)
		if _rotated_rect_intersects_any_empty_cell(dest_rect, angle, empty_rects):
			high = mid
		else:
			best_scale = mid
			low = mid
	return best_scale

func _is_irregular_shape(cells: Array[Vector2i]) -> bool:
	var bounds: Rect2i = _get_shape_bounds(cells)
	return cells.size() != bounds.size.x * bounds.size.y

func _build_empty_cell_rects(cells: Array[Vector2i], cell_pixel_size: int) -> Array[Rect2]:
	var bounds: Rect2i = _get_shape_bounds(cells)
	var occupied_lookup := {}
	for cell in cells:
		var local_cell := Vector2i(cell.x - bounds.position.x, cell.y - bounds.position.y)
		occupied_lookup["%d:%d" % [local_cell.x, local_cell.y]] = true
	var empty_rects: Array[Rect2] = []
	for cell_y in range(bounds.size.y):
		for cell_x in range(bounds.size.x):
			if occupied_lookup.has("%d:%d" % [cell_x, cell_y]):
				continue
			empty_rects.append(Rect2(
				Vector2(cell_x * cell_pixel_size, cell_y * cell_pixel_size),
				Vector2(cell_pixel_size, cell_pixel_size)
			))
	return empty_rects

func _rotated_rect_intersects_any_empty_cell(dest_rect: Rect2, angle: float, empty_rects: Array[Rect2]) -> bool:
	for empty_rect in empty_rects:
		if _rotated_rect_intersects_axis_aligned_rect(dest_rect, angle, empty_rect):
			return true
	return false

func _rotated_rect_intersects_axis_aligned_rect(rotated_rect: Rect2, angle: float, axis_rect: Rect2) -> bool:
	if rotated_rect.size.x <= 0.0 or rotated_rect.size.y <= 0.0 or axis_rect.size.x <= 0.0 or axis_rect.size.y <= 0.0:
		return false
	var rotated_points: Array[Vector2] = _build_rotated_rect_points(rotated_rect, angle)
	var axis_points: Array[Vector2] = [
		axis_rect.position,
		axis_rect.position + Vector2(axis_rect.size.x, 0.0),
		axis_rect.position + axis_rect.size,
		axis_rect.position + Vector2(0.0, axis_rect.size.y),
	]
	var axes: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.DOWN,
		Vector2(cos(angle), sin(angle)).normalized(),
		Vector2(-sin(angle), cos(angle)).normalized(),
	]
	for axis in axes:
		var rotated_projection: Vector2 = _project_points_onto_axis(rotated_points, axis)
		var axis_projection: Vector2 = _project_points_onto_axis(axis_points, axis)
		if rotated_projection.y <= axis_projection.x + 0.001 or axis_projection.y <= rotated_projection.x + 0.001:
			return false
	return true

func _build_rotated_rect_points(rect: Rect2, angle: float) -> Array[Vector2]:
	var center := rect.position + rect.size * 0.5
	var half_size := rect.size * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points: Array[Vector2] = []
	for corner in corners:
		points.append(center + corner.rotated(angle))
	return points

func _project_points_onto_axis(points: Array[Vector2], axis: Vector2) -> Vector2:
	var min_projection: float = points[0].dot(axis)
	var max_projection: float = min_projection
	for index in range(1, points.size()):
		var projection: float = points[index].dot(axis)
		min_projection = min(min_projection, projection)
		max_projection = max(max_projection, projection)
	return Vector2(min_projection, max_projection)

func _resolve_bounded_stretch_pair(ratio_multiplier: float, low: float, high: float) -> Vector2:
	if ratio_multiplier <= 0.0:
		return Vector2.ONE
	var symmetric_x: float = sqrt(ratio_multiplier)
	var symmetric_y: float = 1.0 / symmetric_x
	if symmetric_x >= low and symmetric_x <= high and symmetric_y >= low and symmetric_y <= high:
		return Vector2(symmetric_x, symmetric_y)
	if ratio_multiplier > 1.0:
		return Vector2(high, high / ratio_multiplier)
	return Vector2(high * ratio_multiplier, high)

func _get_shape_bounds(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var min_x: int = cells[0].x
	var max_x: int = cells[0].x
	var min_y: int = cells[0].y
	var max_y: int = cells[0].y
	for cell in cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _compute_visible_alpha_region(image: Image, alpha_threshold: float = 0.02) -> Rect2:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0:
		return Rect2()
	var min_x: int = width
	var max_x: int = -1
	var min_y: int = height
	var max_y: int = -1
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a <= alpha_threshold:
				continue
			min_x = min(min_x, x)
			max_x = max(max_x, x)
			min_y = min(min_y, y)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, Vector2(width, height))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))
