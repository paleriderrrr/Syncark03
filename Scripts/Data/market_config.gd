extends Resource
class_name MarketConfig

@export var slot_count: int = 5
@export var reroll_cost_curve: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21]
@export var expansion_slot_chance: float = 0.3
@export var food_slot_chance: float = 0.7
@export var expansion_offers: Array[Dictionary] = []
@export var rarity_weights_by_market: Array[Dictionary] = []
@export var quantity_ranges: Dictionary = {}
@export var discount_min: float = 0.5
@export var discount_max: float = 1.0

