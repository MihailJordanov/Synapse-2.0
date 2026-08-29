class_name RemovePointSpellEffect
extends SpellEffect

const REMOVE_POINT = preload("uid://38h33s3f1mg7")

var amount: int = 1


func _init(new_amount: int = 1) -> void:
	amount = new_amount


func execute(context: SpellContext) -> void:
	if context == null:
		push_error("RemovePointSpellEffect: Missing context.")
		return

	if context.target == null:
		push_error("RemovePointSpellEffect: Missing target.")
		return

	if not is_instance_valid(context.target):
		push_error("RemovePointSpellEffect: Target is no longer valid.")
		return

	context.target.remove_points(amount)
	
	Audio.play_spatial_sound(
		REMOVE_POINT,
		context.target.global_position,
		false,
		false,
		0.25
	)
