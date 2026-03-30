extends RefCounted
class_name LunchboxVisuals

const GENERATED_DIR := "res://Art/Lunchbox/Generated"
const BASE_SIZE_KEY := &"3x3"
const EXPANSION_SIZE_KEYS: Array[StringName] = [&"1x1", &"2x2", &"1x4", &"2x4"]
const ROLE_IDS: Array[StringName] = [&"warrior", &"hunter", &"mage"]

static func build_role_base_texture_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	for role_id in ROLE_IDS:
		var texture: Texture2D = _load_generated_texture(role_id, BASE_SIZE_KEY)
		if texture != null:
			lookup[role_id] = texture
	return lookup

static func build_role_expansion_texture_lookup() -> Dictionary:
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
	return lookup

static func _load_generated_texture(role_id: StringName, size_key: StringName) -> Texture2D:
	var path := "%s/%s_%s.png" % [GENERATED_DIR, String(role_id), String(size_key)]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func _build_rotated_texture(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	var rotated: Image = Image.create(image.get_height(), image.get_width(), false, image.get_format())
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			rotated.set_pixel(image.get_height() - 1 - y, x, image.get_pixel(x, y))
	return ImageTexture.create_from_image(rotated)
