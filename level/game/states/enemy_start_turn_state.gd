class_name EnemyStartTurnState extends State


func enter() -> void:
	fsm.active_side = GameDecisionEngine.Side.ENEMY

	var hand_is_empty: bool = \
		fsm.enemy_hand.cards_in_hand.is_empty()

	var deck_is_empty: bool = \
		fsm.enemy_hand.deck.is_empty()

	if hand_is_empty and deck_is_empty:
		change_to(fsm.victory_state)
		return

	if not deck_is_empty:
		change_to(fsm.enemy_draw_card_state)
	else:
		change_to(fsm.enemy_play_card_state)
