class_name PlayerPlaySpellCardState
extends State


func enter() -> void:
	fsm.set_state_info("Player Play Spell Card")

	var spell: SpellCard = fsm.active_spell_card

	if spell == null or not is_instance_valid(spell):
		push_error("PlayerPlaySpellCardState: Missing active spell.")
		fsm.active_spell_card = null
		change_to(fsm.check_for_cycle_state)
		return

	if not spell.requires_target():
		_execute_spell_without_target(spell)
		return

	change_to(fsm.select_card_on_board_state)


func _execute_spell_without_target(spell: SpellCard) -> void:
	var context := SpellContext.new(fsm,spell,null,GameDecisionEngine.Side.PLAYER)

	spell.execute(context)
	spell.destroy()

	fsm.active_spell_card = null
	change_to(fsm.check_for_cycle_state)
