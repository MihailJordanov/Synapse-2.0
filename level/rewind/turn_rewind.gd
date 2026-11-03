class_name TurnRewind
extends Node

## Turn history for main_level: snapshots + rewinding with visual card returns.
##
## A snapshot is taken at the start of every PLAYER turn and every ENEMY turn
## (on GameDecisionEngine.state_changed, i.e. before the start-turn state's enter()).
##
## rewind(n): goes back n full rounds (player + enemy) before the current player turn.
## Snapshots are undone like a stack (newest first): current turn -> enemy turn -> player turn ...
## Each step animates the cards back:
##   destroyed cards fade back in, board cards fly back to the hand, drawn cards return to the deck.
## Then scores, mana, turn counters (legends!), first-draw flags and the RNG state are restored.
##
## Legend effects with their own state can implement
##   get_rewind_state() -> Variant  /  set_rewind_state(state: Variant)

signal rewind_started(rounds: int)
signal rewind_finished(rounds: int)

const META_UID: StringName = &"rewind_uid"

enum Zone { DECK, SPELL_DECK, HAND, SLOT }

## Seconds per undone step (one turn) - the card animations play inside it.
@export_range(0.1, 3.0, 0.05) var step_duration: float = 0.6
## Fade-in time for cards that come back from being destroyed.
@export_range(0.05, 3.0, 0.05) var revive_fade_duration: float = 0.5

@onready var fsm: GameDecisionEngine = %GameDecisionEngine

var is_rewinding: bool = false

var _snapshots: Array[Dictionary] = []
var _cards_by_uid: Dictionary = {}  # uid -> Card (may be freed)
var _next_uid: int = 1
var _rewind_state: RewindState
var _pending_rounds: int = 0


func _ready() -> void:
	fsm.state_changed.connect(_on_state_changed)

	# Own state, so the current state's exit() cleans up (buttons, dragger) before rewinding.
	_rewind_state = RewindState.new()
	_rewind_state.name = "RewindState"
	_rewind_state.rewind = self
	fsm.add_child(_rewind_state)
	_rewind_state.setup(fsm)


#region /// public API

## True when the player is waiting for input and n rounds of history exist.
func can_rewind(rounds: int) -> bool:
	if is_rewinding or rounds <= 0:
		return false

	var state: State = fsm.current_state

	if state != fsm.player_play_card_state and state != fsm.player_end_turn_state:
		return false

	return _get_player_snapshot_indices().size() > rounds


## Starts rewinding n rounds (through RewindState, so the FSM stays consistent).
func request_rewind(rounds: int) -> bool:
	if not can_rewind(rounds):
		return false

	_pending_rounds = rounds
	fsm.request_transition(_rewind_state)
	return true


func get_available_rounds() -> int:
	return maxi(_get_player_snapshot_indices().size() - 1, 0)

#endregion


#region /// snapshots

func _on_state_changed(_previous: State, current: State) -> void:
	if is_rewinding:
		return

	if current == fsm.player_start_turn_state:
		_snapshots.append(_capture("player"))
	elif current == fsm.enemy_start_turn_state:
		_snapshots.append(_capture("enemy"))


func _capture(kind: String) -> Dictionary:
	var cards: Dictionary = {}

	for side_is_enemy: bool in [false, true]:
		var hand: Hand = fsm.enemy_hand if side_is_enemy else fsm.player_hand
		_capture_list(cards, hand.deck, Zone.DECK, side_is_enemy)
		_capture_list(cards, hand.spell_deck, Zone.SPELL_DECK, side_is_enemy)
		_capture_list(cards, hand.cards_in_hand, Zone.HAND, side_is_enemy)

		var slots: Array[CardSlot] = fsm.enemy_slots if side_is_enemy else fsm.player_slots

		for index in range(slots.size()):
			var card: Card = slots[index].current_card

			if is_instance_valid(card):
				cards[_uid_of(card)] = _card_entry(card, Zone.SLOT, index, side_is_enemy)

	return {
		"kind": kind,
		"cards": cards,
		"vars": {
			"player_score": fsm.player_score,
			"enemy_score": fsm.enemy_score,
			"player_mana": fsm.player_mana,
			"enemy_mana": fsm.enemy_mana,
			"active_side": fsm.active_side,
			"player_turn_count": fsm.player_turn_count,
			"enemy_turn_count": fsm.enemy_turn_count,
			"player_first_draw_done": fsm.player_first_draw_done,
			"enemy_first_draw_done": fsm.enemy_first_draw_done,
			"consecutive_forced_skips": fsm.consecutive_forced_skips,
			"player_spells_played_this_turn": fsm.player_spells_played_this_turn,
			"end_turn_reason": fsm.end_turn_reason,
		},
		"rng_state": fsm.rng.state,
		"legends": _capture_legends(),
	}


