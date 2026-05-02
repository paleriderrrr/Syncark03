extends PopupPanel
class_name BattlePopup
const POPUP_SIZE := Vector2i(1600, 900)
const ATTACK_ANIMATION_TIME := 0.3
const ATTACK_JUMP_HEIGHT := 36.0
const FLOAT_TEXT_TIME := 0.8
const FLOAT_TEXT_RISE := 42.0
const DAMAGE_FLOAT_TEXT_RISE := 54.0
const MAX_VISIBLE_LOG_LINES := 8
const DAMAGE_COLOR := Color(1.0, 0.37, 0.32)
const HEAL_COLOR := Color(0.45, 1.0, 0.58)
const NOTICE_COLOR := Color(1.0, 0.94, 0.60)
const DAMAGE_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const DOWN_TINT := Color(0.45, 0.45, 0.45, 0.9)
const NORMAL_TINT := Color.WHITE
const FLOAT_FONT := preload("res://Art/Fonts/handwriting.ttf")
const DEFAULT_FLOAT_FONT_SIZE := 22
const DAMAGE_FLOAT_FONT_SIZE := 48
const DAMAGE_FLOAT_OUTLINE_SIZE := 10
const MONSTER_TEXTURE_TREE := preload("res://Art/PaperEnemies/tree.png")
const MONSTER_TEXTURE_CREAM := preload("res://Art/PaperEnemies/cream.png")
const MONSTER_TEXTURE_COWDRAGON := preload("res://Art/PaperEnemies/cowdragon.png")
const MONSTER_TEXTURE_WATER := preload("res://Art/PaperEnemies/water.png")
const MONSTER_TEXTURE_BREAD := preload("res://Art/PaperEnemies/bread.png")
const MONSTER_TEXTURE_MUSHROOM := preload("res://Art/PaperEnemies/mushroom.png")
const STAGE_BACKGROUND_TEXTURE := preload("res://Art/NewBattleBackground/battle_stage_popup_bg.png")
const STAGE_OVERLAY_TEXTURE := preload("res://Art/NewBattleBackground/battle_stage_overlay.png")
const STAGE_CLOSED_LEFT_CURTAIN_TEXTURE := preload("res://Art/NewBattleBackground/battle_curtain_left_panel.png")
const STAGE_CLOSED_RIGHT_CURTAIN_TEXTURE := preload("res://Art/NewBattleBackground/battle_curtain_right_panel.png")
const STAGE_FRAME_TEXTURE := preload("res://Art/NewBattleBackground/舞台最上层.png")
const START_BUTTON_NORMAL_TEXTURE := preload("res://Art/NewBattleBackground/battle_start_normal.png")
const START_BUTTON_HOVER_TEXTURE := preload("res://Art/NewBattleBackground/battle_start_hover.png")
const CLOSE_BUTTON_NORMAL_TEXTURE := preload("res://Art/NewBattleBackground/battle_close_normal.png")
const CLOSE_BUTTON_HOVER_TEXTURE := preload("res://Art/NewBattleBackground/battle_close_hover.png")
const VICTORY_BANNER_TEXTURE := preload("res://Art/BattleBackground/victory.png")
const DEFEAT_BANNER_TEXTURE := preload("res://Art/BattleBackground/defeat.png")
const RESULT_BANNER_START_OFFSET := 40.0
const RESULT_BANNER_DROP_TIME := 0.42
const RESULT_BANNER_SETTLE_TIME := 0.14
const RESULT_BANNER_OVERSHOOT := 18.0
const FORMATION_SWAP_TIME := 0.22
const HERO_DRAG_HIT_INSET_X := 24.0
const HERO_DRAG_HIT_INSET_Y := 20.0
const HERO_DROP_HIT_INSET_X := 18.0
const HERO_DROP_HIT_INSET_Y := 18.0
const TARGET_BADGE_COLOR := Color(1.0, 0.93, 0.58)
const TARGET_BADGE_OUTLINE_COLOR := Color(0.24, 0.11, 0.05, 0.95)
const BATTLE_REVEAL_TIME := 0.25
const STAGE_PHASE_PREPARATION: StringName = &"preparation"
const STAGE_PHASE_MONSTER_REVEAL: StringName = &"monster_reveal"
const STAGE_PHASE_BATTLE: StringName = &"battle"
const STAGE_PHASE_RESULT: StringName = &"result"
@export var show_timeline_panel: bool = false
@onready var title_label: Label = %TitleLabel
@onready var route_label: Label = %BattleRouteLabel
@onready var header: Control = $Margin/RootVBox/Header
@onready var stage_backdrop: TextureRect = $WindowArt
@onready var stage_overlay_art: TextureRect = %StageArt
@onready var stage_frame_art: TextureRect = %StageOverlay
@onready var left_curtain_panel: TextureRect = %LeftCurtainBlockout
@onready var right_curtain_panel: TextureRect = %RightCurtainBlockout
@onready var hero_actor_nodes: Array[Control] = [%Hero1Actor, %Hero2Actor, %Hero3Actor]
@onready var hero_portrait_frames: Array[Control] = [%Hero1PortraitFrame, %Hero2PortraitFrame, %Hero3PortraitFrame]
@onready var hero_portrait_sprites: Array[TextureRect] = [%Hero1PortraitSprite, %Hero2PortraitSprite, %Hero3PortraitSprite]
@onready var hero_arena_name_labels: Array[Label] = [%Hero1ArenaNameLabel, %Hero2ArenaNameLabel, %Hero3ArenaNameLabel]
@onready var hero_arena_hp_labels: Array[Label] = [%Hero1ArenaHpLabel, %Hero2ArenaHpLabel, %Hero3ArenaHpLabel]
@onready var playback_time_label: Label = %PlaybackTimeLabel
@onready var battle_log: RichTextLabel = %BattleLog
@onready var result_label: Label = %ResultLabel
@onready var timeline_panel: Control = $Margin/RootVBox/TimelinePanel
@onready var battle_float_layer: Control = %BattleFloatLayer
@onready var result_banner: TextureRect = %ResultBanner
@onready var arena_stage: Control = %ArenaStage
@onready var preparation_hint_label: Label = %PreparationHintLabel
@onready var monster_actor: Control = %MonsterActor
@onready var monster_portrait_frame: Control = %MonsterPortraitFrame
@onready var monster_portrait_sprite: TextureRect = %MonsterPortraitSprite
@onready var monster_arena_name_label: Label = %MonsterArenaNameLabel
@onready var monster_arena_hp_label: Label = %MonsterArenaHpLabel
@onready var start_battle_button: Button = %StartBattleButton
@onready var close_button: Button = %CloseBattleButton
var _is_playing: bool = false
var _is_preparing: bool = false
var _recent_lines: Array[String] = []
var _display_party: Array[Dictionary] = []
var _display_monster: Dictionary = {}
var _name_to_party_index: Dictionary = {}
var _actor_base_positions: Dictionary = {}
var _actor_base_scales: Dictionary = {}
var _active_attack_animations: Dictionary = {}
var _result_banner_tween: Tween
var _formation_tween: Tween
var _hero_target_badges: Array[Label] = []
var _default_hero_actor_nodes: Array[Control] = []
var _default_hero_portrait_frames: Array[Control] = []
var _default_hero_portrait_sprites: Array[TextureRect] = []
var _default_hero_arena_name_labels: Array[Label] = []
var _default_hero_arena_hp_labels: Array[Label] = []
var _party_slot_positions: Array[Vector2] = []
var _dragged_actor: Control
var _drag_pointer_offset := Vector2.ZERO
var _result_banner_target_position := Vector2.ZERO
var _result_banner_target_size := Vector2.ZERO
var _stage_phase: StringName = STAGE_PHASE_PREPARATION
func get_stage_phase() -> StringName:
	return _stage_phase
