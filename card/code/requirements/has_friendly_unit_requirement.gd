class_name HasFriendlyUnitRequirement
extends SpellRequirement


func is_satisfied(context: CardPlayContext) -> bool:
	if context == null:
		return false

	for card: Card in context.board_cards:
		if not card is UnitCard:
			continue

		var unit := card as UnitCard

		if _is_friendly_unit(unit, context.caster_side):
			return true

	return false


func _is_friendly_unit(
	unit: UnitCard,
	caster_side: int
) -> bool:
	match caster_side:
		GameDecisionEngine.Side.PLAYER:
			return not unit.is_enemy_card

		GameDecisionEngine.Side.ENEMY:
			return unit.is_enemy_card

	return false
