extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://Scenes/Components/item_strip.tscn")
	var strip: ItemStrip = scene.instantiate() as ItemStrip
	root.add_child(strip)
	await process_frame

	var entries: Array[Dictionary] = []
	for index in range(11):
		entries.append({
			"group_key": StringName("entry_%d" % index),
			"definition_id": &"amber_tea" if index == 10 else &"red_berry",
			"display_name": "Entry %d" % index,
			"count": 1,
			"category": &"drink" if index == 10 else &"fruit",
			"rarity": &"common",
		})
	strip.set_entries(entries, {})
	await process_frame
	strip.debug_set_viewport_size(Vector2(852, 208))
	strip.debug_set_page_index(2)
	await process_frame

	var first_index: int = strip.get_first_visible_entry_index_for_page()
	var first_rect: Rect2 = strip.get_entry_visible_rect(first_index)
	var viewport_rect: Rect2 = strip.get_viewport_visible_rect()
	_assert(first_index == 10, "The third page should begin with the deterministic eleventh entry")
	_assert(first_rect.position.x >= viewport_rect.position.x, "The third-page first card should not be clipped on the left")
	_assert(first_rect.end.x <= viewport_rect.end.x, "The third-page first card should fit inside the visible strip")
	_assert(first_rect.size.x > 0.0, "The third-page first card should have non-zero visible width")

	strip.queue_free()
	if _failures.is_empty():
		print("ITEM_STRIP_TEST_PASS")
		quit(0)
	else:
		printerr("ITEM_STRIP_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
