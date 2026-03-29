extends PopupPanel
class_name BattlePopup

const POPUP_SIZE := Vector2i(1540, 760)
const ATTACK_ANIMATION_TIME := 0.3
const ATTACK_JUMP_HEIGHT := 36.0
const FLOAT_TEXT_TIME := 0.8
const FLOAT_TEXT_RISE := 42.0
const MAX_VISIBLE_LOG_LINES := 8
const DAMAGE_COLOR := Color(1.0, 0.37, 0.32)
const HEAL_COLOR := Color(0.45, 1.0, 0.58)
const NOTICE_COLOR := Color(1.0, 0.94, 0.60)
const DOWN_TINT := Color(0.45, 0.45, 0.45, 0.9)
const NORMAL_TINT := Color.WHITE
const FLOAT_FONT := preload("res://Art/Fonts/handwriting.ttf")
const MONSTER_TEXTURE_TREE := preload("res://Art/PaperEnemies/tree.png")
const MONSTER_TEXTURE_CREAM := preload("res://Art/PaperEnemies/cream.png")
const MONSTER_TEXTURE_COWDRAGON := preload("res://Art/PaperEnemies/cowdragon.png")
const MONSTER_TEXTURE_WATER := preload("res://Art/PaperEnemies/water.png")
const MONSTER_TEXTURE_BREAD := preload("res://Art/PaperEnemies/bread.png")
const MONSTER_TEXTURE_MUSHROOM := preload("res://Art/PaperEnemies/mushroom.png")

@onready var title_label: Label = %TitleLabel
@onready var route_label: Label = %BattleRouteLabel
@onready var hero_actor_nodes: Array[Control] = [%Hero1Actor, %Hero2Actor, %Hero3Actor]
@onready var hero_portrait_frames: Array[Control] = [%Hero1PortraitFrame, %Hero2PortraitFrame, %Hero3PortraitFrame]
@onready var hero_portrait_sprites: Array[TextureRect] = [%Hero1PortraitSprite, %Hero2PortraitSprite, %Hero3PortraitSprite]
@onready var hero_arena_name_labels: Array[Label] = [%Hero1ArenaNameLabel, %Hero2ArenaNameLabel, %Hero3ArenaNameLabel]
@onready var hero_arena_hp_labels: Array[Label] = [%Hero1ArenaHpLabel, %Hero2ArenaHpLabel, %Hero3ArenaHpLabel]
@onready var playback_time_label: Label = %PlaybackTimeLabel
@onready var battle_log: RichTextLabel = %BattleLog
@onready var result_label: Label = %ResultLabel
@onready var battle_float_layer: Control = %BattleFloatLayer
@onready var monster_actor: Control = %MonsterActor
@onready var monster_portrait_frame: Control = %MonsterPortraitFrame
@onready var monster_portrait_sprite: TextureRect = %MonsterPortraitSprite
@onready var monster_arena_name_label: Label = %MonsterArenaNameLabel
@onready var monster_arena_hp_label: Label = %MonsterArenaHpLabel
@onready var close_button: Button = %CloseBattleButton

var _is_playing: bool = false
var _recent_lines: Array[String] = []
var _display_party: Array[Dictionary] = []
var _display_monster: Dictionary = {}
var _name_to_party_index: Dictionary = {}
var _actor_base_positions: Dictionary = {}
var _actor_base_scales: Dictionary = {}
var _active_attack_animations: Dictionary = {}

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
	set_process(true)
	_cache_actor_base_positions()

func open_battle() -> void:
	if _is_playing:
		return
	_is_playing = true
	close_button.disabled = true
	_ui_sfx().play_battle_start()
	_bgm_player().play_battle()
	var run_state: Node = _run_state()
	_display_party = _capture_initial_party_state(run_state)
	_display_monster = _capture_initial_monster_state(run_state)
	_rebuild_name_lookup()
	var report: Dictionary = CombatEngine.simulate(run_state)
	_prepare_playback()
	popup_centered(POPUP_SIZE)
	await get_tree().process_frame
	_normalize_popup_layout()
	await _play_report(report)
	run_state.apply_battle_report(report)
	_render_final_report(report)
	close_button.disabled = false
	_is_playing = false

