extends SceneTree

const OUTPUT_DIR := "res://Art/UI/NewUI/UI1-3_slices/"
const EXPECTED_FILES := [
	"ui13_formal_settings_icon.png",
	"ui13_formal_help_icon.png",
	"ui13_formal_coin_marker.png",
	"ui13_formal_header_plate_blank.png",
	"ui13_formal_board_wood.png",
	"ui13_formal_right_board.png",
	"ui13_formal_role_tab_top_green.png",
	"ui13_formal_role_tab_mid_red.png",
	"ui13_formal_role_tab_bottom_purple.png",
	"ui13_formal_wanted_poster.png",
	"ui13_formal_depart_text.png",
	"ui13_formal_restart_text.png",
	"ui13_formal_end_text.png",
	"ui13_formal_continue_text.png",
	"ui13_formal_battle_text.png",
	"ui13_formal_leave_text.png",
	"ui13_formal_exit_sign_button.png",
	"ui13_formal_food_icon_veg.png",
	"ui13_formal_food_icon_dessert.png",
	"ui13_formal_food_icon_meat.png",
	"ui13_formal_food_icon_drink.png",
	"ui13_formal_food_icon_staple.png",
	"ui13_formal_food_icon_spice.png",
	"ui13_slice_manifest.json",
]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for file_name in EXPECTED_FILES:
		var path: String = OUTPUT_DIR + file_name
		_assert(FileAccess.file_exists(path), "Missing UI1-3 slice output: %s" % path)
	quit(0 if _failures.is_empty() else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
