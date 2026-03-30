extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	var first_definition: FoodDefinition = run_state.food_catalog.foods[0]
	var second_definition: FoodDefinition = run_state.food_catalog.foods[1]
	var first_cells: Array[Vector2i] = ShapeUtils.translate_cells(first_definition.shape_cells, Vector2i.ZERO)
	var second_cells: Array[Vector2i] = ShapeUtils.translate_cells(second_definition.shape_cells, Vector2i(4, 0))
	var state: Dictionary = run_state.get_selected_character_state()
	state["placed_foods"] = [{
		"instance_id": &"tooltip_test_food",
		"definition_id": first_definition.id,
		"rotation": 0,
		"anchor": Vector2i.ZERO,
		"cells": first_cells,
	}, {
		"instance_id": &"tooltip_test_food_b",
		"definition_id": second_definition.id,
		"rotation": 0,
		"anchor": Vector2i(4, 0),
		"cells": second_cells,
	}]
	run_state.character_states[run_state.selected_character_id] = state
	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Control = editor_scene.instantiate() as Control
	root.add_child(editor)
	await process_frame
	await process_frame
	var board_view: BentoBoardView = editor.get_node("%BentoBoardView")
	board_view._update_food_hover(Vector2(10.0, 10.0))
	await process_frame
	var overlay: Control = editor.get_node_or_null("ItemTooltipOverlay")
	assert(overlay != null, "Shared item tooltip overlay should exist")
	assert(overlay.visible, "Board hover overlay should be visible when hovering placed food")
	var title_label: Label = overlay.get_node("%ItemTooltipTitleLabel")
	assert(title_label.text == first_definition.display_name, "Board hover overlay should show first food name")
	board_view._update_food_hover(Vector2(4.0 * board_view.cell_pixel_size + 10.0, 10.0))
	await process_frame
	assert(title_label.text == second_definition.display_name, "Board hover overlay should switch immediately when hovering a different food")
	board_view.cell_right_clicked.emit(Vector2i.ZERO)
	board_view._clear_food_hover()
	await process_frame
	assert(not overlay.visible, "Board hover overlay should hide when board hover clears")
	print("BOARD_HOVER_TOOLTIP_TEST_PASS")
	quit()
