class_name AddPointSpellEffect
extends SpellEffect


var amount: int = 1


func _init(new_amount: int = 1) -> void:
	amount = new_amount


func execute(context: SpellContext) -> void:
	if context == null:
		push_error("AddPointSpellEffect: Missing context.")
		return

	if context.target == null:
		push_error("AddPointSpellEffect: Missing target.")
		return

	if not is_instance_valid(context.target):
		push_error("AddPointSpellEffect: Target is no longer valid.")
		return

	context.target.add_points(amount)
