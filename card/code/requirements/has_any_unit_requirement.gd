class_name HasAnyUnitRequirement
extends SpellRequirement


func is_satisfied(context: CardPlayContext) -> bool:
	if context == null:
		return false

	for card: Card in context.board_cards:
		if card is UnitCard:
			return true

	return false
