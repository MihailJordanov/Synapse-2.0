class_name DestroyCardState
extends State


func enter() -> void:
	fsm.set_state_info("Destroying cards")

	var removed_cards := (fsm.board_controller.remove_cards(fsm.pending_destroy_ids))

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
		fsm.grant_mana_from_destroyed_cards(
			destroyed_player_cards,
			destroyed_enemy_cards
		)

	for card in removed_cards:
		if is_instance_valid(card):
			card.destroy()

	fsm.pending_destroy_ids.clear()
	fsm.clear_cycle_visualization()


	if fsm.pending_score_enabled:
		await _draw_cycle_reward_spell()

		if fsm.current_state != self:
			return

		change_to(fsm.sum_points_state)
		return


	fsm.clear_resolution_context()
	fsm.finish_resolution()
	
func _draw_cycle_reward_spell() -> void:

	var explosion_wait_completed: bool = await fsm.wait_seconds(0.5,self)

	if not explosion_wait_completed:
		return

	if fsm.current_state != self:
		return

	var drawn_spell: Card = fsm.draw_spell_card_for_side(fsm.active_side)

	if drawn_spell == null:
		return

	if fsm.active_side == GameDecisionEngine.Side.PLAYER:
		fsm.set_state_info("Cycle Reward!\nYou drew a spell card.")
	else:
		fsm.set_state_info("Enemy drew a spell card.")

	await fsm.wait_seconds(1.0,self)
