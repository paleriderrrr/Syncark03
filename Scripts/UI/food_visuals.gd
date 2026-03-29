extends RefCounted
class_name FoodVisuals

static func build_food_texture_lookup(food_catalog: FoodCatalog) -> Dictionary:
	var lookup: Dictionary = {}
	if food_catalog == null:
		return lookup
	for definition in food_catalog.foods:
		if definition == null or definition.icon_texture == null:
			continue
		lookup[definition.id] = definition.icon_texture
	return lookup
