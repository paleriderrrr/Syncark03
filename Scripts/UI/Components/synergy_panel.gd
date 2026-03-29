extends PanelContainer
class_name SynergyPanel

const HIGHLIGHT_THRESHOLD := 3
const DIM_ICON_COLOR := Color(0.48, 0.42, 0.36, 0.82)
const NORMAL_ICON_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HIGHLIGHT_ICON_COLOR := Color(1.12, 0.96, 0.62, 1.0)
const NORMAL_TEXT_COLOR := Color(0.25, 0.16, 0.1, 1.0)
const HIGHLIGHT_TEXT_COLOR := Color(0.64, 0.31, 0.08, 1.0)

@onready var role_label: Label = %RoleLabel
@onready var staple_icon: TextureRect = %StapleIcon
@onready var staple_count_label: Label = %StapleCountLabel
@onready var meat_icon: TextureRect = %MeatIcon
@onready var meat_count_label: Label = %MeatCountLabel
@onready var fruit_icon: TextureRect = %FruitIcon
@onready var fruit_count_label: Label = %FruitCountLabel
@onready var dessert_icon: TextureRect = %DessertIcon
@onready var dessert_count_label: Label = %DessertCountLabel
@onready var drink_icon: TextureRect = %DrinkIcon
@onready var drink_count_label: Label = %DrinkCountLabel
@onready var spice_icon: TextureRect = %SpiceIcon
@onready var spice_count_label: Label = %SpiceCountLabel

var _category_rows: Dictionary = {}

func _ready() -> void:
	_category_rows = {
		&"staple": {"icon": staple_icon, "label": staple_count_label},
		&"meat": {"icon": meat_icon, "label": meat_count_label},
		&"fruit": {"icon": fruit_icon, "label": fruit_count_label},
		&"dessert": {"icon": dessert_icon, "label": dessert_count_label},
		&"drink": {"icon": drink_icon, "label": drink_count_label},
		&"spice": {"icon": spice_icon, "label": spice_count_label},
	}
	for category_id in _category_rows.keys():
		_apply_category_state(category_id, 0)

func set_summary(summary: Dictionary, role_name: String) -> void:
	role_label.text = role_name
	var entry_lookup: Dictionary = {}
	for entry_variant in summary.get("entries", []):
		var entry: Dictionary = entry_variant
		entry_lookup[entry.get("category_id", &"")] = entry
	for category_id in _category_rows.keys():
		var entry: Dictionary = entry_lookup.get(category_id, {})
		_apply_category_state(category_id, int(entry.get("count", 0)))

func _apply_category_state(category_id: StringName, count: int) -> void:
	var row: Dictionary = _category_rows.get(category_id, {})
	if row.is_empty():
		return
	var icon_rect: TextureRect = row["icon"] as TextureRect
	var count_label: Label = row["label"] as Label
	var reached_highlight: bool = count >= HIGHLIGHT_THRESHOLD
	count_label.text = "x%d" % count
	icon_rect.modulate = HIGHLIGHT_ICON_COLOR if reached_highlight else (NORMAL_ICON_COLOR if count > 0 else DIM_ICON_COLOR)
	count_label.add_theme_color_override(
		"font_color",
		HIGHLIGHT_TEXT_COLOR if reached_highlight else NORMAL_TEXT_COLOR
	)
