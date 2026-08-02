class_name PlayerPlayCardState extends State

func enter() -> void:
	if fsm.player_hand.cards_in_hand.is_empty():
		change_to(fsm.defeat_state)
		return
	var empty_slots := fsm.get_empty_slots(GameDecisionEngine.Side.PLAYER)
	if empty_slots.is_empty():
		change_to(fsm.check_for_cycle_state)
		return
	fsm.card_dragger.set_play_context(true, empty_slots)
	if not fsm.card_dragger.card_drop_requested.is_connected(_on_card_drop_requested):
		fsm.card_dragger.card_drop_requested.connect(_on_card_drop_requested)

func exit() -> void:
	fsm.card_dragger.set_play_context(false, [])
	if fsm.card_dragger.card_drop_requested.is_connected(_on_card_drop_requested):
		fsm.card_dragger.card_drop_requested.disconnect(_on_card_drop_requested)

func _on_card_drop_requested(card: Card, slot: CardSlot) -> void:
	if not fsm.try_play_card(card, slot, GameDecisionEngine.Side.PLAYER):
		fsm.card_dragger.reject_last_drop(card)
		return
	change_to(fsm.check_for_cycle_state)
