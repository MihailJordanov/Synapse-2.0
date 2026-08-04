class_name EnemyDrawCardState extends State

func enter() -> void:
	fsm.enemy_hand.draw_card()
	fsm.set_state_info("Enemy Draw Card")
	if not await fsm.wait_seconds(0.3, self):
		return
	change_to(fsm.enemy_play_card_state)
