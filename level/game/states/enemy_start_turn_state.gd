class_name EnemyStartTurnState extends State


func enter() -> void:
	fsm.enemy_turn_count  += 1
	fsm.active_side = GameDecisionEngine.Side.ENEMY
	fsm.level_controller.activate_turn_start_legend(GameDecisionEngine.Side.ENEMY,fsm,fsm.enemy_turn_count)
	fsm.set_state_info("Enemy Start")

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