func _prepare_playback() -> void:
	title_label.text = "Battle In Progress"
	route_label.text = _run_state().get_route_label()
	playback_time_label.text = "Time 0.0s"
	result_label.text = ""
	_recent_lines.clear()
	battle_log.clear()
	_reset_all_attack_animations()
	_refresh_battle_visual_state()

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
		await _process_battle_event(line)
		if line.contains(" is defeated."):
			_ui_sfx().play_defeat_mark()
		_append_recent_log_line(line)
		has_events = true
	if not has_events:
		await get_tree().create_timer(0.25).timeout
	if float(report.get("duration", 0.0)) > previous_time:
		playback_time_label.text = "Time %.1fs" % float(report.get("duration", 0.0))

func _render_final_report(report: Dictionary) -> void:
	if String(report.get("result", "")) == "win":
		_ui_sfx().play_battle_win()
	else:
		_ui_sfx().play_battle_lose()
	_apply_final_display_state(report)
	playback_time_label.text = "Time %.1fs" % float(report.get("duration", 0.0))
	result_label.text = ""
	_refresh_battle_visual_state()

func _capture_initial_party_state(run_state: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in run_state.character_roster.characters:
		var preview: Dictionary = CombatEngine.preview_character_actor(run_state, definition.id)
		if preview.is_empty():
			result.append({
				"id": definition.id,
				"name": definition.display_name,
				"current_hp": float(definition.base_hp),
				"max_hp": float(definition.base_hp),
				"alive": true,
			})
			continue
		result.append({
			"id": preview.get("id", definition.id),
			"name": preview.get("name", definition.display_name),
			"current_hp": float(preview.get("current_hp", definition.base_hp)),
			"max_hp": float(preview.get("max_hp", definition.base_hp)),
			"alive": bool(preview.get("alive", true)),
		})
	return result

func _capture_initial_monster_state(run_state: Node) -> Dictionary:
	var summary: Dictionary = run_state.get_next_monster_summary()
	if summary.is_empty():
		return {
			"id": &"",
			"name": "Unknown",
			"current_hp": 0.0,
			"max_hp": 0.0,
			"alive": false,
		}
	return {
		"id": summary.get("id", &""),
		"name": String(summary.get("display_name", "Unknown")),
		"current_hp": float(summary.get("hp", 0.0)),
		"max_hp": float(summary.get("hp", 0.0)),
		"alive": true,
	}

func _rebuild_name_lookup() -> void:
	_name_to_party_index.clear()
	for index in range(_display_party.size()):
		_name_to_party_index[String(_display_party[index].get("name", ""))] = index

func _refresh_battle_visual_state() -> void:
	for index in range(hero_actor_nodes.size()):
		if index >= _display_party.size():
			hero_actor_nodes[index].visible = false
			continue
		hero_actor_nodes[index].visible = true
		var entry: Dictionary = _display_party[index]
		var alive: bool = bool(entry.get("alive", false))
		hero_arena_name_labels[index].text = String(entry.get("name", "Hero"))
		hero_arena_hp_labels[index].text = "HP %.1f / %.1f" % [
			float(entry.get("current_hp", 0.0)),
			float(entry.get("max_hp", 0.0)),
		]
		hero_actor_nodes[index].modulate = NORMAL_TINT if alive else DOWN_TINT
	monster_arena_name_label.text = String(_display_monster.get("name", "Unknown"))
	monster_arena_hp_label.text = "HP %.1f / %.1f" % [
		float(_display_monster.get("current_hp", 0.0)),
		float(_display_monster.get("max_hp", 0.0)),
	]
	monster_portrait_sprite.texture = _monster_texture_for(_display_monster)
	monster_actor.modulate = NORMAL_TINT if bool(_display_monster.get("alive", false)) else DOWN_TINT

func _apply_final_display_state(report: Dictionary) -> void:
	if report.has("characters"):
		_display_party.clear()
		for actor_variant in report["characters"]:
			var actor: Dictionary = actor_variant
			_display_party.append({
				"id": actor.get("id", &""),
				"name": actor.get("name", "Hero"),
				"current_hp": float(actor.get("current_hp", 0.0)),
				"max_hp": float(actor.get("max_hp", 0.0)),
				"alive": bool(actor.get("alive", false)),
			})
		_rebuild_name_lookup()
	_display_monster["id"] = report.get("monster_id", _display_monster.get("id", &""))
	_display_monster["name"] = String(report.get("monster_name", _display_monster.get("name", "Unknown")))
	_display_monster["current_hp"] = maxf(0.0, float(report.get("monster_hp", _display_monster.get("current_hp", 0.0))))
	_display_monster["max_hp"] = float(report.get("monster_max_hp", _display_monster.get("max_hp", 0.0)))
	_display_monster["alive"] = float(_display_monster.get("current_hp", 0.0)) > 0.0

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

func _process_battle_event(line: String) -> void:
	var content: String = _strip_log_timestamp(line)
	if content.is_empty():
		return
	if content.contains(" deals ") and content.contains(" damage to "):
		await _process_damage_event(content)
	elif content.contains(" restores ") and content.ends_with(" HP."):
		_process_heal_event(content)
	elif content.contains(" lands a critical hit for "):
		await _process_critical_event(content)
	elif content.contains(" retaliates for "):
		await _process_retaliate_event(content)
	elif content.contains(" executes "):
		await _process_execute_event(content)
	elif content.ends_with(" is defeated."):
		_process_defeat_event(content)
	elif content.contains(" revives with "):
		_process_revive_event(content)
	elif content.ends_with("Battle enters attrition mode."):
		pass
	else:
		_process_notice_event(content)
	_refresh_battle_visual_state()

func _strip_log_timestamp(line: String) -> String:
	var close_index: int = line.find("] ")
	if close_index == -1:
		return line.strip_edges()
	return line.substr(close_index + 2).strip_edges()

func _process_damage_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" deals ", false, 1)
	if first_split.size() != 2:
		return
	var second_split: PackedStringArray = String(first_split[1]).split(" damage to ", false, 1)
	if second_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var amount: float = float(second_split[0])
	var target_name: String = String(second_split[1]).trim_suffix(".")
	await _play_attack_animation(source_name)
	_apply_damage_to_target(target_name, amount)
	_spawn_floating_text(_resolve_target_node(target_name), "-%.1f" % amount, DAMAGE_COLOR)

