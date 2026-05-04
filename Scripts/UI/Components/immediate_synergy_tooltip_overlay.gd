extends Control
class_name ImmediateSynergyTooltipOverlay

const FONT_SIZE_BOOST := 2
const TITLE_COLOR := Color(0.24, 0.15, 0.08, 1.0)
const LABEL_COLOR := Color(0.42, 0.28, 0.16, 1.0)
const VALUE_COLOR := Color(0.15, 0.10, 0.06, 1.0)
const ACTIVATION_RULE := "激活条件：3个不同种同类食物"

@export var tooltip_size := Vector2(520.0, 240.0)
@export_range(0.0, 0.5, 0.01) var top_offset_ratio := 0.12
@export var top_offset_min := 92.0
@export var top_offset_max := 132.0
@export var use_fixed_slot := true

@onready var category_label: Label = %SynergyTooltipCategoryLabel
@onready var synergy_name_label: Label = %SynergyTooltipNameLabel
@onready var count_label: Label = %SynergyTooltipCountLabel
@onready var activation_label: Label = %SynergyTooltipActivationLabel
@onready var effect_label: Label = %SynergyTooltipEffectLabel
@onready var margin_root: MarginContainer = get_node_or_null("Margin") as MarginContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_as_relative = false
	z_index = 110
	_apply_exported_layout()
	_boost_label_font_sizes()
	_apply_text_colors()
	activation_label.text = ACTIVATION_RULE
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	hide_tooltip()

func show_entry(entry: Dictionary, _source_rect: Rect2 = Rect2()) -> void:
	category_label.text = "类别：%s" % String(entry.get("category_name", ""))
	synergy_name_label.text = String(entry.get("synergy_name", ""))
	count_label.text = "当前计数：x%d" % int(entry.get("count", 0))
	effect_label.text = "效果描述：%s" % String(entry.get("effect_text", ""))
	visible = true
	_apply_exported_layout()
	if use_fixed_slot:
		_place_in_fixed_slot()

func hide_tooltip() -> void:
	visible = false

func place_at_global_point(anchor_global_position: Vector2) -> void:
	position = Vector2(
		round(anchor_global_position.x - size.x * 0.5),
		round(anchor_global_position.y)
	)

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

func _apply_exported_layout() -> void:
	custom_minimum_size = tooltip_size
	size = tooltip_size
	if margin_root != null:
		margin_root.reset_size()

func _boost_label_font_sizes() -> void:
	for label in [category_label, synergy_name_label, count_label, activation_label, effect_label]:
		var current_size: int = label.get_theme_font_size("font_size")
		if current_size > 0:
			label.add_theme_font_size_override("font_size", current_size + FONT_SIZE_BOOST)

func _apply_text_colors() -> void:
	synergy_name_label.add_theme_color_override("font_color", TITLE_COLOR)
	for label in [category_label, activation_label]:
		label.add_theme_color_override("font_color", LABEL_COLOR)
	for label in [count_label, effect_label]:
		label.add_theme_color_override("font_color", VALUE_COLOR)
