extends RefCounted
class_name FoodVisuals

const FOOD_ICON_DIR := "res://Art/Food"
const FOOD_BOARD_ICON_DIR := "res://Art/FoodBoard"
const UI_BACKGROUND_PATH := "res://Art/UI/閼冲本娅?png"
const UI_PANEL_TEXTURE_A := "res://Art/UI/UI1.png"
const UI_PANEL_TEXTURE_B := "res://Art/UI/UI2.png"

static func build_food_texture_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	var directory: DirAccess = DirAccess.open(FOOD_ICON_DIR)
	if directory == null:
		return lookup
	for file_name in directory.get_files():
		if not file_name.to_lower().ends_with(".png"):
			continue
		if file_name.begins_with("IMG_"):
			continue
		var food_id: StringName = StringName(file_name.get_basename().to_lower())
		var texture: Texture2D = load("%s/%s" % [FOOD_ICON_DIR, file_name]) as Texture2D
		if texture != null:
			lookup[food_id] = texture
	return lookup

static func build_food_board_texture_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	var directory: DirAccess = DirAccess.open(FOOD_BOARD_ICON_DIR)
	if directory == null:
		return lookup
	for file_name in directory.get_files():
		if not file_name.to_lower().ends_with(".png"):
			continue
		var base_name: String = file_name.get_basename().to_lower()
		var separator_index: int = base_name.rfind("_r")
		if separator_index <= 0:
			continue
		var food_id: StringName = StringName(base_name.substr(0, separator_index))
		var rotation_text: String = base_name.substr(separator_index + 2)
		if not rotation_text.is_valid_int():
			continue
		var rotation: int = int(rotation_text)
		var texture: Texture2D = load("%s/%s" % [FOOD_BOARD_ICON_DIR, file_name]) as Texture2D
		if texture == null:
			continue
		var rotation_lookup: Dictionary = lookup.get(food_id, {})
		rotation_lookup[rotation] = texture
		lookup[food_id] = rotation_lookup
	return lookup

static func get_background_texture() -> Texture2D:
	return load(UI_BACKGROUND_PATH) as Texture2D

static func get_panel_texture_a() -> Texture2D:
	return load(UI_PANEL_TEXTURE_A) as Texture2D

static func get_panel_texture_b() -> Texture2D:
	return load(UI_PANEL_TEXTURE_B) as Texture2D
