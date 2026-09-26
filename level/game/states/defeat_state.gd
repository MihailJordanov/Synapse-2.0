class_name DefeatState
extends State

const DEFEAT_SFX = preload("uid://ba7yp1k5xa8we")

@onready var lose_panel: Panel = %LosePanel
@onready var defeat_info_label: RichTextLabel = %DefeatInfoLabel
@onready var exit_on_defeat_button: Button = %ExitOnDefeatButton
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var music_auto_trigger: MusicAutoTrigger = %MusicAutoTrigger

var reward_granted: bool = false
var received_money: int = 0


func _ready() -> void:
	exit_on_defeat_button.pressed.connect(_on_exit_on_defeat_button_pressed)


func enter() -> void:
	fsm.game_finished.emit(false)

	VisualEffects.camera_shake(10)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	fsm.level_controller.hide_pause_button()

	if not reward_granted:
		received_money = _get_defeat_money_reward()
		reward_granted = true

	_update_defeat_info()

	lose_panel.show()
	music_auto_trigger.pause_music()
	Audio.play_spatial_sound(DEFEAT_SFX, Vector2(800, 450))
	animation_player.play("on_defeat_show")

	print("Defeat!")


func _get_defeat_money_reward() -> int:
	var money_range: Vector2i = fsm.level_controller.level_setup.money_reward_range
	var minimum_money: int = mini(money_range.x, money_range.y)
	var maximum_money: int = maxi(money_range.x, money_range.y)
	var random_money: int = fsm.rng.randi_range(minimum_money, maximum_money)

	return floori(random_money / 4.0)


func _update_defeat_info() -> void:
	var defeat_reason: String = ""

	if fsm.enemy_score >= fsm.enemy_winning_score:
		defeat_reason = "The enemy reached the required score before you."
	else:
		defeat_reason = "You have no more cards you can play."

	defeat_info_label.text = "[font_size=64][color=#e9eef5]%s[/color][/font_size]\n\n[font_size=70][color=#ffe28a]+ %d[/color][/font_size] [font_size=62][color=#d9b85f]sh.[/color][/font_size]" % [defeat_reason, received_money]


func _on_exit_on_defeat_button_pressed() -> void:
	var return_scene_path: String = fsm.level_controller.level_setup.return_scene_path

	if return_scene_path.is_empty():
		push_warning("DefeatState: Return scene path is empty.")
		return

	exit_on_defeat_button.disabled = true
	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(return_scene_path)
