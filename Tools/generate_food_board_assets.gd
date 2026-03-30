extends SceneTree

const FOOD_CATALOG_PATH := "res://Data/Foods/food_catalog.tres"
const OUTPUT_DIR := "res://Art/FoodBoard"
const BOARD_CELL_SIZE := 72

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: FoodCatalog = load(FOOD_CATALOG_PATH) as FoodCatalog
	if catalog == null:
		printerr("FAILED: Food catalog did not load")
		quit(1)
		return
	var texture_lookup: Dictionary = FoodVisuals.build_food_texture_lookup()
	var food_lookup: Dictionary = {}
	for definition_variant in catalog.foods:
		var definition: FoodDefinition = definition_variant
		food_lookup[definition.id] = definition
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)
	var dir := DirAccess.open(output_path)
	if dir == null:
		printerr("FAILED: Could not open output directory %s" % output_path)
		quit(1)
		return
	for file_name in dir.get_files():
		if file_name.to_lower().ends_with(".png"):
			dir.remove(file_name)
	var baker := FoodBoardRenderCache.new()
	baker.prime(texture_lookup, food_lookup, BOARD_CELL_SIZE)
	var written_count: int = 0
	for definition_id_variant in food_lookup.keys():
		var definition_id: StringName = definition_id_variant
		if not texture_lookup.has(definition_id):
			continue
		var base_texture: Texture2D = baker.get_texture(definition_id, 0, BOARD_CELL_SIZE)
		if base_texture == null:
			continue
		var base_image: Image = base_texture.get_image()
		if base_image == null:
			continue
		for rotation in range(4):
			var output_image: Image = base_image.duplicate()
			match rotation:
				1:
					output_image.rotate_90(CLOCKWISE)
				2:
					output_image.rotate_180()
				3:
					output_image.rotate_90(COUNTERCLOCKWISE)
				_:
					pass
			var save_path: String = "%s/%s_r%d.png" % [OUTPUT_DIR, String(definition_id), rotation]
			var error: Error = output_image.save_png(ProjectSettings.globalize_path(save_path))
			if error != OK:
				printerr("FAILED: Could not save %s" % save_path)
				quit(1)
				return
			written_count += 1
	print("FOOD_BOARD_ASSETS_GENERATED %d" % written_count)
	quit(0)
