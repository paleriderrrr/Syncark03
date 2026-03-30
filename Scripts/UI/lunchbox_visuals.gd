extends RefCounted
class_name LunchboxVisuals

const GENERATED_DIR := "res://Art/Lunchbox/Generated"
const BASE_SIZE_KEY := &"3x3"
const EXPANSION_SIZE_KEYS: Array[StringName] = [&"1x1", &"2x2", &"1x4", &"2x4"]
const ROLE_IDS: Array[StringName] = [&"warrior", &"hunter", &"mage"]

static var _role_base_texture_lookup_cache: Dictionary = {}
static var _role_expansion_texture_lookup_cache: Dictionary = {}
static var _source_texture_cache: Dictionary = {}
static var _rotated_texture_cache: Dictionary = {}

static func build_role_base_texture_lookup() -> Dictionary:
	if not _role_base_texture_lookup_cache.is_empty():
		return _role_base_texture_lookup_cache
	var lookup: Dictionary = {}
	for role_id in ROLE_IDS:
		var texture: Texture2D = _load_generated_texture(role_id, BASE_SIZE_KEY)
		if texture != null:
			lookup[role_id] = texture
	_role_base_texture_lookup_cache = lookup
	return _role_base_texture_lookup_cache

static func build_role_expansion_texture_lookup() -> Dictionary:
	if not _role_expansion_texture_lookup_cache.is_empty():
		return _role_expansion_texture_lookup_cache
	var lookup: Dictionary = {}
	for role_id in ROLE_IDS:
		var role_lookup: Dictionary = {}
		for size_key in EXPANSION_SIZE_KEYS:
			var texture: Texture2D = _load_generated_texture(role_id, size_key)
			if texture == null:
				continue
			role_lookup[size_key] = texture
			if size_key == &"1x4":
				role_lookup[&"4x1"] = _build_rotated_texture(texture)
			elif size_key == &"2x4":
				role_lookup[&"4x2"] = _build_rotated_texture(texture)
		if not role_lookup.is_empty():
			lookup[role_id] = role_lookup
	_role_expansion_texture_lookup_cache = lookup
	return _role_expansion_texture_lookup_cache

static func _load_generated_texture(role_id: StringName, size_key: StringName) -> Texture2D:
	var path := "%s/%s_%s.png" % [GENERATED_DIR, String(role_id), String(size_key)]
	if not ResourceLoader.exists(path):
		return null
	if _source_texture_cache.has(path):
		return _source_texture_cache[path] as Texture2D
	var texture: Texture2D = load(path) as Texture2D
	if texture != null:
		_source_texture_cache[path] = texture
	return texture

static func _build_rotated_texture(texture: Texture2D) -> Texture2D:
	var cache_key: String = texture.resource_path
	if cache_key == "":
		cache_key = "rid_%s" % [str(texture.get_rid().get_id())]
	if _rotated_texture_cache.has(cache_key):
		return _rotated_texture_cache[cache_key] as Texture2D
	var image: Image = texture.get_image()
	var rotated: Image = Image.create(image.get_height(), image.get_width(), false, image.get_format())
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			rotated.set_pixel(image.get_height() - 1 - y, x, image.get_pixel(x, y))
	var rotated_texture: Texture2D = ImageTexture.create_from_image(rotated)
	_rotated_texture_cache[cache_key] = rotated_texture
	return rotated_texture

static func clear_runtime_cache() -> void:
	_role_base_texture_lookup_cache = {}
	_role_expansion_texture_lookup_cache = {}
	_source_texture_cache = {}
	_rotated_texture_cache = {}