func _capture_list(cards: Dictionary, list: Array[Card], zone: Zone, side_is_enemy: bool) -> void:
	for index in range(list.size()):
		var card: Card = list[index]

		if is_instance_valid(card):
			cards[_uid_of(card)] = _card_entry(card, zone, index, side_is_enemy)


func _card_entry(card: Card, zone: Zone, index: int, side_is_enemy: bool) -> Dictionary:
	var entry: Dictionary = {
		"card_id": card.card_id,
		"is_enemy": side_is_enemy,
		"zone": zone,
		"index": index,
	}

	if card is UnitCard:
		var unit := card as UnitCard
		entry["target_types"] = unit.target_types.duplicate()
		entry["source_types"] = unit.source_types.duplicate()
		entry["points"] = unit.points

	return entry


func _uid_of(card: Card) -> int:
	if not card.has_meta(META_UID):
		card.set_meta(META_UID, _next_uid)
		_next_uid += 1

	var uid: int = int(card.get_meta(META_UID))
	_cards_by_uid[uid] = card
	return uid


func _capture_legends() -> Dictionary:
	var result: Dictionary = {}
	var controller: LevelController = fsm.level_controller

	for key in ["player", "enemy"]:
		var legend: Legend = controller.player_legend if key == "player" else controller.enemy_legend

		if legend != null and legend.effect != null and legend.effect.has_method("get_rewind_state"):
			result[key] = legend.effect.call("get_rewind_state")

	return result


func _get_player_snapshot_indices() -> Array[int]:
	var result: Array[int] = []

	for index in range(_snapshots.size()):
		if _snapshots[index]["kind"] == "player":
			result.append(index)

	return result

#endregion


#region /// rewinding (called by RewindState)

func perform_pending_rewind() -> void:
	var rounds: int = _pending_rounds
	_pending_rounds = 0

	var player_indices: Array[int] = _get_player_snapshot_indices()

	if rounds <= 0 or player_indices.size() <= rounds:
		return

	var target_index: int = player_indices[player_indices.size() - 1 - rounds]

	is_rewinding = true
	rewind_started.emit(rounds)
	fsm.clear_cycle_visualization()
	fsm.set_state_info("[color=#a1fff0]Rewinding %d turn%s...[/color]" % [rounds, "" if rounds == 1 else "s"])

	# Stack order: newest snapshot first, down to the target.
	for index in range(_snapshots.size() - 1, target_index - 1, -1):
		_restore_cards(_snapshots[index])
		await get_tree().create_timer(step_duration).timeout

	var target: Dictionary = _snapshots[target_index]
	_restore_vars(target)

	# The target is re-captured when its turn starts again.
	_snapshots.resize(target_index)

	is_rewinding = false
	rewind_finished.emit(rounds)


