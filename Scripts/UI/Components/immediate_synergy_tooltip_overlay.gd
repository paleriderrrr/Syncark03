extends PanelContainer
class_name ImmediateSynergyTooltipOverlay

const VIEWPORT_PADDING := 8.0
const POPUP_GAP := 12.0
const ACTIVATION_RULE := "激活条件: 3个不同种同类别食物"

@onready var category_label: Label = %SynergyTooltipCategoryLabel
@onready var synergy_name_label: Label = %SynergyTooltipNameLabel
@onready var count_label: Label = %SynergyTooltipCountLabel
@onready var activation_label: Label = %SynergyTooltipActivationLabel
@onready var effect_label: Label = %SynergyTooltipEffectLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_as_relative = false
	z_index = 110
	activation_label.text = ACTIVATION_RULE
	hide_tooltip()

func show_entry(entry: Dictionary, source_rect: Rect2) -> void:
	category_label.text = String(entry.get("category_name", ""))
	synergy_name_label.text = String(entry.get("synergy_name", ""))
	count_label.text = "当前计数: x%d" % int(entry.get("count", 0))
	effect_label.text = "效果: %s" % String(entry.get("effect_text", ""))
	visible = true
	reset_size()
	size = get_combined_minimum_size()
	_reposition(source_rect)

func hide_tooltip() -> void:
	visible = false

func _reposition(source_rect: Rect2) -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var popup_position := Vector2(source_rect.end.x + POPUP_GAP, source_rect.position.y)
	if popup_position.x + size.x > viewport_rect.size.x - VIEWPORT_PADDING:
		popup_position.x = source_rect.position.x - size.x - POPUP_GAP
	if popup_position.x < VIEWPORT_PADDING:
		popup_position.x = VIEWPORT_PADDING
	if popup_position.y + size.y > viewport_rect.size.y - VIEWPORT_PADDING:
		popup_position.y = viewport_rect.size.y - size.y - VIEWPORT_PADDING
	if popup_position.y < VIEWPORT_PADDING:
		popup_position.y = VIEWPORT_PADDING
	position = popup_position
