class_name SpellContext
extends RefCounted


var fsm: Node
var spell_card: SpellCard
var target: UnitCard
var caster_side: GameDecisionEngine.Side
var destination_slot: CardSlot


func _init(
	new_fsm: Node,
	new_spell_card: SpellCard,
	new_target: UnitCard = null,
	new_caster_side: GameDecisionEngine.Side = GameDecisionEngine.Side.PLAYER,
	new_destination_slot: CardSlot = null
) -> void:
	fsm = new_fsm
	spell_card = new_spell_card
	target = new_target
	caster_side = new_caster_side
	destination_slot = new_destination_slot
