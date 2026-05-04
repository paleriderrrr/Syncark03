extends Control
class_name RightInfoBoard

@export var default_poster_texture: Texture2D
@export var more_info_button_normal_texture: Texture2D
@export var more_info_button_hover_texture: Texture2D
@export_range(0.05, 1.0, 0.01) var flip_duration: float = 0.24
@export_range(0.1, 1.0, 0.01) var pressed_button_alpha: float = 0.45

@onready var board_scale: Control = %BoardScale
@onready var front_face: Control = %FrontFace
@onready var back_face: Control = %BackFace
@onready var front_stage_name_label: Label = %FrontStageNameLabel
@onready var front_monster_name_label: Label = %FrontMonsterNameLabel
@onready var front_risk_label: Label = %FrontRiskLabel
@onready var front_bounty_label: Label = %FrontBountyLabel
@onready var back_monster_name_label: Label = %BackMonsterNameLabel
@onready var back_stats_label: Label = %BackStatsLabel
@onready var back_skill_label: Label = %BackSkillLabel
@onready var front_wanted_poster_rect: TextureRect = %FrontWantedPosterRect
@onready var back_wanted_poster_rect: TextureRect = %BackWantedPosterRect
@onready var more_info_button: Button = %MoreInfoButton
@onready var more_info_button_art: TextureRect = %MoreInfoButtonArt
@onready var back_button: Button = %BackButton
@onready var back_button_art: TextureRect = %BackButtonArt

var _showing_front: bool = true
var _flip_tween: Tween

func _ready() -> void:
	resized.connect(_sync_pivot)
	_sync_pivot()
	_show_face(true)
	more_info_button.pressed.connect(func() -> void: flip_to_back())
	more_info_button.mouse_entered.connect(_refresh_button_art)
	more_info_button.mouse_exited.connect(_refresh_button_art)
	back_button.pressed.connect(func() -> void: flip_to_front())
	back_button.mouse_entered.connect(_refresh_button_art)
	back_button.mouse_exited.connect(_refresh_button_art)
	_refresh_button_art()

func apply_summary(summary: Dictionary, poster_texture: Texture2D) -> void:
	var resolved_poster: Texture2D = poster_texture if poster_texture != null else default_poster_texture
	front_stage_name_label.text = String(summary.get("stage_name", "-"))
	front_monster_name_label.text = String(summary.get("monster_name", "-"))
	front_risk_label.text = String(summary.get("risk_text", "-"))
	front_bounty_label.text = String(summary.get("bounty_text", "-"))
	back_monster_name_label.text = String(summary.get("monster_name", "-"))
	back_stats_label.text = String(summary.get("stats_text", "-"))
	back_skill_label.text = String(summary.get("skill_text", "-"))
	front_wanted_poster_rect.texture = resolved_poster
	back_wanted_poster_rect.texture = resolved_poster

func show_front_immediate() -> void:
	if is_instance_valid(_flip_tween):
		_flip_tween.kill()
		_flip_tween = null
	board_scale.scale.x = 1.0
	_show_face(true)
	more_info_button_art.modulate.a = 1.0
	back_button_art.modulate.a = 1.0
	_refresh_button_art()

func is_showing_front() -> bool:
	return _showing_front

func flip_to_back() -> void:
	_flip(false)

func flip_to_front() -> void:
	_flip(true)

func _flip(to_front: bool) -> void:
	if _showing_front == to_front:
		return
	if is_instance_valid(_flip_tween):
		return
	var trigger_art: TextureRect = more_info_button_art if not to_front else back_button_art
	_set_buttons_disabled(true)
	_flip_tween = create_tween()
	_flip_tween.tween_property(trigger_art, "modulate:a", pressed_button_alpha, flip_duration * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(board_scale, "scale:x", 0.0, flip_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(func() -> void:
		_show_face(to_front)
		board_scale.scale.x = 0.0
	)
	_flip_tween.tween_property(board_scale, "scale:x", 1.0, flip_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flip_tween.finished.connect(func() -> void:
		more_info_button_art.modulate.a = 1.0
		back_button_art.modulate.a = 1.0
		_set_buttons_disabled(false)
		_refresh_button_art()
		_flip_tween = null
	)

func _show_face(show_front: bool) -> void:
	_showing_front = show_front
	front_face.visible = show_front
	back_face.visible = not show_front
	more_info_button.visible = show_front
	back_button.visible = not show_front

func _set_buttons_disabled(disabled: bool) -> void:
	more_info_button.disabled = disabled
	back_button.disabled = disabled

func _refresh_button_art() -> void:
	var front_texture: Texture2D = more_info_button_hover_texture if more_info_button.is_hovered() and not more_info_button.disabled else more_info_button_normal_texture
	var back_texture: Texture2D = more_info_button_hover_texture if back_button.is_hovered() and not back_button.disabled else more_info_button_normal_texture
	more_info_button_art.texture = front_texture
	back_button_art.texture = back_texture

func _sync_pivot() -> void:
	board_scale.pivot_offset = board_scale.size * 0.5
