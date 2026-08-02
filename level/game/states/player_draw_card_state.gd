class_name PlayerDrawCardState extends State

func enter() -> void:
	fsm.player_hand.draw_card()
	if not await fsm.wait_seconds(0.3, self):
		return
	change_to(fsm.player_play_card_state)
