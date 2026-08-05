class_name GameDecisionEngine extends Node

signal control_button_pressed
signal state_changed(previous: State, current: State)
signal score_changed(player_score: int, enemy_score: int)
signal game_finished(player_won: bool)

enum Side { PLAYER, ENEMY }
enum ScorePolicy { ACTIVE_SIDE_GETS_ALL, EACH_OWNER_GETS_OWN }
const CYCLE_VISUALIZER_SCENE = preload("uid://c81aoxm08v8tf")

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
@export var enemy_think_time: float = 1.0
@export var score_policy: ScorePolicy = ScorePolicy.ACTIVE_SIDE_GETS_ALL
@export var randomize_seed: bool = true
@export var fixed_seed: int = 1

var player_score: int = 0
var enemy_score: int = 0
var active_side: int = Side.PLAYER
var current_state: State = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var pending_destroy_ids: Array[int] = []
var pending_score_enabled: bool = false
var pending_total_points: int = 0
var pending_player_owned_points: int = 0
var pending_enemy_owned_points: int = 0
var active_spell_card: SpellCard

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

func _ready() -> void:
	_initialize_cycle_visualizer()
	_initialize_states()
	_initialize_slots()
	_initialize_random_generator()

	controll_turn_button.disabled = true
	controll_turn_button.text = ""

	controll_turn_button.pressed.connect(_on_control_turn_button_pressed)

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
	active_side = Side.PLAYER
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
	else:
		enemy_score += amount
	score_changed.emit(player_score, enemy_score)

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
	