func _run_state() -> Node:
	return get_node("/root/RunState")
func _bgm_player() -> Node:
	return get_node("/root/BgmPlayer")
func _ui_sfx() -> Node:
	return get_node("/root/UiSfxPlayer")
func _ready() -> void:
	_apply_timeline_panel_visibility()
	_configure_stage_controls()
	close_button.pressed.connect(_on_close_pressed)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	start_battle_button.mouse_entered.connect(_on_start_button_hover_entered)
	start_battle_button.mouse_exited.connect(_on_start_button_hover_exited)
	close_button.mouse_entered.connect(_on_close_button_hover_entered)
	close_button.mouse_exited.connect(_on_close_button_hover_exited)
	close_requested.connect(_on_close_pressed)
	popup_hide.connect(_on_popup_hidden)
	for hero_portrait_frame in hero_portrait_frames:
		hero_portrait_frame.gui_input.connect(_on_hero_portrait_frame_gui_input.bind(hero_portrait_frame))
	set_process(true)
	set_process_input(true)
	popup_window = false
	_cache_default_party_node_order()
	_cache_actor_base_positions()
	_cache_party_slot_positions()
	_cache_result_banner_target_rect()
	_create_target_badges()
	_reset_preparation_state()
	_apply_stage_art()
	_configure_stage_visibility()
