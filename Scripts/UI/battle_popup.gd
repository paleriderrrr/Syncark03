extends PopupPanel
class_name BattlePopup

const PLAYBACK_SPEED := 6.0
const MAX_EVENT_DELAY := 0.5

@onready var title_label: Label = %TitleLabel
@onready var route_label: Label = %BattleRouteLabel
@onready var monster_label: Label = %MonsterLabel
@onready var party_label: Label = %PartyLabel
@onready var monster_hp_label: Label = %MonsterHpLabel
@onready var battle_log: RichTextLabel = %BattleLog
@onready var close_button: Button = %CloseBattleButton

var _is_playing: bool = false

func _run_state() -> Node:
	return get_node("/root/RunState")

func _ready() -> void:
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_pressed)

func open_battle() -> void:
	if _is_playing:
		return
	_is_playing = true
	close_button.disabled = true
	var run_state: Node = _run_state()
	var report: Dictionary = CombatEngine.simulate(run_state)
	_prepare_playback(report)
	popup_centered(Vector2i(960, 500))
	await _play_report(report)
	run_state.apply_battle_report(report)
	_render_final_report(report)
	close_button.disabled = false
	_is_playing = false

func _prepare_playback(report: Dictionary) -> void:
	title_label.text = "战斗进行中 - %s" % report.get("monster_name", "未知怪物")
	route_label.text = _run_state().get_route_label()
	monster_label.text = "怪物: %s" % report.get("monster_name", "未知怪物")
	monster_hp_label.text = "时间: 0.0s"
	party_label.text = "正在按时间演算战斗..."
	battle_log.clear()

func _play_report(report: Dictionary) -> void:
	var previous_time: float = 0.0
	var has_events: bool = false
	for line in report.get("log", PackedStringArray()):
		var event_time: float = _extract_log_time(line)
		if event_time > previous_time:
			var wait_seconds: float = minf(MAX_EVENT_DELAY, (event_time - previous_time) / PLAYBACK_SPEED)
			await get_tree().create_timer(wait_seconds).timeout
			monster_hp_label.text = "时间: %.1fs" % event_time
			previous_time = event_time
		battle_log.append_text("%s\n" % line)
		has_events = true
	if not has_events:
		await get_tree().create_timer(0.25).timeout
	if float(report.get("duration", 0.0)) > previous_time:
		monster_hp_label.text = "时间: %.1fs" % float(report.get("duration", 0.0))

func _render_final_report(report: Dictionary) -> void:
	title_label.text = "%s - %s" % [report.get("title", "战斗"), report.get("monster_name", "未知怪物")]
	route_label.text = _run_state().get_route_label()
	monster_label.text = "怪物: %s" % report.get("monster_name", "未知怪物")
	monster_hp_label.text = "怪物剩余生命: %.1f / %.1f" % [float(report.get("monster_hp", 0.0)), float(report.get("monster_max_hp", 0.0))]
	var party_lines: Array[String] = []
	for entry in report.get("characters", []):
		party_lines.append("%s: %.1f / %.1f %s" % [
			entry.get("name", "角色"),
			float(entry.get("current_hp", 0.0)),
			float(entry.get("max_hp", 0.0)),
			"(存活)" if bool(entry.get("alive", false)) else "(倒下)",
		])
	party_label.text = "\n".join(party_lines)

func _extract_log_time(line: String) -> float:
	var close_index: int = line.find("s]")
	if not line.begins_with("[") or close_index <= 1:
		return 0.0
	return float(line.substr(1, close_index - 1))

func _on_close_pressed() -> void:
	if _is_playing:
		return
	hide()
