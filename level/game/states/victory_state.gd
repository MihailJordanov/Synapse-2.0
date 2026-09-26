class_name VictoryState
extends State

const VICTORY_SFX = preload("uid://cwy2yyi6qott0")

@onready var victory_panel: Panel = %VictoryPanel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var victory_info_label: RichTextLabel = %VictoryInfoLabel
@onready var music_auto_trigger: MusicAutoTrigger = %MusicAutoTrigger
@onready var exit_on_victory_button: Button = %ExitOnVictoryButton

var rewards_granted: bool = false
var received_money: int = 0
var received_cards: Array[String] = []
var unlocked_levels: Array[String] = []

func _ready() -> void:
	exit_on_victory_button.pressed.connect(_on_exit_on_victory_button_pressed)

func enter() -> void:
	fsm.game_finished.emit(true)

	VisualEffects.camera_shake(10)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	fsm.level_controller.hide_pause_button()

	if not rewards_granted:
		_grant_victory_rewards()
		rewards_granted = true

	_update_victory_info()

	victory_panel.show()
	music_auto_trigger.pause_music()
	Audio.play_spatial_sound(VICTORY_SFX, Vector2(800, 450))
	animation_player.play("on_victory_show")

	print("Victory!")


func _grant_victory_rewards() -> void:
	var level_setup: LevelSetup = fsm.level_controller.level_setup

	if not level_setup.level_id.is_empty():
		LevelManager.defeat_level(level_setup.level_id)

	unlocked_levels = _unlock_new_levels(level_setup.levels_unlocked_on_victory)
	received_money = _get_random_money(level_setup.money_reward_range)
	received_cards = _unlock_random_cards(level_setup.card_rewards)


func _unlock_new_levels(level_ids: Array[String]) -> Array[String]:
	var new_levels: Array[String] = []

	for level_id in level_ids:
		if level_id.is_empty():
			continue

		if LevelManager.is_level_unlocked(level_id):
			continue

		LevelManager.unlock_level(level_id)
		new_levels.append(level_id)

	return new_levels


func _get_random_money(money_range: Vector2i) -> int:
	var minimum_money: int = mini(money_range.x, money_range.y)
	var maximum_money: int = maxi(money_range.x, money_range.y)

	return fsm.rng.randi_range(minimum_money, maximum_money)


func _unlock_random_cards(card_ids: Array[String]) -> Array[String]:
	var new_cards: Array[String] = []

	for card_id_string in card_ids:
		if card_id_string.is_empty():
			continue

		var card_id: int = int(card_id_string)

		if CardManager.is_card_in_collection(card_id):
			continue

		if fsm.rng.randf() >= 0.5:
			continue

		if CardManager.add_card_to_collection(card_id):
			new_cards.append(card_id_string)

	return new_cards


func _update_victory_info() -> void:
	var information: Array[String] = []

	information.append("[font_size=70][color=#ffe28a]+ %d[/color][/font_size] [font_size=62][color=#d9b85f]sh.[/color][/font_size]" % received_money)
	if received_cards.size() == 1:
		information.append("[font_size=70][color=#a1fff0]1[/color][/font_size] [font_size=62][color=#f2f7ff]new card![/color][/font_size]")
	elif received_cards.size() > 1:
		information.append("[font_size=70][color=#a1fff0]%d[/color][/font_size] [font_size=62][color=#f2f7ff]new cards![/color][/font_size]" % received_cards.size())

	if unlocked_levels.size() == 1:
		information.append("[font_size=70][color=#a1fff0]1[/color][/font_size] [font_size=62][color=#f2f7ff]new level![/color][/font_size]")
	elif unlocked_levels.size() > 1:
		information.append("[font_size=70][color=#a1fff0]%d[/color][/font_size] [font_size=62][color=#f2f7ff]new levels![/color][/font_size]" % unlocked_levels.size())

	victory_info_label.text = "\n".join(information)

func _on_exit_on_victory_button_pressed() -> void:
	var return_scene_path: String = fsm.level_controller.level_setup.return_scene_path

	if return_scene_path.is_empty():
		push_warning("VictoryState: Return scene path is empty.")
		return

	exit_on_victory_button.disabled = true
	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(return_scene_path)
