class_name EnemyPlayCardState
extends State


const SPELL_REVEAL_TIME: float = 1.0


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

	var playable_cards: Array[Card] = fsm.get_playable_cards(
		fsm.enemy_hand,
		GameDecisionEngine.Side.ENEMY
	)

	if playable_cards.is_empty():
		fsm.set_state_info("Enemy Has No Playable Cards")

		if fsm.register_forced_skip():
			change_to(fsm.defeat_state)
			return

		change_to(fsm.enemy_end_turn_state)
		return

	var card: Card = playable_cards.pick_random()
	var slot: CardSlot = empty_slots.pick_random()

	if card == null or not is_instance_valid(card):
		push_error(
			"EnemyPlayCardState: Invalid selected card."
		)
		change_to(fsm.enemy_end_turn_state)
		return

	if slot == null or not is_instance_valid(slot):
		push_error(
			"EnemyPlayCardState: Invalid selected slot."
		)
		change_to(fsm.enemy_end_turn_state)
		return

	var start_global_position: Vector2 = card.global_position
	var start_rotation: float = card.global_rotation
	var start_scale: Vector2 = card.global_scale

	var was_played: bool = fsm.try_play_card(
		card,
		slot,
		GameDecisionEngine.Side.ENEMY
	)
	
	if was_played:
		fsm.reset_forced_skips()

	if not was_played:
		push_error(
			"EnemyPlayCardState: Legal move validation failed."
		)
		change_to(fsm.enemy_end_turn_state)
		return

	card.global_position = start_global_position
	card.global_rotation = start_rotation
	card.global_scale = start_scale

	await _animate_card_to_slot(card, slot)

	if fsm.current_state != self:
		return

	if not is_instance_valid(card):
		return

	card.set_card_hide(false)

	match card.card_type:
		Card.CardType.UNIT:
			_finish_unit_play()

		Card.CardType.SPELL:
			if not card is SpellCard:
				push_error(
					"EnemyPlayCardState: Card has SPELL type, "
					+ "but is not a SpellCard."
				)

				card.destroy()
				change_to(fsm.check_for_cycle_state)
				return

			await _resolve_spell(card as SpellCard)

		_:
			push_error(
				"EnemyPlayCardState: Unsupported card type."
			)
			card.destroy()
			change_to(fsm.check_for_cycle_state)


func _finish_unit_play() -> void:
	change_to(fsm.check_for_cycle_state)


func _resolve_spell(spell: SpellCard) -> void:
	if spell == null or not is_instance_valid(spell):
		push_error(
			"EnemyPlayCardState: Invalid spell card."
		)
		change_to(fsm.check_for_cycle_state)
		return

	fsm.set_state_info("Enemy Played a Spell")

	var reveal_completed: bool = await fsm.wait_seconds(
		SPELL_REVEAL_TIME,
		self
	)

	if not reveal_completed:
		return

	if fsm.current_state != self:
		return

	if not is_instance_valid(spell):
		return

	var play_context: CardPlayContext = \
		fsm.create_card_play_context(
			GameDecisionEngine.Side.ENEMY
		)

	if not spell.is_playable_now(play_context):
		push_warning(
			"EnemyPlayCardState: Spell is no longer playable."
		)

		_return_spell_to_enemy_hand(spell)
		return

	var target: UnitCard = null

	if spell.requires_target():
		var valid_targets: Array[UnitCard] = \
			spell.get_valid_targets(play_context)

		if valid_targets.is_empty():
			push_warning(
				"EnemyPlayCardState: Spell has no valid targets."
			)

			_return_spell_to_enemy_hand(spell)
			return

		target = valid_targets.pick_random()

	var spell_context := SpellContext.new(
		fsm,
		spell,
		target,
		GameDecisionEngine.Side.ENEMY
	)

	spell.execute(spell_context)

	if is_instance_valid(spell):
		spell.destroy()

	change_to(fsm.check_for_cycle_state)


func _return_spell_to_enemy_hand(
	spell: SpellCard
) -> void:
	if spell == null or not is_instance_valid(spell):
		change_to(fsm.enemy_end_turn_state)
		return

	if spell.current_slot != null:
		spell.current_slot.clear_slot(false)
		spell.current_slot = null

	fsm.enemy_hand.add_existing_card(spell)
	change_to(fsm.enemy_end_turn_state)


func _animate_card_to_slot(
	card: Card,
	slot: CardSlot
) -> void:
	if not is_instance_valid(card):
		return

	if not is_instance_valid(slot):
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
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

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
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

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
