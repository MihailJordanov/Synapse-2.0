@icon("res://resources/icons/controller.svg")
class_name LevelController
extends Node

## Single entry point for a battle. Holds the level data AND runs the level.
##
## Two ways to start:
## 1. From the map  -> ZoneController calls LevelController.prepare_level(...) before
##    changing scene. That data overrides the inspector values, and the player's
##    real data (name, icon, equipped legend, deck) is used.
## 2. Directly (F6 on main_level.tscn) -> the inspector values below are used.
##    Empty player fields fall back to the player's real data.

signal setup_finished

const DEFAULT_LEGEND_ICON = preload("uid://xciqo3d2po72")

## Fallback decks, used only when no Deck resource is set (or the player's deck is empty).
const TEST_PLAYER_UNIT_IDS: Array[int] = [11000, 11007, 11004, 11007, 11008, 11001, 11002, 11003, 11004, 11005]
const TEST_PLAYER_SPELL_IDS: Array[int] = [21001, 21101, 21400, 21100]
const TEST_ENEMY_UNIT_IDS: Array[int] = [11009, 11007, 11002, 11007, 11001, 11001, 11002, 11003, 11004, 11005]
const TEST_ENEMY_SPELL_IDS: Array[int] = [21100, 21102, 21400, 21000]


## Data handed over from the map. Lives between scenes, consumed once in _ready().
class LaunchData:
	var level_id: String = ""
	var enemy_name: String = ""
	var enemy_icon_texture: Texture2D = null
	var enemy_legend: Legend = null
	var enemy_deck: Deck = null
	var player_winning_score: int = 10
	var enemy_winning_score: int = 10
	var levels_unlocked_on_victory: Array[String] = []
	var money_reward_range: Vector2i = Vector2i(15, 20)
	var card_rewards: Array[String] = []
	var return_scene_path: String = ""
	var play_with_tavi: bool = false

static var _launch_data: LaunchData = null


@export_category("Player")
## Test run only. Empty = name from PlayerDataManager.
@export var player_name: String = ""
## Test run only. Empty = icon from PlayerDataManager.
@export var player_icon_texture: Texture2D
## Test run only. Empty = the equipped legend.
@export var player_legend: Legend
## Test run only. Empty = the deck built in the collection.
@export var player_deck: Deck
@export var is_player_start_first: bool = false

@export_category("Enemy")
@export var enemy_name: String = ""
@export var enemy_icon_texture: Texture2D
@export var enemy_legend: Legend
## Empty = built-in test deck.
@export var enemy_deck: Deck

@export_category("Level Rules")
@export_range(1, 100, 1) var player_winning_score: int = 10
@export_range(1, 100, 1) var enemy_winning_score: int = 10
@export_file("*.tscn") var return_scene_path: String = ""

@export_category("Victory Rewards")
@export var level_id: String = ""
@export var levels_unlocked_on_victory: Array[String] = []
@export var money_reward_range: Vector2i = Vector2i(15, 20)
@export var card_rewards: Array[String] = []

@export_category("Helpers")
## Tavi shows hints during the battle (first turn + when the player is idle).
@export var play_with_tavi: bool = false


@onready var game_decision_engine: GameDecisionEngine = %GameDecisionEngine
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var tavi_guide: TaviGuide = %TaviGuide

#region /// intro UI
@onready var player_name_label: RichTextLabel = %PlayerNameLabel
@onready var enemy_name_label: RichTextLabel = %EnemyNameLabel
@onready var player_icon_texture_rect: TextureRect = %PlayerIconTextureRect
@onready var enemy_icon_texture_rect: TextureRect = %EnemyIconTextureRect
#endregion

#region /// legends UI
@onready var player_legend_texture_rect: TextureRect = %PlayerLegendTextureRect
@onready var enemy_legend_texture_rect: TextureRect = %EnemyLegendTextureRect
@onready var legend_info_panel: Panel = %LegendInfoPanel
@onready var legend_info_label: RichTextLabel = %LegendInfoRichTextLabel
@onready var player_legend_ui: Control = %PlayerLegend
@onready var enemy_legend_ui: Control = %EnemyLegend
#endregion

