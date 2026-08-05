class_name PlayerPlayCardState
extends State


var is_skip_available: bool = false


func enter() -> void:
	fsm.set_state_info("Player Play Card")

	if fsm.player_hand.cards_in_hand.is_empty():
		change_to(fsm.defeat_state)
		return

	var empty_slots: Array[CardSlot] = fsm.get_empty_slots(
		GameDecisionEngine.Side.PLAYER
	)

	if empty_slots.is_empty():
		change_to(fsm.check_for_cycle_state)
		return

	var has_playable_card: bool = fsm.has_any_playable_card(
		fsm.player_hand,
		GameDecisionEngine.Side.PLAYER
	)

	if not has_playable_card:
		_enter_skip_mode()
		return

	_enter_play_mode(empty_slots)


func exit() -> void:
	fsm.card_dragger.set_play_context(false, [])

	if fsm.card_dragger.card_drop_requested.is_connected(
		_on_card_drop_requested
	):
		fsm.card_dragger.card_drop_requested.disconnect(
			_on_card_drop_requested
		)

	if fsm.control_button_pressed.is_connected(
		_on_skip_turn_pressed
	):
		fsm.control_button_pressed.disconnect(
			_on_skip_turn_pressed
		)

	fsm.disable_turn_button()
	is_skip_available = false


func _enter_play_mode(
	empty_slots: Array[CardSlot]
) -> void:
	is_skip_available = false

	fsm.set_state_info("Play a card.")
	fsm.disable_turn_button()

	fsm.card_dragger.set_play_context(
		true,
		empty_slots
	)

	if not fsm.card_dragger.card_drop_requested.is_connected(
		_on_card_drop_requested
	):
		fsm.card_dragger.card_drop_requested.connect(
			_on_card_drop_requested
		)


func _enter_skip_mode() -> void:
	is_skip_available = true

	fsm.set_state_info(
		"No playable cards. You may skip your turn."
	)

	fsm.card_dragger.set_play_context(false, [])
	fsm.set_control_button("Skip Turn", true)

	if not fsm.control_button_pressed.is_connected(
		_on_skip_turn_pressed
	):
		fsm.control_button_pressed.connect(
			_on_skip_turn_pressed
		)


func _on_card_drop_requested(
	card: Card,
	slot: CardSlot
) -> void:
	if not fsm.is_card_playable_now(
		card,
		GameDecisionEngine.Side.PLAYER
	):
		fsm.card_dragger.reject_last_drop(card)
		return

	var was_played: bool = fsm.try_play_card(
		card,
		slot,
		GameDecisionEngine.Side.PLAYER
	)
	
	if not was_played:
		fsm.card_dragger.reject_last_drop(card)
		return

	fsm.reset_forced_skips()

	match card.card_type:
		Card.CardType.UNIT:
			change_to(fsm.check_for_cycle_state)

		Card.CardType.SPELL:
			if not card is SpellCard:
				push_error(
					"Card has SPELL type but is not a SpellCard."
				)

				card.destroy()
				change_to(fsm.check_for_cycle_state)
				return

			fsm.active_spell_card = card as SpellCard
			change_to(fsm.player_play_spell_card_state)
			
func _on_skip_turn_pressed() -> void:
	if not is_skip_available:
		return

	if fsm.current_state != self:
		return

	is_skip_available = false

	if fsm.register_forced_skip():
		change_to(fsm.defeat_state)
		return

	var terminal: State = fsm.score_terminal_state()

	if terminal != null:
		change_to(terminal)
		return

	change_to(fsm.enemy_start_turn_state)
