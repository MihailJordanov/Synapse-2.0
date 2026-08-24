class_name GameDecisionEngine extends Node

signal control_button_pressed
signal state_changed(previous: State, current: State)
signal score_changed(player_score: int, enemy_score: int)
signal game_finished(player_won: bool)

enum Side { PLAYER, ENEMY }
enum ScorePolicy { ACTIVE_SIDE_GETS_ALL, EACH_OWNER_GETS_OWN }
enum ManaPolicy { DESTROY_ENEMIES, SACRIFICE_ALLIES }
enum ResolutionOrigin { UNIT_PLAY, SPELL_PLAY }
const CYCLE_VISUALIZER_SCENE = preload("uid://c81aoxm08v8tf")
const MAX_CONSECUTIVE_FORCED_SKIPS = 3

var cycle_visualizer: CycleVisualizer

@export_group("References")
@export var level_controller: LevelController
@export var board_controller: BoardController
@export var player_hand: Hand
@export var enemy_hand: Hand
@export var card_dragger: CardDragger
@export var player_slots: Array[CardSlot] = []
@export var enemy_slots: Array[CardSlot] = []

@export_group("Rules")
@export var initial_draw_count: int = 5
@export var player_winning_score: int = 10
@export var enemy_winning_score: int = 10
@export var player_max_mana_to_collect: int = 10
@export var enemy_max_mana_to_collect: int = 10
@export var enemy_think_time: float = 1.0
@export var score_policy: ScorePolicy = ScorePolicy.ACTIVE_SIDE_GETS_ALL
@export var mana_policy: ManaPolicy = ManaPolicy.DESTROY_ENEMIES
@export var randomize_seed: bool = true
@export var fixed_seed: int = 1

var player_score: int = 0
var enemy_score: int = 0
var player_mana : int = 6
var enemy_mana : int = 6
var active_side: int = Side.PLAYER
var current_state: State = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var pending_destroy_ids: Array[int] = []
var pending_score_enabled: bool = false
var pending_total_points: int = 0
var pending_player_owned_points: int = 0
var pending_enemy_owned_points: int = 0
var active_spell_card: SpellCard
var resolution_origin: ResolutionOrigin = ResolutionOrigin.UNIT_PLAY
var consecutive_forced_skips: int = 0
var player_spells_played_this_turn: int = 0
var player_first_draw_done: bool = false
var enemy_first_draw_done: bool = false
var player_turn_count: int = 0
var enemy_turn_count: int = 0

var _pending_state: State = null
var _transition_queued: bool = false



@onready var setup_state: SetupState = %SetupState
@onready var player_start_turn_state: PlayerStartTurnState = %PlayerStartTurnState
@onready var player_draw_card_state: PlayerDrawCardState = %PlayerDrawCardState
@onready var player_play_card_state: PlayerPlayCardState = %PlayerPlayCardState
@onready var player_end_turn_state: PlayerEndTurnState = %PlayerEndTurnState
@onready var enemy_start_turn_state: EnemyStartTurnState = %EnemyStartTurnState
@onready var enemy_draw_card_state: EnemyDrawCardState = %EnemyDrawCardState
@onready var enemy_play_card_state: EnemyPlayCardState = %EnemyPlayCardState
@onready var enemy_end_turn_state: EnemyEndTurnState = %EnemyEndTurnState
@onready var check_for_cycle_state: CheckForCycleState = %CheckForCycleState
@onready var destroy_card_state: DestroyCardState = %DestroyCardState
@onready var sum_points_state: SumPointsState = %SumPointsState
@onready var victory_state: VictoryState = %VictoryState
@onready var defeat_state: DefeatState = %DefeatState
@onready var current_state_label: Label = get_node_or_null("%StateLabel") as Label
@onready var state_inform_label: RichTextLabel = %StateInformLabel
@onready var controll_turn_button: Button = %ControllTurnButton
@onready var player_play_spell_card_state: PlayerPlaySpellCardState = %PlayerPlaySpellCardState
@onready var select_card_on_board_state: SelectCardOnBoardState = %SelectCardOnBoardState
@onready var player_mana_inform_label: RichTextLabel = %PlayerManaInformLabel
@onready var player_victory_points_inform_label: RichTextLabel = %PlayerVictoryPointsInformLabel
@onready var player_deck_inform_label: RichTextLabel = %PlayerDeckInformLabel
@onready var enemy_mana_inform_label: RichTextLabel = %EnemyManaInformLabel
@onready var enemy_victory_points_inform_label: RichTextLabel = %EnemyVictoryPointsInformLabel
@onready var enemy_deck_inform_label: RichTextLabel = %EnemyDeckInformLabel