func open_battle() -> void:
	if _is_playing or _is_preparing:
		return
	_is_preparing = true
	close_button.disabled = false
	start_battle_button.disabled = false
	start_battle_button.visible = true
	preparation_hint_label.visible = true
	_configure_stage_controls()
	var run_state: Node = _run_state()
	_restore_default_party_node_order()
	_display_party = _capture_initial_party_state(run_state)
	_display_monster = _capture_initial_monster_state(run_state)
	_rebuild_name_lookup()
	_prepare_pre_battle_preview()
	_set_stage_phase(STAGE_PHASE_PREPARATION)
	popup_centered(POPUP_SIZE)
	await get_tree().process_frame
	_normalize_popup_layout()
	_set_stage_phase(STAGE_PHASE_PREPARATION)
func _on_start_battle_pressed() -> void:
	if _is_playing or not _is_preparing:
		return
	_is_preparing = false
	_is_playing = true
	start_battle_button.disabled = true
	start_battle_button.visible = false
	preparation_hint_label.visible = false
	close_button.disabled = true
	_ui_sfx().play_battle_start()
	_bgm_player().play_battle()
	await _play_battle_start_reveal()
	var run_state: Node = _run_state()
	var report: Dictionary = CombatEngine.simulate(run_state, _current_party_order())
	_prepare_playback()
	await _play_report(report)
	run_state.apply_battle_report(report)
	await _render_final_report(report)
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
	_reset_result_banner()
	_refresh_battle_visual_state()
	_set_stage_phase(STAGE_PHASE_BATTLE)
func _prepare_pre_battle_preview() -> void:
	title_label.text = "Battle Ready"
	route_label.text = _run_state().get_route_label()
	playback_time_label.text = "Ready"
	result_label.text = ""
	_recent_lines.clear()
	battle_log.clear()
	_reset_all_attack_animations()
	_reset_result_banner()
	_refresh_battle_visual_state()
func _reset_preparation_state() -> void:
	_is_preparing = false
	_dragged_actor = null
	_drag_pointer_offset = Vector2.ZERO
	start_battle_button.disabled = false
	start_battle_button.visible = true
	preparation_hint_label.visible = true
	_stop_formation_animation()
	_apply_party_layout(false)
func _current_party_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for entry_variant in _display_party:
		var entry: Dictionary = entry_variant
		order.append(entry.get("id", &""))
	return order
func _apply_timeline_panel_visibility() -> void:
	timeline_panel.visible = show_timeline_panel
func _apply_stage_art() -> void:
	stage_backdrop.texture = STAGE_BACKGROUND_TEXTURE
	stage_overlay_art.texture = STAGE_OVERLAY_TEXTURE
	stage_frame_art.texture = STAGE_FRAME_TEXTURE
	stage_backdrop.z_index = -10
	stage_overlay_art.z_index = 2
	stage_frame_art.z_index = 30
	left_curtain_panel.z_index = 10
	right_curtain_panel.z_index = 11