func _restore_cards(snapshot: Dictionary) -> void:
	var cards: Dictionary = snapshot["cards"]

	# 1. Live cards that do not exist in this snapshot (should not happen) -> remove.
	for uid in _cards_by_uid.keys():
		var live: Card = _get_live_card(uid)

		if live == null:
			_cards_by_uid.erase(uid)
			continue

		if not cards.has(uid):
			_detach_card(live)
			live.queue_free()
			_cards_by_uid.erase(uid)

	# 2. Make sure every card exists (re-create destroyed ones) and has the right data.
	var revived: Dictionary = {}  # uid -> true

	for uid in cards:
		var entry: Dictionary = cards[uid]
		var card: Card = _get_live_card(uid)

		if card == null:
			card = CardManager.create_card_by_id(int(entry["card_id"]))

			if card == null:
				push_warning("TurnRewind: could not re-create card %d." % int(entry["card_id"]))
				continue

			card.set_meta(META_UID, uid)
			_cards_by_uid[uid] = card
			revived[uid] = true

		card.is_enemy_card = bool(entry["is_enemy"])
		_apply_unit_data(card, entry)

	# 3. Free every slot whose card must leave it (so cards can swap places).
	for slot: CardSlot in fsm.player_slots + fsm.enemy_slots:
		var current: Card = slot.current_card

		if current == null:
			continue

		var entry: Dictionary = cards.get(int(current.get_meta(META_UID, -1)), {})

		if entry.is_empty() or not _is_entry_slot(entry, slot):
			slot.clear_slot(false)

	# 4. Move every card to its zone (with animations).
	for uid in cards:
		var card: Card = _get_live_card(uid)

		if card == null:
			continue

		_move_card(card, cards[uid], revived.has(uid))

	# 5. Exact order of decks and hands.
	for side_is_enemy: bool in [false, true]:
		var hand: Hand = fsm.enemy_hand if side_is_enemy else fsm.player_hand
		hand.deck.assign(_ordered_cards(cards, Zone.DECK, side_is_enemy))
		hand.spell_deck.assign(_ordered_cards(cards, Zone.SPELL_DECK, side_is_enemy))
		hand.cards_in_hand.assign(_ordered_cards(cards, Zone.HAND, side_is_enemy))
		hand.hovered_card = null
		hand.dragged_card = null
		hand._update_deck_sprites_visibility()
		hand.deck_changed.emit()
		hand.rearrange_hand()


func _move_card(card: Card, entry: Dictionary, is_revived: bool) -> void:
	var side_is_enemy: bool = bool(entry["is_enemy"])
	var hand: Hand = fsm.enemy_hand if side_is_enemy else fsm.player_hand
	var zone: int = int(entry["zone"])

	match zone:
		Zone.SLOT:
			var slots: Array[CardSlot] = fsm.enemy_slots if side_is_enemy else fsm.player_slots
			var slot: CardSlot = slots[int(entry["index"])]

			if card.current_slot == slot:
				return

			_remove_from_hands(card)
			card.is_card_hide = false

			if is_revived:
				slot.add_child(card)
				card.position = Vector2.ZERO
				_fade_in(card)

			slot.place_card(card)

		Zone.HAND:
			if card.current_slot != null:
				card.current_slot.clear_slot(false)

			for other: Hand in [fsm.player_hand, fsm.enemy_hand]:
				if other != hand:
					other.remove_card(card)

			card.is_card_hide = side_is_enemy

			if card.get_parent() == null:
				hand.add_child(card)
				card.global_position = hand.deck_sprite.global_position if hand.deck_sprite else hand.global_position

				if is_revived:
					_fade_in(card)
			elif card.get_parent() != hand:
				card.reparent(hand, true)

			card.scale = Vector2.ONE
			card.z_as_relative = true

		Zone.DECK, Zone.SPELL_DECK:
			card.is_card_hide = side_is_enemy

			if card.get_parent() == null:
				return  # already in a deck (not in the tree)

			if card.current_slot != null:
				card.current_slot.clear_slot(false)

			_remove_from_hands(card)
			_fly_into_deck(card, hand, zone == Zone.SPELL_DECK)


func _fly_into_deck(card: Card, hand: Hand, is_spell: bool) -> void:
	var target_sprite: Sprite2D = hand.spell_deck_sprite if is_spell else hand.deck_sprite
	var target_position: Vector2 = target_sprite.global_position if target_sprite else hand.global_position

	card.z_as_relative = false
	card.z_index = 900

	var tween: Tween = card.create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "global_position", target_position, step_duration * 0.7)
	tween.tween_property(card, "scale", Vector2(0.6, 0.6), step_duration * 0.7)
	tween.tween_property(card, "modulate:a", 0.0, step_duration * 0.7)
	tween.chain().tween_callback(_finish_deck_return.bind(card))


func _finish_deck_return(card: Card) -> void:
	if not is_instance_valid(card):
		return

	if card.get_parent() != null:
		card.get_parent().remove_child(card)

	card.modulate.a = 1.0
	card.scale = Vector2.ONE
	card.z_index = 0
	card.z_as_relative = true


