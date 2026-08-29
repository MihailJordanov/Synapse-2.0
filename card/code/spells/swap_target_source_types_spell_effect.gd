class_name SwapTargetSourceTypesSpellEffect
extends SpellEffect

const SWAP_TYPES = preload("uid://dalho0ho32160")

func can_apply_to(target: UnitCard) -> bool:
	if target == null:
		return false

	if not is_instance_valid(target):
		return false

	return target.target_types != target.source_types


func execute(context: SpellContext) -> void:
	if context == null:
		push_error(
			"SwapTargetSourceTypesSpellEffect: Missing context."
		)
		return

	if context.target == null:
		push_error(
			"SwapTargetSourceTypesSpellEffect: Missing target."
		)
		return

	if not can_apply_to(context.target):
		return

	context.target.swap_target_and_source_types()
	
	Audio.play_spatial_sound(
		SWAP_TYPES,
		context.target.global_position,
		false,
		false,
		0.35
	)
