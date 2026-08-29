@icon( "res://resources/icons/controller.svg" )
class_name LevelController extends Node

const DEFAULT_LEGEND_ICON = preload("uid://cud08kmrohsno")

@export_category("Legends")

@export var player_legend: Legend
@export var enemy_legend: Legend

@onready var player_legend_texture_rect: TextureRect = %PlayerLegendTextureRect
@onready var enemy_legend_texture_rect: TextureRect = %EnemyLegendTextureRect
@onready var legend_info_panel: Panel = %LegendInfoPanel
@onready var legend_info_label: RichTextLabel = %LegendInfoRichTextLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer



var player_deck: Array[Card] = []
var player_spell_deck: Array[Card] = []

var enemy_deck: Array[Card] = []
var enemy_spell_deck: Array[Card] = []

func _ready() -> void:
	_generate_decks()
	_setup_legends_ui()
	player_legend_texture_rect.gui_input.connect(_on_player_legend_gui_input)
	enemy_legend_texture_rect.gui_input.connect(_on_enemy_legend_gui_input)
	legend_info_panel.hide()


func _generate_decks() -> void:
	player_deck.clear()
	player_spell_deck.clear()
	enemy_deck.clear()
	enemy_spell_deck.clear()

	var player_card_ids: Array[int] = [
		11008,
		11007,
		11004,
		11007,
		11008,
		11001,
		11002,
		11003,
		11004,
		11005
	]

	var player_spell_card_ids: Array[int] = [
		21000,
		21001,
		21002,
		21400
	]

	var enemy_card_ids: Array[int] = [
		11009,
		11007,
		11002,
		11007,
		11001,
		11001,
		11002,
		11003,
		11004,
		11005
	]

	var enemy_spell_card_ids: Array[int] = [
		21000,
		21100,
		21101,
		21400
	]

	player_card_ids = _validate_deck_ids(player_card_ids,false,"player_deck")

	player_spell_card_ids = _validate_deck_ids(player_spell_card_ids,true,"player_spell_deck")

	enemy_card_ids = _validate_deck_ids(enemy_card_ids,false,"enemy_deck")

	enemy_spell_card_ids = _validate_deck_ids(enemy_spell_card_ids,true,"enemy_spell_deck")

	player_deck = _create_cards_from_ids(player_card_ids)

	player_spell_deck = _create_cards_from_ids(player_spell_card_ids)

	enemy_deck = _create_cards_from_ids(enemy_card_ids)

	enemy_spell_deck = _create_cards_from_ids(enemy_spell_card_ids)
			

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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_show_legend_info(player_legend)
			else:
				_hide_legend_info()
				
func _on_enemy_legend_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_show_legend_info(enemy_legend)
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

		legend_info_panel.show()
		return

	legend_info_label.text = (
		"[center]"
		+ "[font_size=64][color=#FFD966]"
		+ legend.legend_name
		+ "[/color][/font_size]"
		+ "\n\n"
		+ "[font_size=48][color=#F2F2F2]"
		+ legend.description
		+ "[/color][/font_size]"
		+ "[/center]"
	)

	legend_info_panel.show()
	
func _hide_legend_info() -> void:
	legend_info_panel.hide()
	
func play_legend_activation_animation(legend: Legend,side: GameDecisionEngine.Side) -> void:
	if legend == null:
		return

	if animation_player == null:
		return

	if legend.activation_animation_name.is_empty():
		return

	var prefix: String = ""

	if side == GameDecisionEngine.Side.PLAYER:
		prefix = "player_"
	else:
		prefix = "enemy_"

	var animation_name: StringName = StringName(prefix + String(legend.activation_animation_name))

	if not animation_player.has_animation(animation_name):
		return

	animation_player.play(animation_name)

func activate_turn_start_legend(current_side: GameDecisionEngine.Side,fsm: GameDecisionEngine,turn_number: int) -> void:
	var legend: Legend = null

	if current_side == GameDecisionEngine.Side.PLAYER:
		legend = player_legend
	else:
		legend = enemy_legend

	if legend == null or legend.effect == null:
		return

	var was_activated: bool = legend.effect.on_turn_start(fsm,current_side,turn_number)

	if was_activated:
		play_legend_activation_animation(legend, current_side)


func _is_unit_card_id(card_id: int) -> bool:
	return str(card_id).begins_with("1")


func _is_spell_card_id(card_id: int) -> bool:
	return str(card_id).begins_with("2")
	
func _validate_deck_ids(card_ids: Array[int],expect_spell_cards: bool,deck_name: String) -> Array[int]:
	var valid_ids: Array[int] = []

	for card_id: int in card_ids:
		var is_valid: bool

		if expect_spell_cards:
			is_valid = _is_spell_card_id(card_id)
		else:
			is_valid = _is_unit_card_id(card_id)

		if not is_valid:
			push_warning(
				"LevelController: Card ID %d does not belong in %s and was removed."
				% [
					card_id,
					deck_name
				]
			)
			continue

		valid_ids.append(card_id)

	return valid_ids
	
func _create_cards_from_ids(card_ids: Array[int]) -> Array[Card]:
	var result: Array[Card] = []

	for card_id: int in card_ids:
		var card: Card = CardManager.create_card_by_id(
			card_id
		)

		if card == null:
			push_warning(
				"LevelController: Could not create card ID %d."
				% card_id
			)
			continue

		result.append(card)

	return result
	