#region /// pause menu
@onready var pause_button: Button = %PauseButton
@onready var pause_panel: Panel = %PausePanel
@onready var resum_button: Button = %ResumButton
@onready var exit_button: Button = %ExitButton
@onready var are_you_sure_panel: Panel = %AreYouSurePanel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton
@onready var lose_panel: Panel = %LosePanel
@onready var victory_panel: Panel = %VictoryPanel
#endregion


var player_deck_cards: Array[Card] = []
var player_spell_deck_cards: Array[Card] = []
var enemy_deck_cards: Array[Card] = []
var enemy_spell_deck_cards: Array[Card] = []

## True when the level was opened from the map, false for a direct test run.
var is_launched_from_map: bool = false
## True once the intro animations are done. SetupState checks it before awaiting setup_finished.
var is_setup_finished: bool = false


#region /// launch

static func prepare_level(
	selected_level_id: String,
	selected_enemy_name: String,
	selected_enemy_texture: Texture2D,
	selected_enemy_legend: Legend,
	selected_enemy_deck: Deck,
	selected_player_winning_score: int,
	selected_enemy_winning_score: int,
	selected_levels_unlocked_on_victory: Array[String],
	selected_money_reward_range: Vector2i,
	selected_card_rewards: Array[String],
	selected_return_scene_path: String,
	selected_play_with_tavi: bool = false
) -> void:
	var data := LaunchData.new()
	data.level_id = selected_level_id
	data.enemy_name = selected_enemy_name
	data.enemy_icon_texture = selected_enemy_texture
	data.enemy_legend = selected_enemy_legend
	data.enemy_deck = selected_enemy_deck
	data.player_winning_score = selected_player_winning_score
	data.enemy_winning_score = selected_enemy_winning_score
	data.levels_unlocked_on_victory = selected_levels_unlocked_on_victory.duplicate()
	data.money_reward_range = selected_money_reward_range
	data.card_rewards = selected_card_rewards.duplicate()
	data.return_scene_path = selected_return_scene_path
	data.play_with_tavi = selected_play_with_tavi
	_launch_data = data


func _ready() -> void:
	_init_panels()

	_resolve_level_data()
	_generate_decks()
	_apply_rules_to_engine()
	_setup_legends_ui()
	_connect_signals()
	tavi_guide.setup(game_decision_engine, play_with_tavi)

	_play_intro()


func _resolve_level_data() -> void:
	if _launch_data != null:
		is_launched_from_map = true
		_apply_launch_data(_launch_data)
		_launch_data = null

	# Player data: always the real one from the map, inspector overrides only in test runs.
	if is_launched_from_map or player_name.is_empty():
		player_name = PlayerDataManager.get_player_name()

	if is_launched_from_map or player_icon_texture == null:
		player_icon_texture = PlayerDataManager.get_player_icon_texture()

	if is_launched_from_map or player_legend == null:
		player_legend = LegendManager.create_equipped_legend_instance()
	else:
		player_legend = player_legend.duplicate(true) as Legend

	# Own copy, so a legend effect with state can never leak into the shared resource.
	if enemy_legend != null:
		enemy_legend = enemy_legend.duplicate(true) as Legend


func _apply_launch_data(data: LaunchData) -> void:
	level_id = data.level_id
	enemy_name = data.enemy_name
	enemy_icon_texture = data.enemy_icon_texture
	enemy_legend = data.enemy_legend
	enemy_deck = data.enemy_deck
	player_winning_score = data.player_winning_score
	enemy_winning_score = data.enemy_winning_score
	levels_unlocked_on_victory = data.levels_unlocked_on_victory.duplicate()
	money_reward_range = data.money_reward_range
	card_rewards = data.card_rewards.duplicate()
	return_scene_path = data.return_scene_path
	play_with_tavi = data.play_with_tavi


func _apply_rules_to_engine() -> void:
	game_decision_engine.player_winning_score = player_winning_score
	game_decision_engine.enemy_winning_score = enemy_winning_score
	game_decision_engine.update_game_info_labels()


