extends SceneTree
func _initialize():
    call_deferred("_run")
func _run():
    var scene: PackedScene = load("res://Scenes/main_editor_screen.tscn") as PackedScene
    if scene == null:
        printerr("MAIN_EDITOR_LOAD_FAIL")
        quit(1)
        return
    var inst = scene.instantiate()
    if inst == null:
        printerr("MAIN_EDITOR_INSTANTIATE_FAIL")
        quit(1)
        return
    print("MAIN_EDITOR_LOAD_PASS")
    quit(0)