func _configure_stage_controls() -> void:
	if start_battle_button.get_parent() != arena_stage:
		start_battle_button.reparent(arena_stage)
	if close_button.get_parent() != arena_stage:
		close_button.reparent(arena_stage)
	if preparation_hint_label.get_parent() != arena_stage:
		preparation_hint_label.reparent(arena_stage)
	header.visible = false
	title_label.visible = false
	route_label.visible = false
	start_battle_button.text = ""
	close_button.text = ""
	start_battle_button.flat = true
	close_button.flat = true
	start_battle_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_battle_button.expand_icon = true
	close_button.expand_icon = true
	start_battle_button.icon = START_BUTTON_NORMAL_TEXTURE
	close_button.icon = CLOSE_BUTTON_NORMAL_TEXTURE
	start_battle_button.z_index = 40
	close_button.z_index = 40
	preparation_hint_label.visible = true
	preparation_hint_label.z_index = 38
func _configure_stage_visibility() -> void:
	left_curtain_panel.visible = false
	right_curtain_panel.visible = true
	stage_frame_art.z_index = 30
	left_curtain_panel.z_index = 10
	right_curtain_panel.z_index = 11
	stage_overlay_art.z_index = 2
	stage_backdrop.z_index = -10
	battle_float_layer.z_index = 45
	result_banner.z_index = 50
	monster_actor.z_index = 5
	for hero_actor in hero_actor_nodes:
		hero_actor.z_index = 5
func _set_button_icon(button: Button, normal_texture: Texture2D, hovered_texture: Texture2D, hovered: bool) -> void:
	button.icon = hovered_texture if hovered else normal_texture
func _on_start_button_hover_entered() -> void:
	_set_button_icon(start_battle_button, START_BUTTON_NORMAL_TEXTURE, START_BUTTON_HOVER_TEXTURE, true)
func _on_start_button_hover_exited() -> void:
	_set_button_icon(start_battle_button, START_BUTTON_NORMAL_TEXTURE, START_BUTTON_HOVER_TEXTURE, false)
func _on_close_button_hover_entered() -> void:
	_set_button_icon(close_button, CLOSE_BUTTON_NORMAL_TEXTURE, CLOSE_BUTTON_HOVER_TEXTURE, true)
func _on_close_button_hover_exited() -> void:
	_set_button_icon(close_button, CLOSE_BUTTON_NORMAL_TEXTURE, CLOSE_BUTTON_HOVER_TEXTURE, false)
func _set_stage_phase(phase: StringName) -> void:
	_stage_phase = phase
	match phase:
		STAGE_PHASE_PREPARATION:
			left_curtain_panel.visible = false
			right_curtain_panel.visible = true
			monster_actor.visible = false
			preparation_hint_label.visible = true
			start_battle_button.visible = true
			close_button.visible = true
		STAGE_PHASE_MONSTER_REVEAL:
			left_curtain_panel.visible = false
			right_curtain_panel.visible = true
			monster_actor.visible = false
			preparation_hint_label.visible = false
		STAGE_PHASE_BATTLE:
			left_curtain_panel.visible = false
			right_curtain_panel.visible = false
			monster_actor.visible = true
			preparation_hint_label.visible = false
		STAGE_PHASE_RESULT:
			left_curtain_panel.visible = false
			right_curtain_panel.visible = false
			monster_actor.visible = true
			preparation_hint_label.visible = false
func _play_battle_start_reveal() -> void:
	_set_stage_phase(STAGE_PHASE_MONSTER_REVEAL)
	await get_tree().create_timer(BATTLE_REVEAL_TIME).timeout
	_set_stage_phase(STAGE_PHASE_BATTLE)
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
	var result: String = String(report.get("result", ""))
	if result == "win":
		_ui_sfx().play_battle_win()
	else:
		_ui_sfx().play_battle_lose()
	_apply_final_display_state(report)
	playback_time_label.text = "Time %.1fs" % float(report.get("duration", 0.0))
	result_label.text = ""
	_refresh_battle_visual_state()
	_set_stage_phase(STAGE_PHASE_RESULT)
	await _play_result_banner(result)
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
func _cache_default_party_node_order() -> void:
	_default_hero_actor_nodes = hero_actor_nodes.duplicate()
	_default_hero_portrait_frames = hero_portrait_frames.duplicate()
	_default_hero_portrait_sprites = hero_portrait_sprites.duplicate()
	_default_hero_arena_name_labels = hero_arena_name_labels.duplicate()
	_default_hero_arena_hp_labels = hero_arena_hp_labels.duplicate()
