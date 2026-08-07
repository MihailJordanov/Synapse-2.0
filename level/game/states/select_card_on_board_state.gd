class_name SelectCardOnBoardState
extends State


const DIM_MODULATE := Color(0.35, 0.35, 0.35, 0.55)
const NORMAL_MODULATE := Color.WHITE

var valid_targets: Array[UnitCard] = []
var all_board_cards: Array[Card] = []
var selection_finished: bool = false
var original_z_indexes: Dictionary = {}


func enter() -> void:
	fsm.set_state_info("Select Card On Board")

	selection_finished = false
	valid_targets.clear()
	all_board_cards.clear()

	var spell: SpellCard = fsm.active_spell_card

	if spell == null or not is_instance_valid(spell):
		push_error(
			"SelectCardOnBoardState: Missing active spell."
		)
		_abort_selection()
		return

	var play_context: CardPlayContext = fsm.create_card_play_context(fsm.active_side)

	all_board_cards = play_context.board_cards
	valid_targets = spell.get_valid_targets(play_context)

	if valid_targets.is_empty():
		push_warning(
			"SelectCardOnBoardState: No valid targets."
		)
		_return_spell_to_hand(spell)
		return

	_apply_selection_visuals()
	_connect_target_signals()
	
	
func exit() -> void:
	_disconnect_target_signals()
	_clear_selection_visuals()

	valid_targets.clear()
	all_board_cards.clear()


func _connect_target_signals() -> void:
	for target: UnitCard in valid_targets:
		if not target.card_pressed.is_connected(
			_on_card_pressed
		):
			target.card_pressed.connect(
				_on_card_pressed
			)


func _disconnect_target_signals() -> void:
	for target: UnitCard in valid_targets:
		if (
			is_instance_valid(target)
			and target.card_pressed.is_connected(
				_on_card_pressed
			)
		):
			target.card_pressed.disconnect(
				_on_card_pressed
			)


func _on_card_pressed(card: Card) -> void:
	if selection_finished:
		return

	if not card is UnitCard:
		return

	var target := card as UnitCard

	if not valid_targets.has(target):
		return

	selection_finished = true
	_resolve_spell(target)


func _resolve_spell(target: UnitCard) -> void:
	var spell: SpellCard = fsm.active_spell_card

	if spell == null or not is_instance_valid(spell):
		push_error(
			"SelectCardOnBoardState: Spell became invalid."
		)
		_abort_selection()
		return

	if not fsm.has_enough_mana(
		fsm.active_side,
		spell.get_mana_cost()
	):
		_return_spell_to_hand(spell)
		return

	var context := SpellContext.new(
		fsm,
		spell,
		target,
		fsm.active_side
	)

	spell.execute(context)

	if not fsm.spend_mana(
		fsm.active_side,
		spell.get_mana_cost()
	):
		push_error(
			"SelectCardOnBoardState: Mana spending failed."
		)

	fsm.register_player_spell_played()
	fsm.reset_forced_skips()

	spell.destroy()
	fsm.active_spell_card = null

	fsm.rebuild_board_connections()
	fsm.resolve_after_spell_play()
	
	
func _return_spell_to_hand(spell: SpellCard) -> void:
	if spell.current_slot != null:
		spell.current_slot.clear_slot(false)
		spell.current_slot = null

	fsm.player_hand.add_existing_card(spell)

	fsm.active_spell_card = null
	change_to(fsm.player_play_card_state)
func _abort_selection() -> void:
	fsm.active_spell_card = null
	change_to(fsm.check_for_cycle_state)


func _apply_selection_visuals() -> void:
	original_z_indexes.clear()

	for card: Card in all_board_cards:
		if not is_instance_valid(card):
			continue

		original_z_indexes[card] = card.z_index

		if _is_valid_target(card):
			card.modulate = NORMAL_MODULATE
			card.z_index += 100
		else:
			card.modulate = DIM_MODULATE

func _clear_selection_visuals() -> void:
	for card: Card in all_board_cards:
		if not is_instance_valid(card):
			continue

		card.modulate = NORMAL_MODULATE

		if original_z_indexes.has(card):
			card.z_index = int(original_z_indexes[card])

	original_z_indexes.clear()
	

	
	
func _is_valid_target(card: Card) -> bool:
	if not card is UnitCard:
		return false

	return valid_targets.has(card as UnitCard)
