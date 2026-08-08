class_name EnemyPlayCardState
extends State


const SPELL_REVEAL_TIME: float = 1.0

@export_range(0.0, 1.0, 0.05)
var spell_play_chance: float = 0.5


func enter() -> void:
	fsm.set_state_info("Enemy Play Card")

	var timer_completed: bool = await fsm.wait_seconds(
		fsm.enemy_think_time,
		self
	)

	if not timer_completed:
		return

	if fsm.current_state != self:
		return

	if fsm.enemy_hand.cards_in_hand.is_empty():
		change_to(fsm.victory_state)
		return

	await _play_enemy_turn()


func _play_enemy_turn() -> void:
	var played_any_card: bool = false

	while fsm.current_state == self:
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

		var playable_spells: Array[SpellCard] = []
		var playable_units: Array[UnitCard] = []

		for card: Card in playable_cards:
			if card is SpellCard:
				playable_spells.append(
					card as SpellCard
				)
			elif card is UnitCard:
				playable_units.append(
					card as UnitCard
				)

		if _should_play_spell(
			playable_spells,
			playable_units,
			played_any_card
		):
			var spell: SpellCard = (
				playable_spells.pick_random()
			)

			var spell_played: bool = await _play_spell_card(
				spell,
				empty_slots.pick_random()
			)

			if fsm.current_state != self:
				return

			if spell_played:
				played_any_card = true
				fsm.reset_forced_skips()

				fsm.rebuild_board_connections()
				fsm.resolve_after_spell_play()
				return

			change_to(fsm.enemy_end_turn_state)
			return

		if not playable_units.is_empty():
			var unit: UnitCard = (
				playable_units.pick_random()
			)

			var unit_played: bool = await _play_unit_card(
				unit,
				empty_slots.pick_random()
			)

			if fsm.current_state != self:
				return

			if not unit_played:
				push_error(
					"EnemyPlayCardState: "
					+ "Could not play selected unit."
				)

				change_to(fsm.enemy_end_turn_state)
				return

			fsm.reset_forced_skips()
			fsm.resolve_after_unit_play()
			return

		if played_any_card:
			fsm.set_state_info(
				"Enemy Has No Unit Card to Play"
			)

			change_to(fsm.enemy_end_turn_state)
			return

		fsm.set_state_info(
			"Enemy Has No Playable Cards"
		)

		if fsm.register_forced_skip():
			change_to(fsm.defeat_state)
			return

		change_to(fsm.enemy_end_turn_state)
		return


func _should_play_spell(playable_spells: Array[SpellCard],playable_units: Array[UnitCard],played_any_card: bool) -> bool:
	if playable_spells.is_empty():
		return false

	if playable_units.is_empty() and not played_any_card:
		return true

	return fsm.rng.randf() <= spell_play_chance
	
func _play_unit_card(unit: UnitCard,slot: CardSlot) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false

	if slot == null or not is_instance_valid(slot):
		return false

	var start_global_position: Vector2 = \
		unit.global_position

	var start_rotation: float = \
		unit.global_rotation

	var start_scale: Vector2 = \
		unit.global_scale

	if not fsm.try_play_card(
		unit,
		slot,
		GameDecisionEngine.Side.ENEMY
	):
		return false

	unit.global_position = start_global_position
	unit.global_rotation = start_rotation
	unit.global_scale = start_scale

	await _animate_card_to_slot(
		unit,
		slot
	)

	if fsm.current_state != self:
		return false

	if not is_instance_valid(unit):
		return false

	unit.set_card_hide(false)

	return true

func _play_spell_card(spell: SpellCard,slot: CardSlot) -> bool:
	if spell == null or not is_instance_valid(spell):
		return false

	if slot == null or not is_instance_valid(slot):
		return false

	var start_global_position: Vector2 = \
		spell.global_position

	var start_rotation: float = \
		spell.global_rotation

	var start_scale: Vector2 = \
		spell.global_scale

	if not fsm.try_play_card(
		spell,
		slot,
		GameDecisionEngine.Side.ENEMY
	):
		return false

	spell.global_position = start_global_position
	spell.global_rotation = start_rotation
	spell.global_scale = start_scale

	await _animate_card_to_slot(
		spell,
		slot
	)

	if fsm.current_state != self:
		return false

	if not is_instance_valid(spell):
		return false

	spell.set_card_hide(false)

	fsm.set_state_info(
		"Enemy Played a Spell"
	)

	var reveal_completed: bool = await fsm.wait_seconds(
		SPELL_REVEAL_TIME,
		self
	)

	if not reveal_completed:
		return false

	if fsm.current_state != self:
		return false

	if not is_instance_valid(spell):
		return false

	return _resolve_spell(spell)

func _resolve_spell(spell: SpellCard) -> bool:
	if spell == null or not is_instance_valid(spell):
		return false

	var play_context: CardPlayContext = \
		fsm.create_card_play_context(
			GameDecisionEngine.Side.ENEMY
		)

	if not spell.is_playable_now(
		play_context
	):
		push_warning(
			"EnemyPlayCardState: "
			+ "Spell is no longer playable."
		)

		_return_spell_to_enemy_hand(spell)
		return false

	if not fsm.has_enough_mana(
		GameDecisionEngine.Side.ENEMY,
		spell.get_mana_cost()
	):
		push_warning(
			"EnemyPlayCardState: "
			+ "Enemy no longer has enough mana."
		)

		_return_spell_to_enemy_hand(spell)
		return false

	var target: UnitCard = null

	if spell.requires_target():
		var valid_targets: Array[UnitCard] = \
			spell.get_valid_targets(
				play_context
			)

		if valid_targets.is_empty():
			push_warning(
				"EnemyPlayCardState: "
				+ "Spell has no valid targets."
			)

			_return_spell_to_enemy_hand(spell)
			return false

		target = valid_targets.pick_random()

	var destination_slot: CardSlot = \
		spell.current_slot

	if destination_slot == null:
		push_error(
			"EnemyPlayCardState: "
			+ "Spell has no destination slot."
		)

		_return_spell_to_enemy_hand(spell)
		return false

	var spell_context := SpellContext.new(
		fsm,
		spell,
		target,
		GameDecisionEngine.Side.ENEMY
	)

	spell_context.destination_slot = \
		destination_slot


	if spell.current_slot != null:
		spell.current_slot.clear_slot(false)
		spell.current_slot = null


	spell.execute(spell_context)

	if not fsm.spend_mana(
		GameDecisionEngine.Side.ENEMY,
		spell.get_mana_cost()
	):
		push_error(
			"EnemyPlayCardState: "
			+ "Mana spending failed."
		)

		if is_instance_valid(spell):
			spell.destroy()

		return false


	if is_instance_valid(spell):
		spell.destroy()

	return true

func _return_spell_to_enemy_hand(spell: SpellCard) -> void:
	if spell == null or not is_instance_valid(spell):
		return

	if spell.current_slot != null:
		spell.current_slot.clear_slot(false)
		spell.current_slot = null

	fsm.enemy_hand.add_existing_card(spell)

func _animate_card_to_slot(card: Card,slot: CardSlot) -> void:
	if not is_instance_valid(card):
		return

	if not is_instance_valid(slot):
		return

	var start_position: Vector2 = \
		card.global_position

	var target_position: Vector2 = \
		slot.global_position

	var middle_position: Vector2 = (
		start_position.lerp(
			target_position,
			0.5
		)
		+ Vector2(
			0.0,
			-100.0
		)
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
