extends RefCounted
class_name FoodVisuals

const FOOD_ICON_PATHS := {
	&"red_berry": "res://Art/Food/IMG_0120.PNG",
	&"lettuce_leaf": "res://Art/Food/IMG_0121.PNG",
	&"lemon": "res://Art/Food/IMG_0123.PNG",
	&"broccoli": "res://Art/Food/IMG_0124.PNG",
	&"prickly_pear": "res://Art/Food/IMG_0125.PNG",
}

const UI_BACKGROUND_PATH := "res://Art/UI/背景.png"
const UI_PANEL_TEXTURE_A := "res://Art/UI/UI1.png"
const UI_PANEL_TEXTURE_B := "res://Art/UI/UI2.png"

static func build_food_texture_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	for food_id in FOOD_ICON_PATHS.keys():
		var texture: Texture2D = load(FOOD_ICON_PATHS[food_id]) as Texture2D
		if texture != null:
			lookup[food_id] = texture
	return lookup

static func get_background_texture() -> Texture2D:
	return load(UI_BACKGROUND_PATH) as Texture2D

static func get_panel_texture_a() -> Texture2D:
	return load(UI_PANEL_TEXTURE_A) as Texture2D

static func get_panel_texture_b() -> Texture2D:
	return load(UI_PANEL_TEXTURE_B) as Texture2D
