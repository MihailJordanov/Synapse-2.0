class_name TutorialHand
extends Hand

## Same card layout and draw animations as Hand, without shuffling or debug draws.


func _unhandled_input(_event: InputEvent) -> void:
	pass


func setup_deck(source_cards: Array) -> void:
	clear_hand_and_deck()
	for item in source_cards:
		var card: Card = item as Card
		if not is_instance_valid(card):
			continue
		card.is_enemy_card = is_enemy
		card.is_card_hide = is_enemy
		deck.append(card)
	_update_deck_sprites_visibility()
	deck_changed.emit()


func draw_card_by_id(card_id: int) -> UnitCard:
	for index: int in range(deck.size()):
		var card: Card = deck[index]
		if is_instance_valid(card) and card.card_id == card_id:
			deck.remove_at(index)
			deck.push_front(card)
			return draw_card() as UnitCard
	push_warning("TutorialHand %s: no remaining copy of draw ID %d." % [name, card_id])
	return null


func find_unit_by_id(card_id: int) -> UnitCard:
	for card: Card in cards_in_hand:
		if is_instance_valid(card) and card is UnitCard and card.card_id == card_id:
			return card as UnitCard
	return null


func clear_hand_and_deck() -> void:
	for tween_value: Variant in _card_tweens.values():
		var tween: Tween = tween_value as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_card_tweens.clear()
	var seen: Dictionary = {}
	for card: Card in cards_in_hand + deck + spell_deck:
		if not is_instance_valid(card) or seen.has(card.get_instance_id()):
			continue
		seen[card.get_instance_id()] = true
		card.queue_free()
	cards_in_hand.clear()
	deck.clear()
	spell_deck.clear()
	hovered_card = null
	dragged_card = null


func _exit_tree() -> void:
	# Undrawn cards have no parent, so the scene would not free them automatically.
	for card: Card in deck + spell_deck:
		if is_instance_valid(card) and card.get_parent() == null:
			card.queue_free()
	deck.clear()
	spell_deck.clear()