func _restore_default_party_node_order() -> void:
	hero_actor_nodes = _default_hero_actor_nodes.duplicate()
	hero_portrait_frames = _default_hero_portrait_frames.duplicate()
	hero_portrait_sprites = _default_hero_portrait_sprites.duplicate()
	hero_arena_name_labels = _default_hero_arena_name_labels.duplicate()
	hero_arena_hp_labels = _default_hero_arena_hp_labels.duplicate()
	_apply_party_layout(false)
func _cache_party_slot_positions() -> void:
	_party_slot_positions.clear()
	for hero_actor in hero_actor_nodes:
		_party_slot_positions.append(hero_actor.position)
func _create_target_badges() -> void:
	if not _hero_target_badges.is_empty():
		return
	for hero_actor in hero_actor_nodes:
		var badge := Label.new()
		badge.name = "TargetBadge"
		badge.text = "1"
		badge.position = Vector2(126.0, -18.0)
		badge.size = Vector2(56.0, 32.0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", FLOAT_FONT)
		badge.add_theme_font_size_override("font_size", 24)
		badge.add_theme_color_override("font_color", TARGET_BADGE_COLOR)
		badge.add_theme_constant_override("outline_size", 5)
		badge.add_theme_color_override("font_outline_color", TARGET_BADGE_OUTLINE_COLOR)
		hero_actor.add_child(badge)
		_hero_target_badges.append(badge)
func _refresh_target_badges() -> void:
	for index in range(hero_actor_nodes.size()):
		var badge: Label = hero_actor_nodes[index].get_node_or_null("TargetBadge") as Label
		if badge == null:
			continue
		badge.text = str(index + 1)
		badge.visible = index < _display_party.size()
func _apply_party_layout(animate: bool) -> void:
	_stop_formation_animation()
	if animate:
		_formation_tween = create_tween()
		_formation_tween.set_parallel(true)
	for index in range(hero_actor_nodes.size()):
		var hero_actor: Control = hero_actor_nodes[index]
		var target_position: Vector2 = _party_slot_positions[index]
		hero_actor.z_index = 5
		if animate:
			var track: PropertyTweener = _formation_tween.tween_property(hero_actor, "position", target_position, FORMATION_SWAP_TIME)
			track.set_trans(Tween.TRANS_CUBIC)
			track.set_ease(Tween.EASE_OUT)
		else:
			hero_actor.position = target_position
			hero_actor.scale = Vector2(hero_actor.scale.x, hero_actor.scale.y)
	if animate:
		_formation_tween.finished.connect(func() -> void:
			_formation_tween = null
		)
func _stop_formation_animation() -> void:
	if _formation_tween != null:
		_formation_tween.kill()
		_formation_tween = null
func _swap_party_slots(first_index: int, second_index: int, animate: bool = true) -> void:
	if first_index == second_index:
		return
	if first_index < 0 or second_index < 0:
		return
	if first_index >= _display_party.size() or second_index >= _display_party.size():
		return
	var actor_node: Control = hero_actor_nodes[first_index]
	hero_actor_nodes[first_index] = hero_actor_nodes[second_index]
	hero_actor_nodes[second_index] = actor_node
	var portrait_frame: Control = hero_portrait_frames[first_index]
	hero_portrait_frames[first_index] = hero_portrait_frames[second_index]
	hero_portrait_frames[second_index] = portrait_frame
	var portrait_sprite: TextureRect = hero_portrait_sprites[first_index]
	hero_portrait_sprites[first_index] = hero_portrait_sprites[second_index]
	hero_portrait_sprites[second_index] = portrait_sprite
	var name_label: Label = hero_arena_name_labels[first_index]
	hero_arena_name_labels[first_index] = hero_arena_name_labels[second_index]
	hero_arena_name_labels[second_index] = name_label
	var hp_label: Label = hero_arena_hp_labels[first_index]
	hero_arena_hp_labels[first_index] = hero_arena_hp_labels[second_index]
	hero_arena_hp_labels[second_index] = hp_label
	var entry: Dictionary = _display_party[first_index]
	_display_party[first_index] = _display_party[second_index]
	_display_party[second_index] = entry
	_rebuild_name_lookup()
	_apply_party_layout(animate)
	_refresh_battle_visual_state()
func _rotate_party_target_order_visual() -> void:
	if _display_party.size() <= 1:
		return
	var first_node: Control = hero_actor_nodes[0]
	hero_actor_nodes.remove_at(0)
	hero_actor_nodes.append(first_node)
	var first_frame: Control = hero_portrait_frames[0]
	hero_portrait_frames.remove_at(0)
	hero_portrait_frames.append(first_frame)
	var first_sprite: TextureRect = hero_portrait_sprites[0]
	hero_portrait_sprites.remove_at(0)
	hero_portrait_sprites.append(first_sprite)
	var first_name_label: Label = hero_arena_name_labels[0]
	hero_arena_name_labels.remove_at(0)
	hero_arena_name_labels.append(first_name_label)
	var first_hp_label: Label = hero_arena_hp_labels[0]
	hero_arena_hp_labels.remove_at(0)
	hero_arena_hp_labels.append(first_hp_label)
	var first_entry: Dictionary = _display_party[0]
	_display_party.remove_at(0)
	_display_party.append(first_entry)
	_rebuild_name_lookup()
	_apply_party_layout(true)
	_refresh_battle_visual_state()
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
	_refresh_target_badges()
func _apply_final_display_state(report: Dictionary) -> void:
	if report.has("characters"):
		var report_by_id: Dictionary = {}
		for actor_variant in report["characters"]:
			var actor: Dictionary = actor_variant
			report_by_id[actor.get("id", &"")] = {
				"id": actor.get("id", &""),
				"name": actor.get("name", "Hero"),
				"current_hp": float(actor.get("current_hp", 0.0)),
				"max_hp": float(actor.get("max_hp", 0.0)),
				"alive": bool(actor.get("alive", false)),
			}
		for index in range(_display_party.size()):
			var actor_id: StringName = _display_party[index].get("id", &"")
			if report_by_id.has(actor_id):
				_display_party[index] = report_by_id[actor_id]
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
	elif content.contains(" restores ") and content.contains(" HP"):
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
	_play_attack_sfx_for_source(source_name)
	await _play_attack_animation(source_name)
	_apply_damage_to_target(target_name, amount)
	_spawn_floating_text(
		_resolve_target_node(target_name),
		"-%.1f" % amount,
		DAMAGE_COLOR,
		DAMAGE_FLOAT_FONT_SIZE,
		DAMAGE_FLOAT_TEXT_RISE,
		DAMAGE_OUTLINE_COLOR,
		DAMAGE_FLOAT_OUTLINE_SIZE
	)
func _process_heal_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" restores ", false, 1)
	if first_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var heal_tail: String = String(first_split[1])
	var hp_index: int = heal_tail.find(" HP")
	if hp_index == -1:
		return
	var amount: float = float(heal_tail.substr(0, hp_index))
	_apply_heal_to_target(source_name, amount)
	_spawn_floating_text(_resolve_target_node(source_name), "+%.1f" % amount, HEAL_COLOR)
	if _is_monster_name(source_name):
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
	_play_attack_sfx_for_source(source_name)
	await _play_attack_animation(source_name)
	_apply_damage_to_target(String(_display_monster.get("name", "")), amount)
	_spawn_floating_text(
		monster_actor,
		"-%.1f" % amount,
		DAMAGE_COLOR,
		DAMAGE_FLOAT_FONT_SIZE,
		DAMAGE_FLOAT_TEXT_RISE,
		DAMAGE_OUTLINE_COLOR,
		DAMAGE_FLOAT_OUTLINE_SIZE
	)