func _process_heal_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" restores ", false, 1)
	if first_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var amount: float = float(String(first_split[1]).trim_suffix(" HP."))
	_apply_heal_to_target(source_name, amount)
	_spawn_floating_text(_resolve_target_node(source_name), "+%.1f" % amount, HEAL_COLOR)
	if _is_monster_name(source_name) and content.contains("through Satisfaction"):
		_spawn_notice_text("%s skill" % source_name)

func _process_critical_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" lands a critical hit for ", false, 1)
	if first_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var amount: float = float(String(first_split[1]).trim_suffix("."))
	await _play_attack_animation(source_name)
	_spawn_floating_text(_resolve_actor_node(source_name), "CRIT %.1f" % amount, NOTICE_COLOR)

func _process_retaliate_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" retaliates for ", false, 1)
	if first_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var amount: float = float(String(first_split[1]).trim_suffix(" damage."))
	await _play_attack_animation(source_name)
	_apply_damage_to_target(String(_display_monster.get("name", "")), amount)
	_spawn_floating_text(monster_actor, "-%.1f" % amount, DAMAGE_COLOR)

func _process_execute_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" executes ", false, 1)
	if first_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var target_name: String = String(first_split[1]).trim_suffix(".")
	await _play_attack_animation(source_name)
	_set_target_hp(target_name, 0.0, false)
	_spawn_floating_text(_resolve_target_node(target_name), "EXEC", NOTICE_COLOR)

func _process_defeat_event(content: String) -> void:
	var target_name: String = content.trim_suffix(" is defeated.")
	_set_target_hp(target_name, 0.0, false)
	_spawn_floating_text(_resolve_target_node(target_name), "DOWN", DAMAGE_COLOR)

func _process_revive_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" revives with ", false, 1)
	if first_split.size() != 2:
		return
	var target_name: String = first_split[0]
	var hp_amount: float = float(String(first_split[1]).trim_suffix(" HP."))
	_set_target_hp(target_name, hp_amount, true)
	_spawn_floating_text(_resolve_target_node(target_name), "REVIVE %.1f" % hp_amount, HEAL_COLOR)

func _process_notice_event(content: String) -> void:
	var skill_notice: String = _monster_skill_notice(content)
	if skill_notice != "":
		_spawn_notice_text(skill_notice)

