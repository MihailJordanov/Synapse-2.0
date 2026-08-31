class_name PlayerPlayCardState
extends State

const PLACING_CARD = preload("uid://0bmixn5qduk2")

var is_skip_available: bool = false
var skip_is_forced: bool = false


func enter() -> void:
	fsm.set_state_info("Player Play Card")

	var played_spell_this_turn: bool = fsm.has_player_played_spell_this_turn()

	if fsm.player_hand.cards_in_hand.is_empty():
		_enter_skip_only_mode(
			"No cards remain in your hand.\n"
			+ "You may skip your turn.",
			not played_spell_this_turn
		)
		return

	var empty_slots: Array[CardSlot] = fsm.get_empty_slots(GameDecisionEngine.Side.PLAYER)

	if empty_slots.is_empty():
		change_to(fsm.check_for_cycle_state)
		return

	var has_playable_card: bool = fsm.has_any_playable_card(fsm.player_hand,GameDecisionEngine.Side.PLAYER)

	var has_unit_card: bool = fsm.hand_has_unit_card(fsm.player_hand)

	if not has_playable_card:
		var message: String = (
			"No playable cards.\n"
			+ "You may skip your turn."
		)

		if played_spell_this_turn and not has_unit_card:
			message = (
				"You have no unit cards in your hand "
				+ "and no playable spells remain.\n"
				+ "You may skip your turn."
			)

		_enter_skip_only_mode(message,not played_spell_this_turn)
		return

	if not has_unit_card:
		if played_spell_this_turn:
			_enter_spell_only_mode(empty_slots)
		else:
			_enter_spell_only_must_play_mode(empty_slots)

		return

	_enter_play_mode(empty_slots)
	
	
func exit() -> void:
	is_skip_available = false
	skip_is_forced = false

	fsm.card_dragger.set_play_context(false, [])

	if fsm.card_dragger.card_drop_requested.is_connected(_on_card_drop_requested):
		fsm.card_dragger.card_drop_requested.disconnect(_on_card_drop_requested)

	if fsm.control_button_pressed.is_connected(_on_skip_turn_pressed):
		fsm.control_button_pressed.disconnect(_on_skip_turn_pressed)

	fsm.disable_turn_button()

func _enter_play_mode(empty_slots: Array[CardSlot]) -> void:
	is_skip_available = false
	skip_is_forced = false

	fsm.set_state_info("Play a card.")
	fsm.disable_turn_button()

	fsm.card_dragger.set_play_context(true,empty_slots)

	if not fsm.card_dragger.card_drop_requested.is_connected(_on_card_drop_requested):
		fsm.card_dragger.card_drop_requested.connect(_on_card_drop_requested)

func _enter_skip_only_mode(message: String, is_forced: bool) -> void:
	is_skip_available = true
	skip_is_forced = is_forced
	
	fsm.set_state_info(message)
	fsm.card_dragger.set_play_context(false, [])
	fsm.set_control_button("Skip Turn", true)

	if not fsm.control_button_pressed.is_connected(_on_skip_turn_pressed):
		fsm.control_button_pressed.connect(_on_skip_turn_pressed)

func _on_card_drop_requested(card: Card,slot: CardSlot) -> void:
	if not fsm.is_card_playable_now(
		card,
		GameDecisionEngine.Side.PLAYER
	):
		Audio.ui_error()
		fsm.card_dragger.reject_last_drop(card)
		return

	var was_played: bool = fsm.try_play_card(
		card,
		slot,
		GameDecisionEngine.Side.PLAYER
	)

	if not was_played:
		Audio.ui_error()
		fsm.card_dragger.reject_last_drop(card)
		return
	
	Audio.play_spatial_sound(
			PLACING_CARD,
			slot.global_position,
			false,
			true,
			0.25
		)

	match card.card_type:
		Card.CardType.UNIT:
			fsm.reset_forced_skips()
			fsm.resolve_after_unit_play()

		Card.CardType.SPELL:
			if not card is SpellCard:
				push_error(
					"Card has SPELL type but is not a SpellCard."
				)

				card.destroy()
				change_to(fsm.check_for_cycle_state)
				return

			fsm.active_spell_card = card as SpellCard
			change_to(fsm.player_play_spell_card_state)

func _on_skip_turn_pressed() -> void:
	if not is_skip_available:
		return

	if fsm.current_state != self:
		return

	is_skip_available = false

	if skip_is_forced:
		if fsm.register_forced_skip():
			change_to(fsm.defeat_state)
			return
	else:
		fsm.reset_forced_skips()

	var terminal: State = fsm.score_terminal_state()

	if terminal != null:
		change_to(terminal)
		return

	change_to(fsm.enemy_start_turn_state)

func _enter_spell_only_mode(empty_slots: Array[CardSlot]) -> void:
	is_skip_available = true
	skip_is_forced = false

	fsm.set_state_info(
		"You have no unit cards in your hand. "
		+ "You may play more spells or skip your turn."
	)

	fsm.card_dragger.set_play_context(true,empty_slots)

	if not fsm.card_dragger.card_drop_requested.is_connected(_on_card_drop_requested):
		fsm.card_dragger.card_drop_requested.connect(_on_card_drop_requested)

	fsm.set_control_button("Skip Turn", true)

	if not fsm.control_button_pressed.is_connected(_on_skip_turn_pressed):
		fsm.control_button_pressed.connect(_on_skip_turn_pressed)

func _enter_spell_only_must_play_mode(empty_slots: Array[CardSlot]) -> void:
	is_skip_available = false
	skip_is_forced = false

	fsm.set_state_info(
		"You have only spell cards in your hand.\n"
		+ "You must play at least one card before you can skip."
	)

	fsm.disable_turn_button()

	fsm.card_dragger.set_play_context(true,empty_slots)

	if not fsm.card_dragger.card_drop_requested.is_connected(_on_card_drop_requested):
		fsm.card_dragger.card_drop_requested.connect(_on_card_drop_requested)