func _process_execute_event(content: String) -> void:
	var first_split: PackedStringArray = content.split(" executes ", false, 1)
	if first_split.size() != 2:
		return
	var source_name: String = first_split[0]
	var target_name: String = String(first_split[1]).trim_suffix(".")
	_play_attack_sfx_for_source(source_name)
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
	if content.contains("shifts target order"):
		_rotate_party_target_order_visual()
	var skill_notice: String = _monster_skill_notice(content)
	if skill_notice != "":
		_spawn_notice_text(skill_notice)
func _on_hero_portrait_frame_gui_input(event: InputEvent, hero_portrait_frame: Control) -> void:
	if not _is_preparing or _is_playing:
		return
	var actor_index: int = hero_portrait_frames.find(hero_portrait_frame)
	if actor_index == -1 or actor_index >= _display_party.size():
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit_rect: Rect2 = _hero_drag_hit_rect(actor_index)
		if not hit_rect.has_point(mouse_button.global_position):
			return
		var hero_actor: Control = hero_actor_nodes[actor_index]
		if mouse_button.pressed:
			_begin_party_drag(hero_actor, mouse_button.global_position)
			get_viewport().set_input_as_handled()
		elif _dragged_actor == hero_actor:
			_finish_party_drag(mouse_button.global_position)
			get_viewport().set_input_as_handled()
