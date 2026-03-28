extends Resource
class_name MonsterDefinition

@export var id: StringName
@export var display_name: String = ""
@export var category: StringName
@export var base_hp: int = 0
@export var base_attack: float = 0.0
@export var attack_interval: float = 1.0
@export_multiline var skill_summary: String = ""
@export var target_rule: StringName

