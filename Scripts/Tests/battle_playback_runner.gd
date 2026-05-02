extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = root.get_node("/root/RunState")
	run_state.start_new_run()
	run_state.shared_inventory.append(run_state.generate_item_instance(&"red_berry"))
	var item: Dictionary = run_state.shared_inventory[0]
	run_state.select_inventory_item(item["instance_id"])
	_assert(run_state.try_place_selected_item(Vector2i.ZERO), "Playback test setup should place a food item")
	run_state.advance_to_next_node()
	run_state.prepare_battle()

	var editor_scene: PackedScene = load("res://Scenes/main_editor_screen.tscn")
	var editor: Node = editor_scene.instantiate()
	root.add_child(editor)
	await process_frame

	var popup: BattlePopup = editor.get_node("BattlePopup") as BattlePopup
	var blocker: Control = editor.get_node("BattleModalBlocker") as Control
	var result_banner: TextureRect = popup.get_node("Margin/RootVBox/ArenaPanel/ArenaStage/ResultBanner") as TextureRect
	var start_button: Button = popup.find_child("StartBattleButton", true, false) as Button
	var left_curtain: TextureRect = popup.find_child("LeftCurtainBlockout", true, false) as TextureRect
	var right_curtain: TextureRect = popup.find_child("RightCurtainBlockout", true, false) as TextureRect
	var stage_background: TextureRect = popup.get_node("WindowArt") as TextureRect
	var stage_overlay: TextureRect = popup.get_node("StageArt") as TextureRect
	var stage_frame: TextureRect = popup.get_node("StageOverlay") as TextureRect
	var monster_actor: Control = popup.get_node("%MonsterActor") as Control
	_assert(start_button != null, "Battle popup should expose a Start Battle button node")
	_assert(left_curtain != null and right_curtain != null, "Battle popup should create both curtain nodes")
	popup.open_battle()
	_assert(not popup._is_playing, "Battle popup should stay in preparation mode before Start Battle is pressed")
	_assert(start_button.visible, "Battle popup should show a Start Battle button during preparation")
	_assert(popup.get_stage_phase() == &"preparation", "Battle popup should open in the preparation stage phase")
	_assert(not left_curtain.visible, "Preparation phase should reveal the hero-side curtain")
	_assert(right_curtain.visible, "Preparation phase should keep the monster-side curtain closed")
	_assert(stage_background.texture != null and stage_background.texture.resource_path.ends_with("battle_stage_popup_bg.png"), "Battle popup should use the new stage background art")
	_assert(stage_overlay.texture != null and stage_overlay.texture.resource_path.ends_with("battle_stage_overlay.png"), "Battle popup should use the new stage overlay art")
	_assert(stage_frame.texture != null and stage_frame.texture.resource_path.ends_with("舞台最上层.png"), "Battle popup should use the new stage frame art")
	_assert(start_button.icon != null and start_button.icon.resource_path.ends_with("battle_start_normal.png"), "Battle popup should use the new start button art")
	_assert(not monster_actor.visible, "Preparation phase should hide the monster until battle start reveal")
	_assert(not popup.popup_window, "Battle popup should not use click-outside popup-window auto close")
	_assert(blocker.visible, "Battle popup should block outside interaction while visible")
	_assert(run_state.battle_reports.is_empty(), "Battle result should not be committed before playback finishes")
	start_button.pressed.emit()
	await process_frame
	_assert(popup._is_playing, "Battle popup should enter playback after Start Battle is pressed")
	_assert(popup.get_stage_phase() == &"monster_reveal" or popup.get_stage_phase() == &"battle", "Start Battle should enter the monster reveal contract before playback")
	while popup._is_playing:
		await process_frame
	_assert(run_state.battle_reports.size() == 1, "Battle result should be committed after playback finishes")
	_assert(result_banner.visible, "Battle result banner should be visible after playback finishes")
	_assert(monster_actor.visible, "Battle phase should reveal the monster actor")
	var result: String = String(run_state.battle_reports[0].get("result", ""))
	var banner_path: String = ""
	if result_banner.texture != null:
		banner_path = result_banner.texture.resource_path
	if result == "win":
		_assert(banner_path.ends_with("victory.png"), "Winning battles should show the victory banner")
	elif result == "lose":
		_assert(banner_path.ends_with("defeat.png"), "Losing battles should show the defeat banner")
	else:
		_assert(false, "Battle playback test expected a win or lose result, got %s" % result)
	popup.hide()
	await process_frame
	_assert(not blocker.visible, "Battle popup should release the outside blocker after closing")

	editor.queue_free()
	if _failures.is_empty():
		print("BATTLE_PLAYBACK_TEST_PASS")
		quit(0)
	else:
		printerr("BATTLE_PLAYBACK_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