func _monster_skill_notice(content: String) -> String:
	var monster_name: String = String(_display_monster.get("name", ""))
	if monster_name == "" or not content.begins_with(monster_name + " "):
		return ""
	if content.contains("corrosion"):
		return "%s skill" % monster_name
	if content.contains("bento effects"):
		return "%s skill" % monster_name
	if content.contains("heal reduction"):
		return "%s skill" % monster_name
	if content.contains("Burst Charge"):
		return "%s skill" % monster_name
	if content.contains("target order"):
		return "%s skill" % monster_name
	return "%s skill" % monster_name

func _apply_damage_to_target(target_name: String, amount: float) -> void:
	if _is_monster_name(target_name):
		var current_hp: float = maxf(0.0, float(_display_monster.get("current_hp", 0.0)) - amount)
		_display_monster["current_hp"] = current_hp
		_display_monster["alive"] = current_hp > 0.0
		return
	var index: int = int(_name_to_party_index.get(target_name, -1))
	if index < 0 or index >= _display_party.size():
		return
	var actor: Dictionary = _display_party[index]
	var current_hp: float = maxf(0.0, float(actor.get("current_hp", 0.0)) - amount)
	actor["current_hp"] = current_hp
	actor["alive"] = current_hp > 0.0
	_display_party[index] = actor

func _apply_heal_to_target(target_name: String, amount: float) -> void:
	if _is_monster_name(target_name):
		var current_hp: float = minf(float(_display_monster.get("max_hp", 0.0)), float(_display_monster.get("current_hp", 0.0)) + amount)
		_display_monster["current_hp"] = current_hp
		_display_monster["alive"] = current_hp > 0.0
		return
	var index: int = int(_name_to_party_index.get(target_name, -1))
	if index < 0 or index >= _display_party.size():
		return
	var actor: Dictionary = _display_party[index]
	var current_hp: float = minf(float(actor.get("max_hp", 0.0)), float(actor.get("current_hp", 0.0)) + amount)
	actor["current_hp"] = current_hp
	actor["alive"] = current_hp > 0.0
	_display_party[index] = actor

func _set_target_hp(target_name: String, hp_value: float, alive: bool) -> void:
	if _is_monster_name(target_name):
		_display_monster["current_hp"] = hp_value
		_display_monster["alive"] = alive
		return
	var index: int = int(_name_to_party_index.get(target_name, -1))
	if index < 0 or index >= _display_party.size():
		return
	var actor: Dictionary = _display_party[index]
	actor["current_hp"] = hp_value
	actor["alive"] = alive
	_display_party[index] = actor

func _is_monster_name(target_name: String) -> bool:
	return target_name == String(_display_monster.get("name", ""))

func _resolve_actor_node(actor_name: String) -> Control:
	if _is_monster_name(actor_name):
		return monster_actor
	var index: int = int(_name_to_party_index.get(actor_name, -1))
	if index < 0 or index >= hero_actor_nodes.size():
		return null
	return hero_actor_nodes[index]

func _resolve_actor_visual_node(actor_name: String) -> Control:
	if _is_monster_name(actor_name):
		return monster_portrait_frame
	var index: int = int(_name_to_party_index.get(actor_name, -1))
	if index < 0 or index >= hero_portrait_frames.size():
		return null
	return hero_portrait_frames[index]

func _resolve_actor_jump_node(actor_name: String) -> Control:
	return _resolve_actor_visual_node(actor_name)

func _resolve_target_node(target_name: String) -> Control:
	return _resolve_actor_node(target_name)

func _cache_actor_base_positions() -> void:
	for hero_frame in hero_portrait_frames:
		hero_frame.pivot_offset = hero_frame.size * 0.5
		_actor_base_positions[hero_frame] = hero_frame.position
		_actor_base_scales[hero_frame] = hero_frame.scale
	monster_portrait_frame.pivot_offset = monster_portrait_frame.size * 0.5
	_actor_base_positions[monster_portrait_frame] = monster_portrait_frame.position
	_actor_base_scales[monster_portrait_frame] = monster_portrait_frame.scale

