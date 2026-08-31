class_name RuneSeerLegendEffect
extends LegendEffect


func on_turn_start(fsm: GameDecisionEngine,side: GameDecisionEngine.Side,turn_number: int) -> bool:
	if turn_number != 1:
		return false

	var hand: Hand

	if side == GameDecisionEngine.Side.PLAYER:
		hand = fsm.player_hand
	else:
		hand = fsm.enemy_hand

	if hand == null:
		return false

	if hand.spell_deck.is_empty():
		return false

	var drawn_card: Card = hand.draw_spell_card()

	if drawn_card == null:
		return false

	if drawn_card is SpellCard:
		var spell: SpellCard = drawn_card as SpellCard

		spell.set_mana_cost(spell.get_mana_cost() - 1)

	return true
