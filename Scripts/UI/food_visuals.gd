extends RefCounted
class_name FoodVisuals

const FOOD_CATALOG_PATH := "res://Data/Foods/food_catalog.tres"
const FOOD_ICON_DIR := "res://Art/Food"
const FOOD_BOARD_ICON_DIR := "res://Art/FoodBoard"
const UI_BACKGROUND_PATH := "res://Art/UI/闁煎啿鏈▍?png"
const UI_PANEL_TEXTURE_A := "res://Art/UI/UI1.png"
const UI_PANEL_TEXTURE_B := "res://Art/UI/UI2.png"
const FOOD_ICON_SUFFIXES := [".png", ".PNG"]

static var _food_texture_lookup_cache: Dictionary = {}
static var _food_board_texture_lookup_cache: Dictionary = {}
static var _background_texture_cache: Texture2D
static var _panel_texture_a_cache: Texture2D
static var _panel_texture_b_cache: Texture2D
static var _food_catalog_cache: FoodCatalog

static func build_food_texture_lookup() -> Dictionary:
	if not _food_texture_lookup_cache.is_empty():
		return _food_texture_lookup_cache
	var lookup: Dictionary = {}
	var catalog: FoodCatalog = _get_food_catalog()
	if catalog == null:
		return lookup
	for definition_variant in catalog.foods:
		var definition: FoodDefinition = definition_variant
		if definition == null:
			continue
		var food_id: StringName = StringName(String(definition.id).to_lower())
		var texture: Texture2D = _load_food_icon(food_id)
		if texture != null:
			lookup[food_id] = texture
	_food_texture_lookup_cache = lookup
	return _food_texture_lookup_cache

static func build_food_board_texture_lookup() -> Dictionary:
	if not _food_board_texture_lookup_cache.is_empty():
		return _food_board_texture_lookup_cache
	var lookup: Dictionary = {}
	var catalog: FoodCatalog = _get_food_catalog()
	if catalog == null:
		return lookup
	for definition_variant in catalog.foods:
		var definition: FoodDefinition = definition_variant
		if definition == null:
			continue
		var food_id: StringName = StringName(String(definition.id).to_lower())
		var rotation_lookup: Dictionary = {}
		for rotation in range(4):
			var texture_path := "%s/%s_r%d.png" % [FOOD_BOARD_ICON_DIR, String(food_id), rotation]
			var texture: Texture2D = _load_texture_if_exists(texture_path)
			if texture != null:
				rotation_lookup[rotation] = texture
		if not rotation_lookup.is_empty():
			lookup[food_id] = rotation_lookup
	_food_board_texture_lookup_cache = lookup
	return _food_board_texture_lookup_cache

static func _get_food_catalog() -> FoodCatalog:
	if _food_catalog_cache != null:
		return _food_catalog_cache
	_food_catalog_cache = load(FOOD_CATALOG_PATH) as FoodCatalog
	return _food_catalog_cache

static func _load_food_icon(food_id: StringName) -> Texture2D:
	for suffix in FOOD_ICON_SUFFIXES:
		var texture: Texture2D = _load_texture_if_exists("%s/%s%s" % [FOOD_ICON_DIR, String(food_id), suffix])
		if texture != null:
			return texture
	return null

static func _load_texture_if_exists(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func get_background_texture() -> Texture2D:
	if _background_texture_cache == null:
		_background_texture_cache = load(UI_BACKGROUND_PATH) as Texture2D
	return _background_texture_cache

static func get_panel_texture_a() -> Texture2D:
	if _panel_texture_a_cache == null:
		_panel_texture_a_cache = load(UI_PANEL_TEXTURE_A) as Texture2D
	return _panel_texture_a_cache

static func get_panel_texture_b() -> Texture2D:
	if _panel_texture_b_cache == null:
		_panel_texture_b_cache = load(UI_PANEL_TEXTURE_B) as Texture2D
	return _panel_texture_b_cache

static func clear_runtime_cache() -> void:
	_food_texture_lookup_cache = {}
	_food_board_texture_lookup_cache = {}
	_background_texture_cache = null
	_panel_texture_a_cache = null
	_panel_texture_b_cache = null
	_food_catalog_cache = null