func _monster_texture_for(monster_data: Dictionary) -> Texture2D:
	var monster_id: StringName = monster_data.get("id", &"")
	match monster_id:
		&"fruit_tree_king":
			return MONSTER_TEXTURE_TREE
		&"cream_overlord":
			return MONSTER_TEXTURE_CREAM
		&"charging_beast":
			return MONSTER_TEXTURE_COWDRAGON
		&"water_giant":
			return MONSTER_TEXTURE_WATER
		&"bread_knight":
			return MONSTER_TEXTURE_BREAD
		&"spice_wizard":
			return MONSTER_TEXTURE_MUSHROOM
		_:
			return null

func _play_attack_animation(actor_name: String) -> void:
	var visual_node: Control = _resolve_actor_visual_node(actor_name)
	if visual_node == null:
		return
	var base_position: Vector2 = _actor_base_positions.get(visual_node, visual_node.position)
	var base_scale: Vector2 = _actor_base_scales.get(visual_node, visual_node.scale)
	visual_node.pivot_offset = visual_node.size * 0.5
	visual_node.position = base_position
	visual_node.scale = base_scale
	_active_attack_animations[actor_name] = {
		"node": visual_node,
		"elapsed": 0.0,
		"base_position": base_position,
		"base_scale": base_scale,
	}
	await get_tree().create_timer(ATTACK_ANIMATION_TIME).timeout

func _process(delta: float) -> void:
	if _active_attack_animations.is_empty():
		return
	var finished_names: Array[String] = []
	for actor_name_variant in _active_attack_animations.keys():
		var actor_name: String = String(actor_name_variant)
		var animation: Dictionary = _active_attack_animations[actor_name]
		var node: Control = animation.get("node", null) as Control
		if node == null:
			finished_names.append(actor_name)
			continue
		var elapsed: float = float(animation.get("elapsed", 0.0)) + delta
		var progress: float = minf(elapsed / ATTACK_ANIMATION_TIME, 1.0)
		var base_position: Vector2 = animation.get("base_position", node.position)
		var base_scale: Vector2 = animation.get("base_scale", node.scale)
		var jump_offset: float = sin(progress * PI) * ATTACK_JUMP_HEIGHT
		var flip_factor: float = cos(progress * TAU)
		node.position = base_position + Vector2(0.0, -jump_offset)
		node.scale = Vector2(base_scale.x * flip_factor, base_scale.y)
		if progress >= 1.0:
			node.position = base_position
			node.scale = base_scale
			finished_names.append(actor_name)
		else:
			animation["elapsed"] = elapsed
			_active_attack_animations[actor_name] = animation
	for actor_name in finished_names:
		_active_attack_animations.erase(actor_name)

func _reset_all_attack_animations() -> void:
	for actor_name_variant in _active_attack_animations.keys():
		var actor_name: String = String(actor_name_variant)
		var animation: Dictionary = _active_attack_animations[actor_name]
		var node: Control = animation.get("node", null) as Control
		if node == null:
			continue
		node.position = animation.get("base_position", node.position)
		node.scale = animation.get("base_scale", node.scale)
	_active_attack_animations.clear()

func _spawn_floating_text(target_node: Control, text: String, color: Color) -> void:
	if target_node == null:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(180, 36)
	label.add_theme_font_override("font", FLOAT_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = color
	battle_float_layer.add_child(label)
	var target_rect: Rect2 = target_node.get_global_rect()
	var layer_rect: Rect2 = battle_float_layer.get_global_rect()
	label.position = target_rect.get_center() - layer_rect.position - label.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -FLOAT_TEXT_RISE), FLOAT_TEXT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_TIME).from(1.0)
	tween.chain().tween_callback(label.queue_free)

func _spawn_notice_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(360, 40)
	label.add_theme_font_override("font", FLOAT_FONT)
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = NOTICE_COLOR
	battle_float_layer.add_child(label)
	var layer_size: Vector2 = battle_float_layer.size
	label.position = Vector2((layer_size.x - label.size.x) * 0.5, 20.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -20.0), FLOAT_TEXT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_TIME).from(1.0)
	tween.chain().tween_callback(label.queue_free)

func _normalize_popup_layout() -> void:
	if not visible:
		return
	popup_centered(POPUP_SIZE)
	_cache_actor_base_positions()

func _on_close_pressed() -> void:
	if _is_playing:
		return
	_ui_sfx().play_button()
	hide()

func _on_popup_hidden() -> void:
	_reset_all_attack_animations()
	_bgm_player().play_non_battle()