func _input(event: InputEvent) -> void:
	if _dragged_actor == null:
		return
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event
		_dragged_actor.global_position = mouse_motion.global_position + _drag_pointer_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finish_party_drag(mouse_button.global_position)
			get_viewport().set_input_as_handled()
func _begin_party_drag(hero_actor: Control, pointer_global_position: Vector2) -> void:
	_stop_formation_animation()
	_dragged_actor = hero_actor
	_drag_pointer_offset = hero_actor.global_position - pointer_global_position
	hero_actor.z_index = 60
func _finish_party_drag(pointer_global_position: Vector2) -> void:
	if _dragged_actor == null:
		return
	var source_index: int = hero_actor_nodes.find(_dragged_actor)
	var target_index: int = _find_party_drop_target(pointer_global_position, _dragged_actor)
	_dragged_actor.z_index = 5
	_dragged_actor = null
	if source_index != -1 and target_index != -1 and source_index != target_index:
		_swap_party_slots(source_index, target_index)
	else:
		_apply_party_layout(true)
func _find_party_drop_target(pointer_global_position: Vector2, dragged_actor: Control) -> int:
	var best_index := -1
	var best_distance := INF
	for index in range(hero_actor_nodes.size()):
		var hero_actor: Control = hero_actor_nodes[index]
		if hero_actor == dragged_actor:
			continue
		var rect: Rect2 = _hero_drag_hit_rect(index, true)
		if rect.has_point(pointer_global_position):
			return index
		var distance: float = rect.get_center().distance_to(pointer_global_position)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_distance <= 220.0:
		return best_index
	return -1
func _hero_drag_hit_rect(index: int, for_drop_target: bool = false) -> Rect2:
	if index < 0 or index >= hero_portrait_frames.size():
		return Rect2()
	var rect: Rect2 = hero_portrait_frames[index].get_global_rect()
	var inset_x: float = HERO_DROP_HIT_INSET_X if for_drop_target else HERO_DRAG_HIT_INSET_X
	var inset_y: float = HERO_DROP_HIT_INSET_Y if for_drop_target else HERO_DRAG_HIT_INSET_Y
	rect = rect.grow_individual(-inset_x, -inset_y, -inset_x, -inset_y)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return hero_portrait_frames[index].get_global_rect()
	return rect
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
		var monster_current_hp: float = maxf(0.0, float(_display_monster.get("current_hp", 0.0)) - amount)
		_display_monster["current_hp"] = monster_current_hp
		_display_monster["alive"] = monster_current_hp > 0.0
		return
	var index: int = int(_name_to_party_index.get(target_name, -1))
	if index < 0 or index >= _display_party.size():
		return
	var actor: Dictionary = _display_party[index]
	var actor_current_hp: float = maxf(0.0, float(actor.get("current_hp", 0.0)) - amount)
	actor["current_hp"] = actor_current_hp
	actor["alive"] = actor_current_hp > 0.0
	_display_party[index] = actor
