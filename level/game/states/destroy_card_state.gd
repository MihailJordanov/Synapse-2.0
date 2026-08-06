class_name DestroyCardState
extends State


func enter() -> void:
	fsm.set_state_info("Destroying cards")

	var removed_cards := fsm.board_controller.remove_cards(fsm.pending_destroy_ids)

	var destroyed_player_cards: int = 0
	var destroyed_enemy_cards: int = 0

	for card in removed_cards:
		if not is_instance_valid(card):
			continue

		var points: int = card.get_points()
		fsm.pending_total_points += points

		if card.is_enemy_card:
			destroyed_enemy_cards += 1
			fsm.pending_enemy_owned_points += points
		else:
			destroyed_player_cards += 1
			fsm.pending_player_owned_points += points

	if fsm.pending_score_enabled:
		fsm.grant_mana_from_destroyed_cards(destroyed_player_cards,destroyed_enemy_cards)

	for card in removed_cards:
		if is_instance_valid(card):
			card.destroy()

	fsm.pending_destroy_ids.clear()
	fsm.clear_cycle_visualization()

	if fsm.pending_score_enabled:
		change_to(fsm.sum_points_state)
	else:
		fsm.clear_resolution_context()
		fsm.go_to_end_turn()
