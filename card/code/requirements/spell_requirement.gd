class_name SpellRequirement
extends RefCounted


func is_satisfied(_context: CardPlayContext) -> bool:
	push_error(
		"SpellRequirement.is_satisfied() must be overridden."
	)
	return false
