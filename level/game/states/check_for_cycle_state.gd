class_name CheckForCycleState extends State

func enter() -> void:
	fsm.clear_resolution_context()
	var cycle_ids := fsm.board_controller.find_cycle_participants()
	if not cycle_ids.is_empty():
		fsm.pending_destroy_ids.assign(cycle_ids)
		fsm.pending_score_enabled = true
		change_to(fsm.destroy_card_state)
		return
	if fsm.is_board_full():
		fsm.pending_destroy_ids.assign(fsm.board_controller.get_all_card_ids())
		fsm.pending_score_enabled = false
		change_to(fsm.destroy_card_state)
		return
	fsm.go_to_end_turn()
