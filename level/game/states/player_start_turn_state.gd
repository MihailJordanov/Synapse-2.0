class_name PlayerStartTurnState extends State


func enter() -> void:
	fsm.active_side = GameDecisionEngine.Side.PLAYER
	fsm.set_state_info("Player Start")

	var hand_is_empty: bool = \
		fsm.player_hand.cards_in_hand.is_empty()

	var deck_is_empty: bool = \
		fsm.player_hand.deck.is_empty()

	if hand_is_empty and deck_is_empty:
		change_to(fsm.defeat_state)
		return

	if not deck_is_empty:
		change_to(fsm.player_draw_card_state)
	else:
		change_to(fsm.player_play_card_state)
