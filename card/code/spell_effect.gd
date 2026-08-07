@abstract
class_name SpellEffect
extends Resource

func can_apply_to(_target: UnitCard) -> bool:
	return true

@abstract
func execute(context: SpellContext) -> void
