extends Node

const SFX_BUTTON := preload("res://Audio/SFXver02/按按钮.wav")
const SFX_PURCHASE_SUCCESS := preload("res://Audio/SFXver02/Item purchase.wav")
const SFX_PURCHASE_DENIED := preload("res://Audio/SFXver02/购买被拒绝（可以不用）.wav")
const SFX_PICKUP := preload("res://Audio/SFXver02/拿起食物.wav")
const SFX_PLACE_A := preload("res://Audio/SFXver02/放置食物1.wav")
const SFX_PLACE_B := preload("res://Audio/SFXver02/放置食物2.wav")
const SFX_STRIP_SLIDE := preload("res://Audio/SFXver02/背包滑动.wav")
const SFX_BATTLE_START := preload("res://Audio/SFXver02/战斗开始1.wav")
const SFX_WIN := preload("res://Audio/SFXver02/Win sound 13.wav")
const SFX_LOSE := preload("res://Audio/SFXver02/Lost sound 4.wav")
const SFX_MONSTER_ATTACK := preload("res://Audio/SFXver02/怪物打击.wav")
const SFX_ROLE_ATTACK_1 := preload("res://Audio/SFXver02/角色攻击1.wav")
const SFX_ROLE_ATTACK_2 := preload("res://Audio/SFXver02/角色攻击2.wav")
const SFX_DEFEAT_A := preload("res://Audio/SFXver02/打败画叉1.wav")
const SFX_DEFEAT_B := preload("res://Audio/SFXver02/打败画叉2.wav")
const SFX_SYNERGY_A := preload("res://Audio/SFXver02/羁绊触发.wav")
const SFX_SYNERGY_B := preload("res://Audio/SFXver02/羁绊触发.wav")
const SFX_SHOP_OPEN := preload("res://Audio/SFXver02/商店开张（可不用）.wav")

var _button_player: AudioStreamPlayer
var _result_player: AudioStreamPlayer
var _pickup_player: AudioStreamPlayer
var _place_player: AudioStreamPlayer
var _slide_player: AudioStreamPlayer
var _battle_player: AudioStreamPlayer
var _synergy_player: AudioStreamPlayer
var _monster_attack_player: AudioStreamPlayer
var _role_attack_player: AudioStreamPlayer
var _next_place_index: int = 0
var _next_defeat_index: int = 0
var _next_synergy_index: int = 0
var _next_role_attack_index: int = 0

func _ready() -> void:
	_button_player = _create_player("ButtonPlayer")
	_result_player = _create_player("ResultPlayer")
	_pickup_player = _create_player("PickupPlayer")
	_place_player = _create_player("PlacePlayer")
	_slide_player = _create_player("SlidePlayer")
	_battle_player = _create_player("BattlePlayer")
	_synergy_player = _create_player("SynergyPlayer")
	_monster_attack_player = _create_player("MonsterAttackPlayer")
	_role_attack_player = _create_player("RoleAttackPlayer")

func play_button() -> void:
	_play_stream(_button_player, SFX_BUTTON)

func play_purchase_success() -> void:
	_play_stream(_result_player, SFX_PURCHASE_SUCCESS)

func play_purchase_denied() -> void:
	_play_stream(_result_player, SFX_PURCHASE_DENIED)

func play_pickup() -> void:
	_play_stream(_pickup_player, SFX_PICKUP)

func play_place() -> void:
	var stream: AudioStream = SFX_PLACE_A if _next_place_index == 0 else SFX_PLACE_B
	_next_place_index = (_next_place_index + 1) % 2
	_play_stream(_place_player, stream)

func play_strip_slide() -> void:
	_play_stream(_slide_player, SFX_STRIP_SLIDE)

func play_battle_start() -> void:
	_play_stream(_battle_player, SFX_BATTLE_START)

func play_battle_win() -> void:
	_play_stream(_battle_player, SFX_WIN)

func play_battle_lose() -> void:
	_play_stream(_battle_player, SFX_LOSE)

func play_monster_attack() -> void:
	_play_stream(_monster_attack_player, SFX_MONSTER_ATTACK)

func play_role_attack() -> void:
	var stream: AudioStream = SFX_ROLE_ATTACK_1 if _next_role_attack_index == 0 else SFX_ROLE_ATTACK_2
	_next_role_attack_index = (_next_role_attack_index + 1) % 2
	_play_stream(_role_attack_player, stream)

func play_defeat_mark() -> void:
	var stream: AudioStream = SFX_DEFEAT_A if _next_defeat_index == 0 else SFX_DEFEAT_B
	_next_defeat_index = (_next_defeat_index + 1) % 2
	_play_stream(_battle_player, stream)

func play_synergy_cue() -> void:
	var stream: AudioStream = SFX_SYNERGY_A if _next_synergy_index == 0 else SFX_SYNERGY_B
	_next_synergy_index = (_next_synergy_index + 1) % 2
	_play_stream(_synergy_player, stream)

func play_shop_open() -> void:
	_play_stream(_result_player, SFX_SHOP_OPEN)

func _create_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	add_child(player)
	return player

func _play_stream(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.play()