func _play_intro() -> void:
	player_name_label.text = player_name
	player_icon_texture_rect.texture = player_icon_texture
	enemy_name_label.text = enemy_name
	enemy_icon_texture_rect.texture = enemy_icon_texture

	animation_player.play("fade_in")
	await animation_player.animation_finished

	animation_player.play("start_battle")
	await animation_player.animation_finished

	is_setup_finished = true
	setup_finished.emit()


func _init_panels() -> void:
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	are_you_sure_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.hide()
	are_you_sure_panel.hide()
	lose_panel.hide()
	victory_panel.hide()
	legend_info_panel.hide()
	hide_pause_button()


func _connect_signals() -> void:
	player_legend_texture_rect.gui_input.connect(_on_player_legend_gui_input)
	enemy_legend_texture_rect.gui_input.connect(_on_enemy_legend_gui_input)
	pause_button.pressed.connect(_on_pause_button_pressed)
	resum_button.pressed.connect(_on_resum_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)

#endregion


#region /// decks

func _generate_decks() -> void:
	var player_unit_ids: Array[int] = []
	var player_spell_ids: Array[int] = []

	if not is_launched_from_map and player_deck != null:
		player_unit_ids = _convert_card_ids_to_int(player_deck.get_unit_card_ids())
		player_spell_ids = _convert_card_ids_to_int(player_deck.get_spell_card_ids())
	else:
		player_unit_ids = CardManager.get_unit_deck()
		player_spell_ids = CardManager.get_spell_deck()

	if player_unit_ids.is_empty():
		push_warning("LevelController: Player unit deck is empty, using the test deck.")
		player_unit_ids = TEST_PLAYER_UNIT_IDS.duplicate()
		player_spell_ids = TEST_PLAYER_SPELL_IDS.duplicate()

	var enemy_unit_ids: Array[int] = TEST_ENEMY_UNIT_IDS.duplicate()
	var enemy_spell_ids: Array[int] = TEST_ENEMY_SPELL_IDS.duplicate()

	if enemy_deck != null:
		enemy_unit_ids = _convert_card_ids_to_int(enemy_deck.get_unit_card_ids())
		enemy_spell_ids = _convert_card_ids_to_int(enemy_deck.get_spell_card_ids())

	player_deck_cards = _create_cards_from_ids(_validate_deck_ids(player_unit_ids, false, "player_deck"))
	player_spell_deck_cards = _create_cards_from_ids(_validate_deck_ids(player_spell_ids, true, "player_spell_deck"))
	enemy_deck_cards = _create_cards_from_ids(_validate_deck_ids(enemy_unit_ids, false, "enemy_deck"))
	enemy_spell_deck_cards = _create_cards_from_ids(_validate_deck_ids(enemy_spell_ids, true, "enemy_spell_deck"))


func _convert_card_ids_to_int(card_ids: Array[String]) -> Array[int]:
	var result: Array[int] = []

	for card_id in card_ids:
		result.append(int(card_id))

	return result


func _is_unit_card_id(card_id: int) -> bool:
	return str(card_id).begins_with("1")


func _is_spell_card_id(card_id: int) -> bool:
	return str(card_id).begins_with("2")


func _validate_deck_ids(card_ids: Array[int], expect_spell_cards: bool, deck_name: String) -> Array[int]:
	var valid_ids: Array[int] = []

	for card_id: int in card_ids:
		var is_valid: bool = _is_spell_card_id(card_id) if expect_spell_cards else _is_unit_card_id(card_id)

		if not is_valid:
			push_warning("LevelController: Card ID %d does not belong in %s and was removed." % [card_id, deck_name])
			continue

		valid_ids.append(card_id)

	return valid_ids


func _create_cards_from_ids(card_ids: Array[int]) -> Array[Card]:
	var result: Array[Card] = []

	for card_id: int in card_ids:
		var card: Card = CardManager.create_card_by_id(card_id)

		if card == null:
			push_warning("LevelController: Could not create card ID %d." % card_id)
			continue

		result.append(card)

	return result

#endregion


#region /// legends

