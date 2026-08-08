class_name StealEnemyUnitSpellEffect
extends SpellEffect


func can_apply_to(target: UnitCard) -> bool:
	if target == null:
		return false

	if not is_instance_valid(target):
		return false

	if target.current_slot == null:
		return false

	return true


func execute(context: SpellContext) -> void:
	if context == null:
		push_error(
			"StealEnemyUnitSpellEffect: Missing context."
		)
		return

	var target: UnitCard = context.target
	var destination_slot: CardSlot = context.destination_slot
	var spell: SpellCard = context.spell_card

	if target == null or not is_instance_valid(target):
		push_error(
			"StealEnemyUnitSpellEffect: Missing target."
		)
		return

	if destination_slot == null:
		push_error(
			"StealEnemyUnitSpellEffect: Missing destination slot."
		)
		return

	if spell == null or not is_instance_valid(spell):
		push_error(
			"StealEnemyUnitSpellEffect: Missing spell."
		)
		return

	if not can_apply_to(target):
		push_warning(
			"StealEnemyUnitSpellEffect: Invalid target."
		)
		return

	var old_slot: CardSlot = target.current_slot

	if old_slot != null:
		old_slot.remove_card_reference(target)

	destination_slot.remove_card_reference(spell)

	target.is_enemy_card = (
		context.caster_side
		== GameDecisionEngine.Side.ENEMY
	)

	if not destination_slot.place_card(target):
		push_error(
			"StealEnemyUnitSpellEffect: "
			+ "Could not place captured unit."
		)
		return
