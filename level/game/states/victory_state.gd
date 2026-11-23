class_name VictoryState
extends State

const VICTORY_SFX = preload("uid://cwy2yyi6qott0")

## Chance to win each reward card per victory (until its collection limit is reached).
const CARD_REWARD_CHANCE: float = 0.5

@onready var victory_panel: Panel = %VictoryPanel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var victory_info_label: RichTextLabel = %VictoryInfoLabel
@onready var music_auto_trigger: MusicAutoTrigger = %MusicAutoTrigger
@onready var exit_on_victory_button: Button = %ExitOnVictoryButton

var rewards_granted: bool = false
var received_money: int = 0
var received_cards: Array[String] = []
var unlocked_levels: Array[String] = []
var unlocked_features: Array[String] = []
## Zones unlocked by THIS victory (first clear only) -> the zone-complete screen is shown.
var unlocked_zones: Array[String] = []

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
	var level: LevelController = fsm.level_controller

	if not level.level_id.is_empty():
		LevelManager.defeat_level(level.level_id)

	unlocked_levels = _unlock_new_levels(level.levels_unlocked_on_victory)
	received_money = _get_random_money(level.money_reward_range)
	PlayerDataManager.add_money(received_money)
	received_cards = _unlock_random_cards(level.card_rewards)
	received_cards.append_array(_grant_guaranteed_cards(level.guaranteed_card_rewards))
	unlocked_features = _unlock_features(level.features_unlocked_on_victory)
	unlocked_zones = _unlock_zones(level.zones_unlocked_on_victory)

	if _is_zone_cleared(level.zone_level_ids):
		unlocked_levels.append_array(_unlock_new_levels(level.levels_unlocked_on_zone_clear))
		unlocked_zones.append_array(_unlock_zones(level.zones_unlocked_on_zone_clear))


func _grant_guaranteed_cards(card_ids: Array[String]) -> Array[String]:
	var new_cards: Array[String] = []

	for card_id_string in card_ids:
		var card_id: int = int(card_id_string)

		if card_id_string.is_empty():
			continue

		if CardManager.get_card_collection_count(card_id) >= CardManager.get_max_card_copies_in_collection(card_id):
			continue

		if CardManager.add_card_to_collection(card_id):
			new_cards.append(card_id_string)

	return new_cards


## True when every level of the zone is defeated (this victory included).
func _is_zone_cleared(zone_level_ids: Array[String]) -> bool:
	if zone_level_ids.is_empty():
		return false

	for level_id in zone_level_ids:
		if not LevelManager.is_level_defeated(level_id):
			return false

	return true


func _unlock_zones(zone_ids: Array[String]) -> Array[String]:
	var new_zones: Array[String] = []

	for zone_id in zone_ids:
		if ZoneManager.unlock_zone(zone_id):
			new_zones.append(zone_id.strip_edges().to_upper())

	return new_zones


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


func _unlock_features(feature_ids: Array[String]) -> Array[String]:
	var new_features: Array[String] = []

	for feature_id in feature_ids:
		if PlayerDataManager.unlock_feature(feature_id):
			new_features.append(feature_id)

	return new_features


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

		# Keep rolling until the collection limit (max_copies_in_collection in data/cards/*.json).
		if CardManager.get_card_collection_count(card_id) >= CardManager.get_max_card_copies_in_collection(card_id):
			continue

		if fsm.rng.randf() >= CARD_REWARD_CHANCE:
			continue

		if CardManager.add_card_to_collection(card_id):
			new_cards.append(card_id_string)

	return new_cards


func _update_victory_info() -> void:
	var information: Array[String] = []

	information.append("[font_size=70][color=#ffe28a]+ %d[/color][/font_size] [img=60x60]res://00_global/hud/assets/money_icon.png[/img]" % received_money)
	if received_cards.size() == 1:
		information.append("[font_size=70][color=#a1fff0]1[/color][/font_size] [font_size=62][color=#f2f7ff]new card![/color][/font_size]")
	elif received_cards.size() > 1:
		information.append("[font_size=70][color=#a1fff0]%d[/color][/font_size] [font_size=62][color=#f2f7ff]new cards![/color][/font_size]" % received_cards.size())

	if unlocked_levels.size() == 1:
		information.append("[font_size=70][color=#a1fff0]1[/color][/font_size] [font_size=62][color=#f2f7ff]new level![/color][/font_size]")
	elif unlocked_levels.size() > 1:
		information.append("[font_size=70][color=#a1fff0]%d[/color][/font_size] [font_size=62][color=#f2f7ff]new levels![/color][/font_size]" % unlocked_levels.size())

	if not unlocked_zones.is_empty():
		information.append("[font_size=62][color=#a1fff0]New zone unlocked![/color][/font_size]")

	for feature_id in unlocked_features:
		information.append("[font_size=62][color=#f2f7ff]%s unlocked![/color][/font_size]" % feature_id.capitalize())

	victory_info_label.text = "\n".join(information)

func _on_exit_on_victory_button_pressed() -> void:
	# The zone that started the level (or the main map after an F6 test run).
	var return_scene_path: String = fsm.level_controller.get_exit_scene_path()

	# First clear of a zone's last level: Tavi's "zone complete" screen first.
	if not unlocked_zones.is_empty():
		ZoneCompleteScreen.new_zone = unlocked_zones[0]
		return_scene_path = ZoneCompleteScreen.SCENE_PATH
	# After A02: the spell tutorial (once).
	elif SpellTutorial.should_start():
		return_scene_path = SpellTutorial.INTRO_SCENE_PATH

	exit_on_victory_button.disabled = true
	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(return_scene_path)
