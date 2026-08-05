class_name SpellContext
extends RefCounted


var fsm: Node
var spell_card: SpellCard
var target: UnitCard
var caster_side: GameDecisionEngine.Side


func _init(
	new_fsm: Node,
	new_spell_card: SpellCard,
	new_target: UnitCard = null,
	new_caster_side: GameDecisionEngine.Side = GameDecisionEngine.Side.PLAYER
) -> void:
	fsm = new_fsm
	spell_card = new_spell_card
	target = new_target
	caster_side = new_caster_side