func _setup_legends_ui() -> void:
	if player_legend != null and player_legend.texture != null:
		player_legend_texture_rect.texture = player_legend.texture
	else:
		player_legend_texture_rect.texture = DEFAULT_LEGEND_ICON

	if enemy_legend != null and enemy_legend.texture != null:
		enemy_legend_texture_rect.texture = enemy_legend.texture
	else:
		enemy_legend_texture_rect.texture = DEFAULT_LEGEND_ICON


func get_player_starting_extra_draws() -> int:
	if player_legend == null:
		return 0

	return player_legend.get_starting_extra_draws()


func get_enemy_starting_extra_draws() -> int:
	if enemy_legend == null:
		return 0

	return enemy_legend.get_starting_extra_draws()


func _on_player_legend_gui_input(event: InputEvent) -> void:
	_handle_legend_press(event, player_legend)


func _on_enemy_legend_gui_input(event: InputEvent) -> void:
	_handle_legend_press(event, enemy_legend)


func _handle_legend_press(event: InputEvent, legend: Legend) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_show_legend_info(legend)
		else:
			_hide_legend_info()


func _show_legend_info(legend: Legend) -> void:
	if legend == null:
		legend_info_label.text = (
			"[center]"
			+ "[font_size=64][color=#B8B8B8]No Legend[/color][/font_size]"
			+ "\n\n"
			+ "[font_size=48][color=#808080]No effect[/color][/font_size]"
			+ "[/center]"
		)
	else:
		legend_info_label.text = (
			"[center]"
			+ "[font_size=64][color=#FFD966]" + legend.legend_name + "[/color][/font_size]"
			+ "\n\n"
			+ "[font_size=48][color=#F2F2F2]" + legend.description + "[/color][/font_size]"
			+ "[/center]"
		)

	legend_info_panel.show()


func _hide_legend_info() -> void:
	legend_info_panel.hide()


func play_legend_activation_animation(legend: Legend, side: GameDecisionEngine.Side) -> void:
	if legend == null or animation_player == null:
		return

	if legend.activation_animation_name.is_empty():
		return

	var prefix: String = "player_" if side == GameDecisionEngine.Side.PLAYER else "enemy_"
	var animation_name: StringName = StringName(prefix + String(legend.activation_animation_name))

	if not animation_player.has_animation(animation_name):
		return

	animation_player.play(animation_name)


func activate_turn_start_legend(current_side: GameDecisionEngine.Side, fsm: GameDecisionEngine, turn_number: int) -> void:
	var legend: Legend = player_legend if current_side == GameDecisionEngine.Side.PLAYER else enemy_legend

	if legend == null or legend.effect == null:
		return

	var was_activated: bool = legend.effect.on_turn_start(fsm, current_side, turn_number)

	if was_activated:
		play_legend_activation_animation(legend, current_side)

#endregion


#region /// pause menu

func _on_pause_button_pressed() -> void:
	pause_game()


func _on_resum_button_pressed() -> void:
	resume_game()


func _on_exit_button_pressed() -> void:
	resum_button.hide()
	exit_button.hide()
	are_you_sure_panel.show()


func _on_yes_button_pressed() -> void:
	pass


func _on_no_button_pressed() -> void:
	are_you_sure_panel.hide()
	resum_button.show()
	exit_button.show()


func pause_game() -> void:
	pause_button.hide()
	are_you_sure_panel.hide()
	resum_button.show()
	exit_button.show()
	pause_panel.show()
	tavi_guide.set_paused(true)
	get_tree().paused = true


func resume_game() -> void:
	pause_panel.hide()
	are_you_sure_panel.hide()
	pause_button.show()
	tavi_guide.set_paused(false)
	get_tree().paused = false


func show_pause_button() -> void:
	pause_button.show()
	pause_button.disabled = false


func hide_pause_button() -> void:
	pause_button.hide()
	pause_button.disabled = true

#endregion


## Called from AnimationPlayer method tracks (start_battle etc.).
func play_ui_sound(audio: AudioStream, end_offset: float = 0.0) -> void:
	Audio.play_ui_audio(audio, end_offset)
