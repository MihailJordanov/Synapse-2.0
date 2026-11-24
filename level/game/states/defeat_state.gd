class_name DefeatState
extends State

const DEFEAT_SFX = preload("uid://ba7yp1k5xa8we")
const SEAL_ICON_PATH: String = "res://00_global/hud/assets/seal_icon.png"

@export_category("Renew the Rite (continue for Seals)")
@export var renew_seal_cost: int = 30
@export var renew_rewind_rounds: int = 3
@export var renew_enemy_points: int = 3

@onready var lose_panel: Panel = %LosePanel
@onready var defeat_info_label: RichTextLabel = %DefeatInfoLabel
@onready var exit_on_defeat_button: Button = %ExitOnDefeatButton
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var music_auto_trigger: MusicAutoTrigger = %MusicAutoTrigger

#region /// renew the rite UI (UI/LosePanel/RenewRitePanel in main_level.tscn - style it freely)
@onready var _renew_panel: Control = %RenewRitePanel
@onready var _renew_title: RichTextLabel = %RenewTitleLabel
@onready var _rewind_button: Button = %RenewRewindButton
@onready var _points_button: Button = %RenewPointsButton
#endregion

var reward_granted: bool = false
var received_money: int = 0


func _ready() -> void:
	exit_on_defeat_button.pressed.connect(_on_exit_on_defeat_button_pressed)
	_rewind_button.pressed.connect(_on_renew_rewind_pressed)
	_points_button.pressed.connect(_on_renew_points_pressed)
	_renew_panel.hide()


func enter() -> void:
	fsm.game_finished.emit(false)

	VisualEffects.camera_shake(10)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	fsm.level_controller.hide_pause_button()

	# The money is only paid when the player really leaves (Ok..), not when they renew the rite.
	if not reward_granted:
		received_money = _get_defeat_money_reward()
		reward_granted = true

	_update_defeat_info()
	_update_renew_panel()

	exit_on_defeat_button.disabled = false
	lose_panel.show()
	music_auto_trigger.pause_music()
	Audio.play_spatial_sound(DEFEAT_SFX, Vector2(800, 450))
	animation_player.play("on_defeat_show")

	print("Defeat!")


func exit() -> void:
	# Leaving the defeat state = the rite was renewed.
	lose_panel.hide()
	_renew_panel.hide()
	music_auto_trigger.resume_music()
	fsm.level_controller.show_pause_button()


func _get_defeat_money_reward() -> int:
	var money_range: Vector2i = fsm.level_controller.money_reward_range
	var minimum_money: int = mini(money_range.x, money_range.y)
	var maximum_money: int = maxi(money_range.x, money_range.y)
	var random_money: int = fsm.rng.randi_range(minimum_money, maximum_money)

	return floori(random_money / 4.0)


func _is_score_defeat() -> bool:
	return fsm.enemy_score >= fsm.enemy_winning_score


func _update_defeat_info() -> void:
	var defeat_reason: String = ""

	if _is_score_defeat():
		defeat_reason = "The enemy reached the required score before you."
	else:
		defeat_reason = "You have no more cards you can play."

	defeat_info_label.text = "[font_size=64][color=#e9eef5]%s[/color][/font_size]\n[font_size=70][color=#ffe28a]+ %d[/color][/font_size] [img=60x60]res://00_global/hud/assets/money_icon.png[/img]" % [defeat_reason, received_money]


func _on_exit_on_defeat_button_pressed() -> void:
	# The zone that started the level (or the main map after an F6 test run).
	var return_scene_path: String = fsm.level_controller.get_exit_scene_path()

	exit_on_defeat_button.disabled = true
	_rewind_button.disabled = true
	_points_button.disabled = true
	AnalyticsManager.currency_reason("Defeat", fsm.level_controller.get_analytics_level_name())
	PlayerDataManager.add_money(received_money)
	AnalyticsManager.battle_ended("loss", fsm.player_score, fsm.enemy_score, fsm.player_turn_count + fsm.enemy_turn_count)

	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(return_scene_path)


#region /// renew the rite (Seals)

func _update_renew_panel() -> void:
	var seals: int = PlayerDataManager.get_seals()
	var can_pay: bool = PlayerDataManager.has_enough_seals(renew_seal_cost)
	var cost_color: String = "#a1fff0" if can_pay else "#ff5555"
	var rounds: int = mini(renew_rewind_rounds, fsm.level_controller.turn_rewind_rounds_available())

	_renew_title.text = (
		"[center]Renew the rite? [color=%s]%d[/color] [img=36x36]%s[/img]\n" % [cost_color, renew_seal_cost, SEAL_ICON_PATH]
		+ "[font_size=24][color=#9fb6c4]You have %d[/color][/font_size][/center]" % seals
	)

	_rewind_button.text = "Rewind %d turn%s" % [maxi(rounds, 1), "" if rounds == 1 else "s"]
	_rewind_button.disabled = not can_pay or rounds <= 0
	_rewind_button.tooltip_text = "" if rounds > 0 else "No turns to rewind yet."

	_points_button.disabled = not can_pay or not _is_score_defeat()
	_points_button.tooltip_text = "" if _is_score_defeat() else "Only when the enemy won on points."

	_renew_panel.show()


func _pay(option: String) -> bool:
	AnalyticsManager.currency_reason("SecondChance", option)

	if PlayerDataManager.try_spend_seals(renew_seal_cost):
		AnalyticsManager.second_chance_used(option)
		return true

	Audio.ui_error()
	_update_renew_panel()
	return false


func _on_renew_rewind_pressed() -> void:
	var rounds: int = mini(renew_rewind_rounds, fsm.level_controller.turn_rewind_rounds_available())

	if rounds <= 0 or not _pay("rewind"):
		return

	if not fsm.level_controller.request_turn_rewind(rounds, true):
		AnalyticsManager.currency_reason("SecondChance", "refund")
		PlayerDataManager.add_seals(renew_seal_cost)  # refund, nothing happened
		_update_renew_panel()


func _on_renew_points_pressed() -> void:
	if not _is_score_defeat() or not _pay("enemy_minus_points"):
		return

	fsm.enemy_score = maxi(fsm.enemy_score - renew_enemy_points, 0)
	fsm.score_changed.emit(fsm.player_score, fsm.enemy_score)
	fsm.update_game_info_labels()

	# Continue with the turn that would have come next.
	if fsm.active_side == GameDecisionEngine.Side.ENEMY:
		change_to(fsm.player_start_turn_state)
	else:
		change_to(fsm.enemy_start_turn_state)

#endregion