func _ready() -> void:
	_initialize_cycle_visualizer()
	_initialize_states()
	_initialize_slots()
	_initialize_random_generator()
	update_game_info_labels()

	controll_turn_button.disabled = true
	controll_turn_button.text = ""

	controll_turn_button.pressed.connect(_on_control_turn_button_pressed)
	
	_connect_deck_signals()
	update_deck_inform_labels()
	request_transition(setup_state)

func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func request_transition(next_state: State) -> void:
	if next_state == null:
		push_error("GameDecisionEngine: null state transition requested.")
		return
	if _pending_state != null:
		if _pending_state != next_state:
			push_warning("GameDecisionEngine: competing transition ignored: %s" % next_state.name)
		return
	_pending_state = next_state
	if not _transition_queued:
		_transition_queued = true
		call_deferred("_flush_transition")

func _flush_transition() -> void:
	_transition_queued = false
	var next_state: State = _pending_state
	_pending_state = null
	if next_state == null:
		return
	var previous: State = current_state
	if previous == next_state:
		next_state.re_enter()
		_update_state_label()
		return
	if previous:
		previous.exit()
	current_state = next_state
	_update_state_label()
	state_changed.emit(previous, current_state)
	current_state.enter()

func is_state_active(state: State) -> bool:
	return current_state == state

func wait_seconds(seconds: float, owner_state: State) -> bool:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout
	return current_state == owner_state

func reset_match() -> void:
	player_score = 0
	enemy_score = 0
	player_turn_count = 0
	enemy_turn_count = 0
	active_side = Side.PLAYER
	player_first_draw_done = false
	enemy_first_draw_done = false
	clear_resolution_context()
	board_controller.clear_board()
	for slot in player_slots + enemy_slots:
		slot.clear_slot(false)
	score_changed.emit(player_score, enemy_score)

func try_play_card(card: Card, slot: CardSlot, side: int) -> bool:
	if card == null:
		push_error("try_play_card: Card is null.")
		return false

	if slot == null:
		push_error("try_play_card: Slot is null.")
		return false

	if side != active_side:
		push_error(
			"try_play_card: Wrong active side. Requested=%d Active=%d"
			% [side, active_side]
		)
		return false

	var hand: Hand
	var allowed_slots: Array[CardSlot]

	if side == Side.PLAYER:
		hand = player_hand
		allowed_slots = player_slots
	else:
		hand = enemy_hand
		allowed_slots = enemy_slots

	if hand == null:
		push_error("try_play_card: Hand reference is null.")
		return false

	if not hand.cards_in_hand.has(card):
		push_error(
			"try_play_card: Card is not contained in the selected hand."
		)
		return false

	if not allowed_slots.has(slot):
		push_error(
			"try_play_card: Slot is not registered for side %d." % side
		)
		return false

	if slot.card_in_slot:
		push_error("try_play_card: Slot is already occupied.")
		return false

	var should_be_enemy_card: bool = side == Side.ENEMY

	if card.is_enemy_card != should_be_enemy_card:
		push_error(
			"try_play_card: Card ownership mismatch. " +
			"is_enemy_card=%s, requested side=%d"
			% [card.is_enemy_card, side]
		)
		return false

	if slot.is_enemy_slot != should_be_enemy_card:
		push_error(
			"try_play_card: Slot ownership mismatch. " +
			"is_enemy_slot=%s, requested side=%d"
			% [slot.is_enemy_slot, side]
		)
		return false

	if not card is UnitCard and not card is SpellCard:
		push_error(
			"try_play_card: Unsupported Card subclass."
		)
		return false

	if not hand.remove_card(card):
		push_error(
			"try_play_card: Could not remove card from hand."
		)
		return false

	if not slot.place_card(card):
		push_error(
			"try_play_card: CardSlot.place_card() rejected the card."
		)
		hand.add_existing_card(card)
		return false

	if card is SpellCard:
		return true

	var unit_card := card as UnitCard
	var new_board_id: int = board_controller.add_card(unit_card)

	if new_board_id == Card.INVALID_BOARD_ID:
		push_error(
			"try_play_card: BoardController rejected the card."
		)

		var removed_card: Card = slot.clear_slot()

		if removed_card != null:
			hand.add_existing_card(removed_card)

		return false

	return true
	
	
func get_empty_slots(side: int) -> Array[CardSlot]:
	var source: Array[CardSlot] = []

	if side == Side.PLAYER:
		source = player_slots
	else:
		source = enemy_slots

	var result: Array[CardSlot] = []

	for slot: CardSlot in source:
		if slot == null:
			continue

		if not slot.card_in_slot:
			result.append(slot)

	return result

