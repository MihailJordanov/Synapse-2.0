class_name ModifyConnectionTypeSpellEffect
extends SpellEffect

const ADD_TYPE = preload("uid://cq350dpaypdct")
const REMOVE_TYPE = preload("uid://bvojnaglmfdqm")


enum ConnectionType {
	TARGET,
	SOURCE
}

enum Operation {
	ADD,
	REMOVE
}


var connection_type: ConnectionType
var operation: Operation
var type_number: int


func _init(
	new_connection_type: ConnectionType,
	new_operation: Operation,
	new_type_number: int
) -> void:
	connection_type = new_connection_type
	operation = new_operation
	type_number = new_type_number


func can_apply_to(target: UnitCard) -> bool:
	if target == null:
		return false

	if not is_instance_valid(target):
		return false

	match connection_type:
		ConnectionType.TARGET:
			return _can_apply_to_target_types(target)

		ConnectionType.SOURCE:
			return _can_apply_to_source_types(target)

	return false


func _can_apply_to_target_types(target: UnitCard) -> bool:
	match operation:
		Operation.ADD:
			if target.target_types.has(type_number):
				return false

			if target.get_target_types_count() >= UnitCard.MAX_EQUIPPED_TYPES:
				return false

			return true

		Operation.REMOVE:
			return target.target_types.has(type_number)

	return false


func _can_apply_to_source_types(target: UnitCard) -> bool:
	match operation:
		Operation.ADD:
			if target.source_types.has(type_number):
				return false

			if target.get_source_types_count() >= UnitCard.MAX_EQUIPPED_TYPES:
				return false

			return true

		Operation.REMOVE:
			return target.source_types.has(type_number)

	return false


func execute(context: SpellContext) -> void:
	if context == null:
		push_error(
			"ModifyConnectionTypeSpellEffect: Missing context."
		)
		return

	if context.target == null:
		push_error(
			"ModifyConnectionTypeSpellEffect: Missing target."
		)
		return

	if not can_apply_to(context.target):
		push_warning(
			"ModifyConnectionTypeSpellEffect: Effect cannot be applied to target."
		)
		return

	match connection_type:
		ConnectionType.TARGET:
			_apply_to_target_type(context.target)

		ConnectionType.SOURCE:
			_apply_to_source_type(context.target)


func _apply_to_target_type(target: UnitCard) -> void:
	match operation:
		Operation.ADD:
			target.add_target_type(type_number)
			Audio.play_spatial_sound(
				ADD_TYPE,
				target.global_position,
				false,
				false,
				0.25
			)

		Operation.REMOVE:
			target.remove_target_type(type_number)
			Audio.play_spatial_sound(
				REMOVE_TYPE,
				target.global_position,
				false,
				false,
				0.25
			)


func _apply_to_source_type(target: UnitCard) -> void:
	match operation:
		Operation.ADD:
			target.add_source_type(type_number)
			Audio.play_spatial_sound(
				ADD_TYPE,
				target.global_position,
				false,
				false,
				0.25
			)

		Operation.REMOVE:
			target.remove_source_type(type_number)
			Audio.play_spatial_sound(
				REMOVE_TYPE,
				target.global_position,
				false,
				false,
				0.25
			)
