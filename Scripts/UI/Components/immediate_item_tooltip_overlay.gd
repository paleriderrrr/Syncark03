extends Control
class_name ImmediateItemTooltipOverlay

const FONT_SIZE_BOOST := 2
const TITLE_COLOR := Color(0.24, 0.15, 0.08, 1.0)
const LABEL_COLOR := Color(0.42, 0.28, 0.16, 1.0)
const VALUE_COLOR := Color(0.15, 0.10, 0.06, 1.0)

@export var tooltip_size := Vector2(440.0, 260.0)
@export_range(0.0, 0.5, 0.01) var top_offset_ratio := 0.12
@export var top_offset_min := 92.0
@export var top_offset_max := 132.0
@export var use_scene_margin_layout := true
@export var use_fixed_slot := true

@onready var title_label: Label = %ItemTooltipTitleLabel
@onready var quantity_value_label: Label = %ItemTooltipQuantityValueLabel
@onready var rarity_value_label: Label = %ItemTooltipRarityValueLabel
@onready var category_value_label: Label = %ItemTooltipCategoryValueLabel
@onready var price_value_label: Label = %ItemTooltipPriceValueLabel
@onready var shape_summary_label: Label = %ItemTooltipShapeSummaryLabel
@onready var base_bonus_label: Label = %ItemTooltipBaseBonusLabel
@onready var special_effect_label: Label = %ItemTooltipSpecialEffectLabel
@onready var shape_title_label: Label = %ItemTooltipShapeTitleLabel
@onready var shape_host: VBoxContainer = %ItemTooltipShapeHost
@onready var margin_root: MarginContainer = get_node_or_null("Margin") as MarginContainer

var _shape_preview: ItemTooltipBuilder.TooltipShapePreview

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_as_relative = false
	z_index = 100
	_apply_exported_layout()
	_boost_label_font_sizes()
	_apply_text_colors()
	_shape_preview = ItemTooltipBuilder.TooltipShapePreview.new()
	_shape_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shape_preview.cell_size = 18.0
	shape_host.add_child(_shape_preview)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	hide_tooltip()

func show_entry(entry: Dictionary, _source_rect: Rect2 = Rect2()) -> void:
	ItemTooltipBuilder.apply_to_labels(
		entry,
		title_label,
		quantity_value_label,
		rarity_value_label,
		category_value_label,
		price_value_label,
		shape_summary_label,
		base_bonus_label,
		special_effect_label,
		shape_title_label,
		_shape_preview
	)
	visible = true
	_apply_exported_layout()
	if use_fixed_slot:
		_place_in_fixed_slot()

func hide_tooltip() -> void:
	visible = false

func _on_viewport_size_changed() -> void:
	if visible and use_fixed_slot:
		_apply_exported_layout()
		_place_in_fixed_slot()

func _place_in_fixed_slot() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var top_offset: float = clampf(viewport_rect.size.y * top_offset_ratio, top_offset_min, top_offset_max)
	position = Vector2(
		round((viewport_rect.size.x - size.x) * 0.5),
		round(top_offset)
	)

func place_at_global_point(anchor_global_position: Vector2) -> void:
	position = Vector2(
		round(anchor_global_position.x - size.x * 0.5),
		round(anchor_global_position.y)
	)

func _apply_exported_layout() -> void:
	custom_minimum_size = tooltip_size
	size = tooltip_size
	if use_scene_margin_layout and margin_root != null:
		margin_root.reset_size()

func _boost_label_font_sizes() -> void:
	var labels: Array[Label] = [
		title_label,
		quantity_value_label,
		rarity_value_label,
		category_value_label,
		price_value_label,
		shape_summary_label,
		base_bonus_label,
		special_effect_label,
		shape_title_label,
	]
	for label in labels:
		var current_size: int = label.get_theme_font_size("font_size")
		if current_size > 0:
			label.add_theme_font_size_override("font_size", current_size + FONT_SIZE_BOOST)

func _apply_text_colors() -> void:
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	for label_path in [
		"Margin/RootHBox/LeftColumn/InfoGrid/QuantityTitleLabel",
		"Margin/RootHBox/LeftColumn/InfoGrid/RarityTitleLabel",
		"Margin/RootHBox/LeftColumn/InfoGrid/CategoryTitleLabel",
		"Margin/RootHBox/LeftColumn/InfoGrid/PriceTitleLabel",
		"Margin/RootHBox/LeftColumn/BaseBonusTitleLabel",
		"Margin/RootHBox/RightColumn/EffectTitleLabel",
		"Margin/RootHBox/RightColumn/ItemTooltipShapeTitleLabel",
	]:
		var label: Label = get_node(label_path)
		label.add_theme_color_override("font_color", LABEL_COLOR)
	for label in [
		quantity_value_label,
		rarity_value_label,
		category_value_label,
		price_value_label,
		shape_summary_label,
		base_bonus_label,
		special_effect_label,
	]:
		label.add_theme_color_override("font_color", VALUE_COLOR)
