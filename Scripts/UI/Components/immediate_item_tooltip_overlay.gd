extends PanelContainer
class_name ImmediateItemTooltipOverlay

const VIEWPORT_PADDING := 8.0
const POPUP_GAP := 12.0

@onready var title_label: Label = %ItemTooltipTitleLabel
@onready var base_bonus_label: Label = %ItemTooltipBaseBonusLabel
@onready var special_effect_label: Label = %ItemTooltipSpecialEffectLabel
@onready var shape_title_label: Label = %ItemTooltipShapeTitleLabel
@onready var shape_host: VBoxContainer = %ItemTooltipShapeHost

var _shape_preview: ItemTooltipBuilder.TooltipShapePreview

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_as_relative = false
	z_index = 100
	_shape_preview = ItemTooltipBuilder.TooltipShapePreview.new()
	_shape_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape_host.add_child(_shape_preview)
	hide_tooltip()

func show_entry(entry: Dictionary, source_rect: Rect2) -> void:
	ItemTooltipBuilder.apply_to_labels(
		entry,
		title_label,
		base_bonus_label,
		special_effect_label,
		shape_title_label,
		_shape_preview
	)
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
