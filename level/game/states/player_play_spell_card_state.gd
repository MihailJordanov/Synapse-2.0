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

	var play_context: CardPlayContext = \
		fsm.create_card_play_context(fsm.active_side)

	if not spell.is_playable_now(play_context):
		_return_spell_to_hand(spell)
		return

	if not spell.requires_target():
		_execute_spell_without_target(spell)
		return

	change_to(fsm.select_card_on_board_state)


func _return_spell_to_hand(spell: SpellCard) -> void:
	if spell.current_slot != null:
		spell.current_slot.clear_slot(false)
		spell.current_slot = null

	fsm.player_hand.add_existing_card(spell)

	fsm.active_spell_card = null
	change_to(fsm.player_play_card_state)


func _execute_spell_without_target(spell: SpellCard) -> void:
	var context := SpellContext.new(fsm,spell,null,fsm.active_side)

	spell.execute(context)
	spell.destroy()

	fsm.active_spell_card = null
	change_to(fsm.check_for_cycle_state)
