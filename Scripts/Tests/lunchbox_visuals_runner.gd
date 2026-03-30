extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	LunchboxVisuals.clear_runtime_cache()
	_assert(ResourceLoader.exists("res://Art/Lunchbox/Generated/warrior_3x3.png"), "Generated warrior 3x3 lunchbox texture should exist")
	_assert(ResourceLoader.exists("res://Art/Lunchbox/Generated/hunter_2x2.png"), "Generated hunter 2x2 lunchbox texture should exist")
	_assert(ResourceLoader.exists("res://Art/Lunchbox/Generated/mage_2x4.png"), "Generated mage 2x4 lunchbox texture should exist")

	var base_lookup: Dictionary = LunchboxVisuals.build_role_base_texture_lookup()
	_assert(base_lookup.has(&"warrior"), "Lunchbox visuals should expose warrior base texture")
	_assert(base_lookup.has(&"hunter"), "Lunchbox visuals should expose hunter base texture")
	_assert(base_lookup.has(&"mage"), "Lunchbox visuals should expose mage base texture")

	var expansion_lookup: Dictionary = LunchboxVisuals.build_role_expansion_texture_lookup()
	var second_expansion_lookup: Dictionary = LunchboxVisuals.build_role_expansion_texture_lookup()
	_assert(expansion_lookup.has(&"warrior"), "Lunchbox visuals should expose warrior expansion textures")
	if expansion_lookup.has(&"warrior"):
		var warrior_lookup: Dictionary = expansion_lookup[&"warrior"]
		_assert(warrior_lookup.has(&"1x1"), "Warrior expansion textures should include 1x1")
		_assert(warrior_lookup.has(&"2x2"), "Warrior expansion textures should include 2x2")
		_assert(warrior_lookup.has(&"1x4"), "Warrior expansion textures should include 1x4")
		_assert(warrior_lookup.has(&"4x1"), "Warrior expansion textures should include rotated 4x1")
		_assert(warrior_lookup.has(&"2x4"), "Warrior expansion textures should include 2x4")
		_assert(warrior_lookup.has(&"4x2"), "Warrior expansion textures should include rotated 4x2")
		var second_warrior_lookup: Dictionary = second_expansion_lookup[&"warrior"]
		_assert(is_same(warrior_lookup[&"4x1"], second_warrior_lookup[&"4x1"]), "Lunchbox visuals should cache rotated 4x1 textures across calls")
		_assert(is_same(warrior_lookup[&"4x2"], second_warrior_lookup[&"4x2"]), "Lunchbox visuals should cache rotated 4x2 textures across calls")

	if base_lookup.has(&"warrior") and base_lookup.has(&"hunter") and base_lookup.has(&"mage"):
		var warrior_image: Image = (base_lookup[&"warrior"] as Texture2D).get_image()
		var hunter_image: Image = (base_lookup[&"hunter"] as Texture2D).get_image()
		var mage_image: Image = (base_lookup[&"mage"] as Texture2D).get_image()
		var center := Vector2i(warrior_image.get_width() / 2, warrior_image.get_height() / 2)
		var warrior_color: Color = warrior_image.get_pixelv(center)
		var hunter_color: Color = hunter_image.get_pixelv(center)
		var mage_color: Color = mage_image.get_pixelv(center)
		_assert(warrior_color.a > 0.95, "Base lunchbox texture center should be opaque")
		_assert(warrior_color.r > warrior_color.g and warrior_color.r > warrior_color.b, "Warrior lunchbox should preserve the red source color")
		_assert(hunter_color.b > hunter_color.g and hunter_color.b > hunter_color.r, "Hunter lunchbox should recolor toward purple-blue")
		_assert(mage_color.g > mage_color.r and mage_color.g > mage_color.b, "Mage lunchbox should recolor toward green")
		_assert(warrior_image.get_pixel(0, 0).a == 0.0, "Generated lunchbox texture should keep transparent outer corners")

	if _failures.is_empty():
		print("LUNCHBOX_VISUALS_TEST_PASS")
		quit(0)
	else:
		printerr("LUNCHBOX_VISUALS_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
