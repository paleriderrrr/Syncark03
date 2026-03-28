extends GridContainer
class_name BentoBoardView

signal cell_clicked(cell: Vector2i)

const GRID_WIDTH := 6
const GRID_HEIGHT := 8

@export var cell_pixel_size: int = 56
@export var read_only: bool = false

var _buttons: Dictionary = {}

func _ready() -> void:
	columns = GRID_WIDTH
	if _buttons.is_empty():
		_build_buttons()

func _build_buttons() -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var button := Button.new()
			button.custom_minimum_size = Vector2(cell_pixel_size, cell_pixel_size)
			button.focus_mode = Control.FOCUS_NONE
			button.clip_text = true
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var cell := Vector2i(x, y)
			button.pressed.connect(func() -> void:
				cell_clicked.emit(cell)
			)
			add_child(button)
			_buttons["%d:%d" % [x, y]] = button

func refresh_board(character_state: Dictionary, preview_cells: Array[Vector2i], food_lookup: Dictionary) -> void:
	if _buttons.is_empty():
		_build_buttons()
	var active_lookup: Dictionary = ShapeUtils.cells_to_lookup(character_state.get("active_cells", []))
	var preview_lookup: Dictionary = ShapeUtils.cells_to_lookup(preview_cells)
	var occupied_food_by_cell: Dictionary = {}
	for item in character_state.get("placed_foods", []):
		var definition: FoodDefinition = food_lookup.get(item["definition_id"])
		for cell in item["cells"]:
			occupied_food_by_cell["%d:%d" % [cell.x, cell.y]] = definition
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var key := "%d:%d" % [x, y]
			var button: Button = _buttons[key]
			button.disabled = false
			button.text = ""
			button.custom_minimum_size = Vector2(cell_pixel_size, cell_pixel_size)
			if not active_lookup.has(key):
				button.disabled = true
				button.modulate = Color(0.2, 0.2, 0.2, 1.0)
				continue
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if occupied_food_by_cell.has(key):
				var definition: FoodDefinition = occupied_food_by_cell[key]
				button.text = definition.display_name.substr(0, 1)
				button.modulate = _color_for_rarity(definition.rarity)
			elif preview_lookup.has(key):
				button.text = "+"
				button.modulate = Color(0.6, 1.0, 0.6, 1.0)
			elif read_only:
				button.text = "·"

func _color_for_rarity(rarity: StringName) -> Color:
	match rarity:
		&"common":
			return Color(0.75, 0.75, 0.75, 1.0)
		&"rare":
			return Color(0.55, 0.75, 1.0, 1.0)
		&"epic":
			return Color(0.85, 0.55, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)