func are_all_slots_full(slots: Array[CardSlot]) -> bool:
	if slots.is_empty():
		return false
	for slot in slots:
		if not slot.card_in_slot:
			return false
	return true

func is_board_full() -> bool:
	return are_all_slots_full(player_slots) and are_all_slots_full(enemy_slots)

func go_to_end_turn() -> void:
	if active_side == Side.PLAYER:
		request_transition(player_end_turn_state)
	else:
		request_transition(enemy_end_turn_state)
		
		
func add_score(side: int, amount: int) -> void:
	if amount <= 0:
		return
	if side == Side.PLAYER:
		player_score += amount
		player_score = min(player_score, player_winning_score)
	else:
		enemy_score += amount
		enemy_score = min(enemy_score, enemy_winning_score)
	score_changed.emit(player_score, enemy_score)
	
	update_game_info_labels()

func score_terminal_state() -> State:
	var player_reached: bool = player_score >= player_winning_score
	var enemy_reached: bool = enemy_score >= enemy_winning_score

	if player_reached and enemy_reached:
		if active_side == Side.PLAYER:
			return victory_state

		return defeat_state

	if player_reached:
		return victory_state

	if enemy_reached:
		return defeat_state

	return null

func clear_resolution_context() -> void:
	pending_destroy_ids.clear()
	pending_score_enabled = false
	pending_total_points = 0
	pending_player_owned_points = 0
	pending_enemy_owned_points = 0

func _update_state_label() -> void:
	if current_state_label and current_state:
		current_state_label.text = "State: " + current_state.name
		
func _initialize_states() -> void:
	var states: Array[State] = [
		setup_state,
		player_start_turn_state,
		player_draw_card_state,
		player_play_card_state,
		player_end_turn_state,
		enemy_start_turn_state,
		enemy_draw_card_state,
		enemy_play_card_state,
		enemy_end_turn_state,
		check_for_cycle_state,
		destroy_card_state,
		sum_points_state,
		victory_state,
		defeat_state,
		player_play_spell_card_state,
		select_card_on_board_state
	]

	for state: State in states:
		if state == null:
			push_error(
				"GameDecisionEngine: A state reference is null."
			)
			continue

		state.setup(self)
		
func _initialize_slots() -> void:
	for slot: CardSlot in player_slots:
		if slot != null:
			slot.is_enemy_slot = false

	for slot: CardSlot in enemy_slots:
		if slot != null:
			slot.is_enemy_slot = true
			
func _initialize_random_generator() -> void:
	if randomize_seed:
		rng.randomize()
	else:
		rng.seed = fixed_seed
		
		
func set_state_info(text: String) -> void:
	state_inform_label.text = text
		
func set_control_button(text: String, enabled: bool) -> void:
	controll_turn_button.text = text
	controll_turn_button.disabled = not enabled
		
func _on_control_turn_button_pressed() -> void:
	if controll_turn_button.disabled:
		return

	controll_turn_button.disabled = true
	control_button_pressed.emit()
	
func enable_end_turn_button() -> void:
	controll_turn_button.disabled = false
	controll_turn_button.text = "End Turn"


func disable_turn_button() -> void:
	controll_turn_button.disabled = true
	controll_turn_button.text = ""
	
func _initialize_cycle_visualizer() -> void:
	if CYCLE_VISUALIZER_SCENE == null:
		push_error("CycleVisualizer scene is missing.")
		return

	cycle_visualizer = CYCLE_VISUALIZER_SCENE.instantiate() as CycleVisualizer

	if cycle_visualizer == null:
		push_error("Could not instantiate CycleVisualizer.")
		return

	add_child(cycle_visualizer)
	
	
func show_cycle_visualization(cycle_data: CycleData) -> void:
	if cycle_visualizer == null:
		return

	if board_controller == null:
		return

	cycle_visualizer.show_cycle(cycle_data, board_controller)


func clear_cycle_visualization() -> void:
	if cycle_visualizer == null:
		return

	cycle_visualizer.clear_visualization()
		
		
func get_all_cards_on_board() -> Array[Card]:
	var result: Array[Card] = []

	for slot: CardSlot in player_slots:
		if slot.current_card != null:
			result.append(slot.current_card)

	for slot: CardSlot in enemy_slots:
		if slot.current_card != null:
			result.append(slot.current_card)

	return result
	
func return_card_to_hand(card: Card, hand: Hand) -> bool:
	if card == null or not is_instance_valid(card):
		return false

	if card.current_slot != null:
		card.current_slot.clear_slot(false)
		card.current_slot = null

	hand.add_existing_card(card)
	return true
	
