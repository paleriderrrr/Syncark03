extends PopupPanel
class_name BattlePopup

const POPUP_SIZE := Vector2i(1500, 620)
const MAX_VISIBLE_LOG_LINES := 8
const TEX_STAGE_PLAYBACK := preload("res://Art/UI/Battlepage1.png")
const TEX_STAGE_RESULT := preload("res://Art/UI/Battlepage2.png")

@onready var title_label: Label = %TitleLabel
@onready var route_label: Label = %BattleRouteLabel
@onready var stage_art: TextureRect = %StageArt
@onready var hero_labels: Array[Label] = [%Hero1Label, %Hero2Label, %Hero3Label]
@onready var party_meta_label: Label = %PartyMetaLabel
@onready var playback_time_label: Label = %PlaybackTimeLabel
@onready var battle_log: RichTextLabel = %BattleLog
@onready var result_label: Label = %ResultLabel
@onready var monster_name_label: Label = %MonsterNameLabel
@onready var monster_hp_label: Label = %MonsterHpLabel
@onready var monster_meta_label: Label = %MonsterMetaLabel
@onready var close_button: Button = %CloseBattleButton

var _is_playing: bool = false
var _recent_lines: Array[String] = []

func _run_state() -> Node:
	return get_node("/root/RunState")

func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")

func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")

func _ready() -> void:
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	popup_hide.connect(_on_popup_hidden)

func open_battle() -> void:
	if _is_playing:
		return
	_is_playing = true
	close_button.disabled = true
	_ui_sfx().play_battle_start()
	_bgm_player().play_battle()
	var run_state: Node = _run_state()
	var report: Dictionary = CombatEngine.simulate(run_state)
	_prepare_playback(report)
	popup_centered(POPUP_SIZE)
	get_tree().process_frame.connect(_normalize_popup_layout, CONNECT_ONE_SHOT)
	await _play_report(report)
	run_state.apply_battle_report(report)
	_render_final_report(report)
	close_button.disabled = false
	_is_playing = false

func _prepare_playback(report: Dictionary) -> void:
	stage_art.texture = TEX_STAGE_PLAYBACK
	title_label.text = "Battle In Progress - %s" % String(report.get("monster_name", "Unknown"))
	route_label.text = _run_state().get_route_label()
	playback_time_label.text = "Time 0.0s"
	result_label.text = "Timeline playback running..."
	_recent_lines.clear()
	_fill_party_labels(report.get("characters", []), true)
	monster_name_label.text = String(report.get("monster_name", "Unknown"))
	monster_hp_label.text = "HP %.1f / %.1f" % [float(report.get("monster_max_hp", 0.0)), float(report.get("monster_max_hp", 0.0))]
	monster_meta_label.text = "Awaiting combat events..."
	battle_log.clear()

func _play_report(report: Dictionary) -> void:
	var previous_time: float = 0.0
	var has_events: bool = false
	for line in report.get("log", PackedStringArray()):
		var event_time: float = _extract_log_time(line)
		if event_time > previous_time:
			var wait_seconds: float = event_time - previous_time
			await get_tree().create_timer(wait_seconds).timeout
			playback_time_label.text = "Time %.1fs" % event_time
			previous_time = event_time
		if line.contains(" is defeated."):
			_ui_sfx().play_defeat_mark()
		_append_recent_log_line(line)
		has_events = true
	if not has_events:
		await get_tree().create_timer(0.25).timeout
	if float(report.get("duration", 0.0)) > previous_time:
		playback_time_label.text = "Time %.1fs" % float(report.get("duration", 0.0))

func _render_final_report(report: Dictionary) -> void:
	stage_art.texture = TEX_STAGE_RESULT
	if String(report.get("result", "")) == "win":
		_ui_sfx().play_battle_win()
	else:
		_ui_sfx().play_battle_lose()
	title_label.text = "%s - %s" % [String(report.get("title", "Battle")), String(report.get("monster_name", "Unknown"))]
	route_label.text = _run_state().get_route_label()
	playback_time_label.text = "Time %.1fs" % float(report.get("duration", 0.0))
	result_label.text = "Result: %s | Bonus Gold: %d" % [String(report.get("result", "")).to_upper(), int(report.get("bonus_gold", 0))]
	_fill_party_labels(report.get("characters", []), false)
	monster_name_label.text = String(report.get("monster_name", "Unknown"))
	monster_hp_label.text = "HP %.1f / %.1f" % [float(report.get("monster_hp", 0.0)), float(report.get("monster_max_hp", 0.0))]
	monster_meta_label.text = "Duration %.1fs\nBonus Gold %d" % [float(report.get("duration", 0.0)), int(report.get("bonus_gold", 0))]

func _fill_party_labels(characters: Array, pending: bool) -> void:
	var alive_count: int = 0
	for index in range(hero_labels.size()):
		if index >= characters.size():
			hero_labels[index].text = "-"
			continue
		var entry: Dictionary = characters[index]
		var hp_text: String = "%.1f / %.1f" % [float(entry.get("current_hp", 0.0)), float(entry.get("max_hp", 0.0))]
		var status_text: String = "ALIVE" if bool(entry.get("alive", false)) else "DOWN"
		if bool(entry.get("alive", false)):
			alive_count += 1
		hero_labels[index].text = "%s\nHP %s\n%s" % [String(entry.get("name", "Hero")), hp_text, status_text]
	if pending:
		party_meta_label.text = "Party data loaded.\nWaiting for event playback."
	else:
		party_meta_label.text = "Alive Heroes: %d / %d" % [alive_count, characters.size()]

func _append_recent_log_line(line: String) -> void:
	_recent_lines.append(line)
	while _recent_lines.size() > MAX_VISIBLE_LOG_LINES:
		_recent_lines.remove_at(0)
	var rendered_lines: Array[String] = []
	for index in range(_recent_lines.size()):
		var alpha: float = lerpf(0.28, 1.0, float(index + 1) / float(_recent_lines.size()))
		var color_hex: String = Color(0.95, 0.95, 0.95, alpha).to_html()
		rendered_lines.append("[color=#%s]%s[/color]" % [color_hex, _recent_lines[index]])
	battle_log.bbcode_enabled = true
	battle_log.clear()
	battle_log.append_text("\n".join(rendered_lines))

func _extract_log_time(line: String) -> float:
	var close_index: int = line.find("s]")
	if not line.begins_with("[") or close_index <= 1:
		return 0.0
	return float(line.substr(1, close_index - 1))

func _normalize_popup_layout() -> void:
	if not visible:
		return
	popup_centered(POPUP_SIZE)

func _on_close_pressed() -> void:
	if _is_playing:
		return
	_ui_sfx().play_button()
	hide()

func _on_popup_hidden() -> void:
	_bgm_player().play_non_battle()