func _fade_in(card: Card) -> void:
	card.modulate.a = 0.0
	var tween: Tween = card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, revive_fade_duration)


## Never assign a freed card to a typed variable (GDScript error) - check the raw value first.
func _get_live_card(uid: int) -> Card:
	var value: Variant = _cards_by_uid.get(uid)

	if not is_instance_valid(value):
		return null

	return value as Card


func _remove_from_hands(card: Card) -> void:
	fsm.player_hand.remove_card(card)
	fsm.enemy_hand.remove_card(card)


func _detach_card(card: Card) -> void:
	if card.current_slot != null:
		card.current_slot.clear_slot(false)

	_remove_from_hands(card)

	for hand: Hand in [fsm.player_hand, fsm.enemy_hand]:
		hand.deck.erase(card)
		hand.spell_deck.erase(card)


func _apply_unit_data(card: Card, entry: Dictionary) -> void:
	if not card is UnitCard or not entry.has("points"):
		return

	var unit := card as UnitCard
	var targets: Array[int] = []
	var sources: Array[int] = []
	targets.assign(entry["target_types"])
	sources.assign(entry["source_types"])

	if unit.target_types != targets or unit.source_types != sources:
		unit.set_all_types(targets, sources)

	if unit.points != int(entry["points"]):
		unit.set_points(int(entry["points"]))


func _is_entry_slot(entry: Dictionary, slot: CardSlot) -> bool:
	if int(entry["zone"]) != Zone.SLOT:
		return false

	var slots: Array[CardSlot] = fsm.enemy_slots if bool(entry["is_enemy"]) else fsm.player_slots
	var index: int = int(entry["index"])
	return index >= 0 and index < slots.size() and slots[index] == slot


func _ordered_cards(cards: Dictionary, zone: Zone, side_is_enemy: bool) -> Array[Card]:
	var pairs: Array = []

	for uid in cards:
		var entry: Dictionary = cards[uid]

		if int(entry["zone"]) != zone or bool(entry["is_enemy"]) != side_is_enemy:
			continue

		var card: Card = _get_live_card(uid)

		if card != null:
			pairs.append([int(entry["index"]), card])

	pairs.sort_custom(func(a, b): return a[0] < b[0])

	var result: Array[Card] = []

	for pair in pairs:
		result.append(pair[1])

	return result


func _restore_vars(snapshot: Dictionary) -> void:
	var vars: Dictionary = snapshot["vars"]

	fsm.player_score = int(vars["player_score"])
	fsm.enemy_score = int(vars["enemy_score"])
	fsm.set_mana(GameDecisionEngine.Side.PLAYER, int(vars["player_mana"]))
	fsm.set_mana(GameDecisionEngine.Side.ENEMY, int(vars["enemy_mana"]))
	fsm.active_side = int(vars["active_side"])
	fsm.player_turn_count = int(vars["player_turn_count"])
	fsm.enemy_turn_count = int(vars["enemy_turn_count"])
	fsm.player_first_draw_done = bool(vars["player_first_draw_done"])
	fsm.enemy_first_draw_done = bool(vars["enemy_first_draw_done"])
	fsm.consecutive_forced_skips = int(vars["consecutive_forced_skips"])
	fsm.player_spells_played_this_turn = int(vars["player_spells_played_this_turn"])
	fsm.end_turn_reason = int(vars["end_turn_reason"])
	fsm.rng.state = int(snapshot["rng_state"])
	fsm.clear_resolution_context()
	fsm.active_spell_card = null

	var legends: Dictionary = snapshot["legends"]
	var controller: LevelController = fsm.level_controller

	for key in legends:
		var legend: Legend = controller.player_legend if key == "player" else controller.enemy_legend

		if legend != null and legend.effect != null and legend.effect.has_method("set_rewind_state"):
			legend.effect.call("set_rewind_state", legends[key])

	# Rebuild the connection graph from what is on the board now.
	fsm.board_controller.clear_board()

	for slot: CardSlot in fsm.player_slots + fsm.enemy_slots:
		var unit := slot.current_card as UnitCard

		if unit != null:
			fsm.board_controller.add_card(unit)

	fsm.score_changed.emit(fsm.player_score, fsm.enemy_score)
	fsm.update_game_info_labels()
	fsm.update_deck_inform_labels()

#endregion