func create_card_play_context(side: int) -> CardPlayContext:
	var board_cards: Array[Card] = get_all_cards_on_board()
	var empty_slots: Array[CardSlot] = get_empty_slots(side)
	var available_mana: int = get_mana(side)

	return CardPlayContext.new(
		side,
		board_cards,
		empty_slots,
		available_mana
	)

func is_card_playable_now(card: Card,side: int) -> bool:
	if card == null or not is_instance_valid(card):
		return false

	var empty_slots: Array[CardSlot] = get_empty_slots(side)

	if empty_slots.is_empty():
		return false

	if card is UnitCard:
		return true

	if card is SpellCard:
		var spell := card as SpellCard
		var context := create_card_play_context(side)

		return spell.is_playable_now(context)

	return false

func has_any_playable_card(hand: Hand,side: int) -> bool:
	if hand == null:
		return false

	for card: Card in hand.cards_in_hand:
		if is_card_playable_now(card, side):
			return true

	return false
	
func get_playable_cards(hand: Hand,side: int) -> Array[Card]:
	var result: Array[Card] = []

	if hand == null:
		return result

	for card: Card in hand.cards_in_hand:
		if is_card_playable_now(card, side):
			result.append(card)

	return result

func register_forced_skip() -> bool:
	consecutive_forced_skips += 1
	return consecutive_forced_skips >= MAX_CONSECUTIVE_FORCED_SKIPS

func reset_forced_skips() -> void:
	consecutive_forced_skips = 0

func reset_player_spell_count() -> void:
	player_spells_played_this_turn = 0

func register_player_spell_played() -> void:
	player_spells_played_this_turn += 1

func has_player_played_spell_this_turn() -> bool:
	return player_spells_played_this_turn > 0

func hand_has_unit_card(hand: Hand) -> bool:
	if hand == null:
		return false

	for card: Card in hand.cards_in_hand:
		if card is UnitCard:
			return true

	return false
	
func get_mana(side: int) -> int:
	match side:
		Side.PLAYER:
			return player_mana

		Side.ENEMY:
			return enemy_mana

		_:
			push_error("GameDecisionEngine.get_mana: Invalid side.")
			return 0

func get_max_mana(side: int) -> int:
	match side:
		Side.PLAYER:
			return player_max_mana_to_collect

		Side.ENEMY:
			return enemy_max_mana_to_collect

		_:
			push_error("GameDecisionEngine.get_max_mana: Invalid side.")
			return 0

func has_enough_mana(side: int,amount: int) -> bool:
	if amount < 0:
		return false

	return get_mana(side) >= amount
	
func set_mana(side: int,new_amount: int	) -> void:
	match side:
		Side.PLAYER:
			player_mana = clampi(new_amount,0,player_max_mana_to_collect)

		Side.ENEMY:
			enemy_mana = clampi(new_amount,0,enemy_max_mana_to_collect)

		_:
			push_error("GameDecisionEngine.set_mana: Invalid side.")
			return

	_update_mana_inform_labels()
	
func add_mana(side: int,amount: int) -> void:
	if amount <= 0:
		return

	set_mana(side,get_mana(side) + amount)
	
func spend_mana(side: int,amount: int) -> bool:
	if amount < 0:
		push_error(
			"GameDecisionEngine.spend_mana: "
			+ "Amount cannot be negative."
		)
		return false

	if not has_enough_mana(side, amount):
		return false

	set_mana(side,get_mana(side) - amount)

	return true

func _update_mana_inform_labels() -> void:
	if player_mana_inform_label != null:
		player_mana_inform_label.bbcode_enabled = true
		player_mana_inform_label.text = (
			"[color=#7CFC00]"
			+ str(player_mana)
			+ " / "
			+ str(player_max_mana_to_collect)
		)

	if enemy_mana_inform_label != null:
		enemy_mana_inform_label.bbcode_enabled = true
		enemy_mana_inform_label.text = (
			"[color=#F88379]"
			+ str(enemy_mana)
			+ " / "
			+ str(enemy_max_mana_to_collect)
		)

func grant_mana_from_destroyed_cards(destroyed_player_cards: int,destroyed_enemy_cards: int) -> void:
	destroyed_player_cards = maxi(destroyed_player_cards,0)

	destroyed_enemy_cards = maxi(destroyed_enemy_cards,0)

	var mana_gain: int = _calculate_cycle_mana_gain(active_side,destroyed_player_cards,destroyed_enemy_cards)

	if mana_gain <= 0:
		return

	add_mana(active_side,mana_gain)

