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

	if not _has_valid_target(spell):
		_return_spell_to_hand(spell)
		return

	change_to(fsm.select_card_on_board_state)


func _has_valid_target(spell: SpellCard) -> bool:
	var board_cards: Array[Card] = fsm.get_all_cards_on_board()

	for card: Card in board_cards:
		if spell.is_valid_target(card, fsm.active_side):
			return true

	return false


func _return_spell_to_hand(spell: SpellCard) -> void:
	if not fsm.return_card_to_hand(spell, fsm.player_hand):
		push_error("PlayerPlaySpellCardState: Could not return spell to hand.")

	fsm.active_spell_card = null
	change_to(fsm.player_play_card_state)


func _execute_spell_without_target(spell: SpellCard) -> void:
	var context := SpellContext.new(fsm,spell,null,fsm.active_side)

	spell.execute(context)
	spell.destroy()

	fsm.active_spell_card = null
	change_to(fsm.check_for_cycle_state)