func _apply_heal_to_target(target_name: String, amount: float) -> void:
	if _is_monster_name(target_name):
		var monster_current_hp: float = minf(float(_display_monster.get("max_hp", 0.0)), float(_display_monster.get("current_hp", 0.0)) + amount)
		_display_monster["current_hp"] = monster_current_hp
		_display_monster["alive"] = monster_current_hp > 0.0
		return
	var index: int = int(_name_to_party_index.get(target_name, -1))
	if index < 0 or index >= _display_party.size():
		return
	var actor: Dictionary = _display_party[index]
	var actor_current_hp: float = minf(float(actor.get("max_hp", 0.0)), float(actor.get("current_hp", 0.0)) + amount)
	actor["current_hp"] = actor_current_hp
	actor["alive"] = actor_current_hp > 0.0
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
func _is_party_name(actor_name: String) -> bool:
	return int(_name_to_party_index.get(actor_name, -1)) >= 0
func _play_attack_sfx_for_source(source_name: String) -> void:
	if _is_monster_name(source_name):
		_ui_sfx().play_monster_attack()
	elif _is_party_name(source_name):
		_ui_sfx().play_role_attack()
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
func _spawn_floating_text(
	target_node: Control,
	text: String,
	color: Color,
	font_size: int = DEFAULT_FLOAT_FONT_SIZE,
	rise: float = FLOAT_TEXT_RISE,
	outline_color: Color = Color.TRANSPARENT,
	outline_size: int = 0
) -> void:
	if target_node == null:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(maxf(180.0, font_size * 6.0), maxf(36.0, font_size * 1.9))
	label.add_theme_font_override("font", FLOAT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline_size > 0:
		label.add_theme_constant_override("outline_size", outline_size)
		label.add_theme_color_override("font_outline_color", outline_color)
	label.modulate = Color.WHITE
	label.scale = Vector2(0.82, 0.82)
	battle_float_layer.add_child(label)
	var target_rect: Rect2 = target_node.get_global_rect()
	var layer_rect: Rect2 = battle_float_layer.get_global_rect()
	label.position = target_rect.get_center() - layer_rect.position - label.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -rise), FLOAT_TEXT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
func _play_result_banner(result: String) -> void:
	var banner_texture: Texture2D = null
	match result:
		"win":
			banner_texture = VICTORY_BANNER_TEXTURE
		"lose":
			banner_texture = DEFEAT_BANNER_TEXTURE
	if banner_texture == null:
		_reset_result_banner()
		return
	result_banner.texture = banner_texture
	result_banner.visible = true
	result_banner.modulate = Color.WHITE
	_layout_result_banner(true)
	_result_banner_tween = create_tween()
	_result_banner_tween.tween_property(
		result_banner,
		"position:y",
		_result_banner_target_position.y + RESULT_BANNER_OVERSHOOT,
		RESULT_BANNER_DROP_TIME
	).from(result_banner.position.y).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_result_banner_tween.tween_property(
		result_banner,
		"position:y",
		_result_banner_target_position.y,
		RESULT_BANNER_SETTLE_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _result_banner_tween.finished
	_result_banner_tween = null
func _reset_result_banner() -> void:
	if _result_banner_tween != null:
		_result_banner_tween.kill()
		_result_banner_tween = null
	result_banner.texture = null
	result_banner.visible = false
	result_banner.position = _result_banner_target_position
	result_banner.size = _result_banner_target_size
	result_banner.scale = Vector2.ONE
	result_banner.modulate = Color.WHITE
func _layout_result_banner(start_above_screen: bool) -> void:
	result_banner.size = _result_banner_target_size
	result_banner.position = _result_banner_target_position
	if start_above_screen:
		result_banner.position.y = -result_banner.size.y - RESULT_BANNER_START_OFFSET
func _cache_result_banner_target_rect() -> void:
	_result_banner_target_position = result_banner.position
	_result_banner_target_size = result_banner.size
func _normalize_popup_layout() -> void:
	if not visible:
		return
	popup_centered(POPUP_SIZE)
	_configure_stage_controls()
	_cache_actor_base_positions()
	if result_banner.visible:
		_layout_result_banner(false)
func _on_close_pressed() -> void:
	if _is_playing:
		return
	_ui_sfx().play_button()
	hide()
func _on_popup_hidden() -> void:
	_is_playing = false
	_reset_preparation_state()
	_set_stage_phase(STAGE_PHASE_PREPARATION)
	_reset_all_attack_animations()
	_reset_result_banner()
	_restore_default_party_node_order()
	_bgm_player().play_non_battle()