func _calculate_cycle_mana_gain(side: int,destroyed_player_cards: int,destroyed_enemy_cards: int) -> int:
	var destroyed_friendly_cards: int
	var destroyed_opponent_cards: int

	match side:
		Side.PLAYER:
			destroyed_friendly_cards = destroyed_player_cards
			destroyed_opponent_cards = destroyed_enemy_cards

		Side.ENEMY:
			destroyed_friendly_cards = destroyed_enemy_cards
			destroyed_opponent_cards = destroyed_player_cards

		_:
			push_error("GameDecisionEngine: Invalid side when calculating cycle mana.")
			return 0

	var mana_gain: int

	match mana_policy:
		ManaPolicy.DESTROY_ENEMIES:
			mana_gain = (destroyed_opponent_cards - destroyed_friendly_cards)

		ManaPolicy.SACRIFICE_ALLIES:
			mana_gain = (destroyed_friendly_cards - destroyed_opponent_cards)

		_:
			push_error("GameDecisionEngine: Unsupported mana policy.")
			return 0

	return maxi(mana_gain, 0)

func update_game_info_labels() -> void:
	_update_victory_points_labels()
	_update_mana_inform_labels() 
	_update_deck_labels()
	
func _update_victory_points_labels() -> void:
	if player_victory_points_inform_label != null:
		player_victory_points_inform_label.bbcode_enabled = true
		player_victory_points_inform_label.text = (
			"[color=#00FFFF]"
			+ str(player_score)
			+ " / "
			+ str(player_winning_score)
			+ "[/color]"
		)

	if enemy_victory_points_inform_label != null:
		enemy_victory_points_inform_label.bbcode_enabled = true
		enemy_victory_points_inform_label.text = (
			"[color=#ff5555]"
			+ str(enemy_score)
			+ " / "
			+ str(enemy_winning_score)
			+ "[/color]"
		)

func _update_deck_labels() -> void:
	var player_deck_size: int = 0
	var enemy_deck_size: int = 0

	if player_hand != null:
		player_deck_size = player_hand.deck.size()

	if enemy_hand != null:
		enemy_deck_size = enemy_hand.deck.size()

	if player_deck_inform_label != null:
		player_deck_inform_label.bbcode_enabled = true
		player_deck_inform_label.text = (
			"[color=#ECFFDC]"
			+ str(player_deck_size)
			+ "[/color]"
		)

	if enemy_deck_inform_label != null:
		enemy_deck_inform_label.bbcode_enabled = true
		enemy_deck_inform_label.text = (
			"[color=#ECFFDC]"
			+ str(enemy_deck_size)
			+ "[/color]"
		)

func update_deck_inform_labels() -> void:
	var player_deck_count: int = 0
	var enemy_deck_count: int = 0

	if player_hand != null:
		player_deck_count = player_hand.get_deck_size()

	if enemy_hand != null:
		enemy_deck_count = enemy_hand.get_deck_size()

	if player_deck_inform_label != null:
		player_deck_inform_label.bbcode_enabled = true
		player_deck_inform_label.text = (
			"[color=#ECFFDC]"
			+ str(player_deck_count)
		)

	if enemy_deck_inform_label != null:
		enemy_deck_inform_label.bbcode_enabled = true
		enemy_deck_inform_label.text = (
			"[color=#ECFFDC]"
			+ str(enemy_deck_count)
		)

func _connect_deck_signals() -> void:
	if (
		player_hand != null
		and not player_hand.deck_changed.is_connected(
			update_deck_inform_labels
		)
	):
		player_hand.deck_changed.connect(
			update_deck_inform_labels
		)

	if (
		enemy_hand != null
		and not enemy_hand.deck_changed.is_connected(
			update_deck_inform_labels
		)
	):
		enemy_hand.deck_changed.connect(
			update_deck_inform_labels
		)

func resolve_after_unit_play() -> void:
	resolution_origin = ResolutionOrigin.UNIT_PLAY
	request_transition(check_for_cycle_state)

func resolve_after_spell_play() -> void:
	resolution_origin = ResolutionOrigin.SPELL_PLAY
	request_transition(check_for_cycle_state)

func finish_resolution() -> void:
	match resolution_origin:
		ResolutionOrigin.SPELL_PLAY:
			if active_side == Side.PLAYER:
				request_transition(player_play_card_state)
			else:
				request_transition(enemy_play_card_state)

		ResolutionOrigin.UNIT_PLAY:
			go_to_end_turn()

func rebuild_board_connections() -> void:
	if board_controller == null:
		return

	board_controller.rebuild_all_connections()
