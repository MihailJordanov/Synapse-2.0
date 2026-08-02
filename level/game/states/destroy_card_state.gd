class_name DestroyCardState extends State

func enter() -> void:
	var removed_cards := fsm.board_controller.remove_cards(fsm.pending_destroy_ids)
	for card in removed_cards:
		if not is_instance_valid(card):
			continue
		var points := card.get_points()
		fsm.pending_total_points += points
		if card.is_enemy_card:
			fsm.pending_enemy_owned_points += points
		else:
			fsm.pending_player_owned_points += points
	for card in removed_cards:
		if is_instance_valid(card):
			card.destroy()
	fsm.pending_destroy_ids.clear()
	if fsm.pending_score_enabled:
		change_to(fsm.sum_points_state)
	else:
		fsm.clear_resolution_context()
		fsm.go_to_end_turn()
