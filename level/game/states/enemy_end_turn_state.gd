class_name EnemyEndTurnState extends State

func enter() -> void:
	var terminal := fsm.score_terminal_state()
	if terminal:
		change_to(terminal)
		return
	change_to(fsm.player_start_turn_state)
