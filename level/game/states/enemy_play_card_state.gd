class_name EnemyPlayCardState extends State


func enter() -> void:
	fsm.set_state_info("Enemy Play Card")

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

	var start_global_position: Vector2 = card.global_position
	var start_rotation: float = card.global_rotation
	var start_scale: Vector2 = card.global_scale

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

	card.global_position = start_global_position
	card.global_rotation = start_rotation
	card.global_scale = start_scale

	await _animate_card_to_slot(card, slot)

	if fsm.current_state != self:
		return

	card.set_card_hide(false)

	change_to(fsm.check_for_cycle_state)


func _animate_card_to_slot(card: Card, slot: CardSlot) -> void:
	if not is_instance_valid(card) or not is_instance_valid(slot):
		return

	var start_position: Vector2 = card.global_position
	var target_position: Vector2 = slot.global_position

	var middle_position: Vector2 = (
		start_position.lerp(target_position, 0.5)
		+ Vector2(0.0, -100.0)
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		card,
		"global_position",
		middle_position,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		card,
		"global_rotation",
		0.05,
		0.22
	)

	tween.tween_property(
		card,
		"global_position",
		target_position,
		0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		card,
		"global_rotation",
		slot.global_rotation,
		0.28
	)

	tween.parallel().tween_property(
		card,
		"global_scale",
		Vector2.ONE,
		0.28
	)

	await tween.finished
