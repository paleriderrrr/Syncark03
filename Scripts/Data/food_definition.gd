extends Resource
class_name FoodDefinition

@export var id: StringName
@export var display_name: String = ""
@export var icon_texture: Texture2D
@export var category: StringName
@export var hybrid_categories: Array[StringName] = []
@export var rarity: StringName
@export var gold_value: int = 0
@export var shape_cells: Array[Vector2i] = []
@export var hp_bonus: int = 0
@export var attack_bonus: float = 0.0
@export var bonus_damage: float = 0.0
@export var attack_speed_percent: float = 0.0
@export var heal_per_second: float = 0.0
@export var execute_threshold_percent: float = 0.0
@export_multiline var passive_text: String = ""
