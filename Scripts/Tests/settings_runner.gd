extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var run_state: Node = get_root().get_node_or_null("/root/RunState")
	if run_state == null:
		var run_state_script: GDScript = load("res://Scripts/Autoload/run_state.gd")
		run_state = run_state_script.new()
		run_state.name = "RunState"
		get_root().add_child(run_state)
	if get_root().get_node_or_null("/root/BgmPlayer") == null:
		var bgm_script: GDScript = load("res://Scripts/Autoload/bgm_player.gd")
		var bgm_player: Node = bgm_script.new()
		bgm_player.name = "BgmPlayer"
		get_root().add_child(bgm_player)
	if get_root().get_node_or_null("/root/UiSfxPlayer") == null:
		var ui_sfx_script: GDScript = load("res://Scripts/Autoload/ui_sfx_player.gd")
		var ui_sfx_player: Node = ui_sfx_script.new()
		ui_sfx_player.name = "UiSfxPlayer"
		get_root().add_child(ui_sfx_player)
	await process_frame
	run_state.set_master_volume_percent(64.0)
	var scene: PackedScene = load("res://Scenes/settings_screen.tscn")
	assert(scene != null, "Settings scene failed to load")
	var root: Control = scene.instantiate() as Control
	assert(root != null, "Settings scene did not instantiate to Control")
	get_root().add_child(root)
	await process_frame
	assert(root.get_node_or_null("%VolumeSlider") != null, "VolumeSlider missing")
	assert(root.get_node_or_null("%RestartButton") != null, "RestartButton missing")
	assert(root.get_node_or_null("%EditorButton") != null, "EditorButton missing")
	assert(root.get_node_or_null("%BackButton") != null, "BackButton missing")
	assert(root.get_node_or_null("%CloseButton") != null, "CloseButton missing")
	var background: TextureRect = root.get_node("CenterContainer/PanelRoot/Background")
	assert(background.texture != null, "Background texture missing")
	var volume_icon: TextureRect = root.get_node("CenterContainer/PanelRoot/VolumeIcon")
	assert(volume_icon.texture != null, "Volume icon missing")
	var slider: HSlider = root.get_node("%VolumeSlider")
	assert(is_equal_approx(slider.value, 64.0), "Slider did not initialize from RunState master volume")
	slider.value = 25.0
	assert(is_equal_approx(run_state.get_master_volume_percent(), 25.0), "RunState volume did not update from slider")
	var bus_index: int = AudioServer.get_bus_index(&"Master")
	assert(bus_index >= 0, "Master bus missing")
	assert(AudioServer.get_bus_volume_db(bus_index) <= -11.0 and AudioServer.get_bus_volume_db(bus_index) >= -13.0, "Master bus dB did not follow slider change")
	print("SETTINGS_TEST_PASS")
	quit()
