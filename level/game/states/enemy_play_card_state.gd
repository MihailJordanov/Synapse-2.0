class_name EnemyPlayCardState extends State


func enter() -> void:
	var timer_completed: bool = await fsm.wait_seconds(
		fsm.enemy_think_time,
		self
	)

	if not timer_completed:
		return

	if fsm.enemy_hand.cards_in_hand.is_empty():
		change_to(fsm.victory_state)
		return

	var empty_slots: Array[CardSlot] = fsm.get_empty_slots(
		GameDecisionEngine.Side.ENEMY
	)

	if empty_slots.is_empty():
		change_to(fsm.check_for_cycle_state)
		return

	var card_index: int = fsm.rng.randi_range(
		0,
		fsm.enemy_hand.cards_in_hand.size() - 1
	)

	var slot_index: int = fsm.rng.randi_range(
		0,
		empty_slots.size() - 1
	)

	var card: Card = fsm.enemy_hand.cards_in_hand[card_index]
	var slot: CardSlot = empty_slots[slot_index]

	print(
		"Enemy attempting move: card_enemy=%s, slot_enemy=%s, slot_registered=%s, slot_occupied=%s"
		% [
			card.is_enemy_card,
			slot.is_enemy_slot,
			fsm.enemy_slots.has(slot),
			slot.card_in_slot
		]
	)

	var was_played: bool = fsm.try_play_card(
		card,
		slot,
		GameDecisionEngine.Side.ENEMY
	)

	if not was_played:
		push_error(
			"EnemyPlayCardState: legal move validation failed."
		)
		change_to(fsm.enemy_end_turn_state)
		return

	change_to(fsm.check_for_cycle_state)
