extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var card_scene: PackedScene = load("res://Scenes/Components/item_icon_card.tscn")
	assert(card_scene != null, "Item card scene failed to load")
	var card: Control = card_scene.instantiate() as Control
	assert(card != null, "Item card failed to instantiate")
	get_root().add_child(card)
	card.call(
		"configure",
		{
			"display_name": "Test Food",
			"count": 1,
			"display_price": 2,
			"tooltip_name": "Test Food",
			"tooltip_base_bonus": "+8 HP",
			"tooltip_special_effect": "Immediate hover tooltip test",
			"tooltip_shape_cells": [Vector2i(0, 0), Vector2i(1, 0)],
		},
		null,
		{}
	)
	await process_frame
	assert(card.has_signal("hover_started"), "Item card should expose hover_started signal for shared overlay host")
	assert(card.has_signal("hover_ended"), "Item card should expose hover_ended signal for shared overlay host")
	print("ITEM_TOOLTIP_TEST_PASS")
	quit()
