extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	var definition: FoodDefinition = run_state.food_catalog.foods[0]
	var cells: Array[Vector2i] = ShapeUtils.translate_cells(definition.shape_cells, Vector2i.ZERO)
	var state: Dictionary = run_state.get_selected_character_state()
	state["placed_foods"] = [{
		"instance_id": &"tooltip_test_food",
		"definition_id": definition.id,
		"rotation": 0,
		"anchor": Vector2i.ZERO,
		"cells": cells,
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
	await process_frame
	var popup: PopupPanel = editor.get("_board_hover_tooltip")
	assert(popup != null, "Board hover tooltip popup should be created")
	assert(popup.visible, "Board hover tooltip should be visible when hovering placed food")
	board_view._clear_food_hover()
	await process_frame
	assert(not popup.visible, "Board hover tooltip should hide when board hover clears")
	print("BOARD_HOVER_TOOLTIP_TEST_PASS")
	quit()
