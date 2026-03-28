extends PanelContainer
class_name InventoryDropZone

signal drop_received(drag_data: Dictionary)

const NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const HOVER_MODULATE := Color(1.08, 1.08, 1.08, 1.0)

var accepted_sources: Array[StringName] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	modulate = NORMAL_MODULATE

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		modulate = NORMAL_MODULATE
		return false
	var payload: Dictionary = data
	var accepted: bool = accepted_sources.has(payload.get("source", &""))
	modulate = HOVER_MODULATE if accepted else NORMAL_MODULATE
	return accepted

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	modulate = NORMAL_MODULATE
	if not (data is Dictionary):
		return
	drop_received.emit(data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = NORMAL_MODULATE
