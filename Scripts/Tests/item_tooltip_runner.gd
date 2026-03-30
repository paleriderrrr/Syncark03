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
	card.call("_on_mouse_entered")
	await process_frame
	await process_frame
	var tooltip: PopupPanel = card.get("_hover_tooltip")
	assert(tooltip != null, "Hover tooltip should be created immediately")
	assert(tooltip.visible, "Hover tooltip should be visible immediately on mouse enter")
	card.call("_on_mouse_exited")
	await process_frame
	assert(not tooltip.visible, "Hover tooltip should hide immediately on mouse exit")
	print("ITEM_TOOLTIP_TEST_PASS")
	quit()
