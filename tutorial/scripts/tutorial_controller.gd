class_name TutorialController
extends Node

signal state_changed(previous: TutorialState, current: TutorialState)
signal player_card_placed(card: UnitCard, slot: CardSlot)
signal score_changed(player_score: int, enemy_score: int)
signal tutorial_completed
signal tutorial_skipped

enum Side { PLAYER, ENEMY }

@export_category("Required References")
@export var tutorial_setup: TutorialSetup
@export var board_controller: BoardController
@export var player_hand: TutorialHand
@export var enemy_hand: TutorialHand
@export var card_dragger: TutorialCardDragger
@export var player_slots: Array[CardSlot] = []
@export var enemy_slots: Array[CardSlot] = []

@export_category("Presentation — optional, created automatically if empty")
@export var overlay: TutorialOverlay
@export var cycle_visualizer: TutorialCycleVisualizer

@export_category("Optional Existing UI")
@export var player_score_label: RichTextLabel
@export var enemy_score_label: RichTextLabel
@export var player_deck_label: RichTextLabel
@export var enemy_deck_label: RichTextLabel
@export var state_label: Label
@export var ui_to_hide: Array[CanvasItem] = []

@export_category("States — optional, created automatically if empty")
@export var enter_state: TutorialState
@export var place_first_card_state: TutorialState
@export var wait_for_enemy_card_state: TutorialState
@export var explain_connection_state: TutorialState
@export var place_closing_card_state: TutorialState
@export var watch_cycle_state: TutorialState
@export var finish_tutorial_state: TutorialState

var current_state: TutorialState = null
var player_score: int = 0
var enemy_score: int = 0
var player_mana: int = 0
var enemy_mana: int = 0
var active_side: int = Side.PLAYER
var first_player_card: UnitCard
var scripted_enemy_card: UnitCard
var closing_player_card: UnitCard

var _selected_card: UnitCard = null
var _pending_cycle: CycleData
var _next_state: TutorialState = null
var _transition_queued: bool = false
var _running: bool = false
var _leaving: bool = false
var _revision: int = 0
var _enemy_motion_tween: Tween = null
var _wait_timers: Array[Timer] = []
var _normal_icon_pulse_duration: float = 1.0
var _normal_icon_intensity_min: float = -0.5
var _normal_icon_intensity_max: float = 0.3


func _ready() -> void:
	call_deferred("_start_tutorial")


func _start_tutorial() -> void:
	if overlay == null:
		var overlay_scene: PackedScene = load("res://tutorial/tutorial_overlay.tscn") as PackedScene
		overlay = overlay_scene.instantiate() as TutorialOverlay
		add_child(overlay)
	if cycle_visualizer == null:
		var visualizer_scene: PackedScene = (
			load("res://tutorial/tutorial_cycle_visualizer.tscn") as PackedScene
		)
		cycle_visualizer = visualizer_scene.instantiate() as TutorialCycleVisualizer
		add_child(cycle_visualizer)
	_normal_icon_pulse_duration = cycle_visualizer.icon_pulse_duration
	_normal_icon_intensity_min = cycle_visualizer.icon_intensity_min
	_normal_icon_intensity_max = cycle_visualizer.icon_intensity_max
	overlay.resolve_button.disabled = true
	overlay.adventure_button.disabled = true
	overlay.skip_button.pressed.connect(_on_skip_pressed)
	overlay.adventure_button.pressed.connect(_on_adventure_pressed)
	if tutorial_setup != null:
		overlay.skip_button.visible = tutorial_setup.allow_skip
		overlay.skip_button.disabled = not tutorial_setup.allow_skip
		overlay.adventure_button.text = tutorial_setup.adventure_button_text
	var errors: Array[String] = _get_reference_errors()
	if not errors.is_empty():
		fail_tutorial("\n".join(errors))
		return
	errors = tutorial_setup.get_configuration_errors()
	if not errors.is_empty():
		fail_tutorial("\n".join(errors))
		return
	_initialize_states()
	_initialize_slots()
	player_hand.is_enemy = false
	enemy_hand.is_enemy = true
	player_hand.debug_draw_with_space = false
	enemy_hand.debug_draw_with_space = false
	card_dragger.clear_allowed_card()
	card_dragger.card_drop_requested.connect(_on_card_drop_requested)
	player_hand.deck_changed.connect(update_info_labels)
	enemy_hand.deck_changed.connect(update_info_labels)
	for item: CanvasItem in ui_to_hide:
		if is_instance_valid(item):
			item.hide()
	tutorial_setup.apply_header()
	_running = true
	request_transition(enter_state)


func _process(delta: float) -> void:
	if is_state_active(current_state):
		current_state.update(delta)


func request_transition(next_state: TutorialState) -> void:
	if not _running or _leaving:
		return
	if next_state == null:
		fail_tutorial("A null tutorial state was requested.")
		return
	if _next_state != null:
		return
	_next_state = next_state
	_lock_player_input()
	if not _transition_queued:
		_transition_queued = true
		call_deferred("_flush_transition")


func _flush_transition() -> void:
	_transition_queued = false
	if not _running or _leaving or _next_state == null:
		return
	var next_state: TutorialState = _next_state
	_next_state = null
	var previous: TutorialState = current_state
	_revision += 1
	_cancel_waits()
	if previous != null:
		previous.exit()
	current_state = next_state
	current_state.visit = _revision
	overlay.begin_step(current_state, tutorial_setup.default_animation_name)
	if state_label != null:
		state_label.text = String(current_state.name)
	state_changed.emit(previous, current_state)
	current_state.enter()


func is_state_active(state: TutorialState) -> bool:
	return (
		_running
		and not _leaving
		and _next_state == null
		and state != null
		and current_state == state
	)


func wait_seconds(seconds: float, owner_state: TutorialState, visit: int) -> bool:
	if not _same_visit(owner_state, visit):
		return false
	# Owned Timer nodes allow Skip/scene exit to release the await immediately.
	# Unlike SceneTreeTimer, a cancelled timer cannot retain a coroutine cycle.
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.001)
	add_child(timer)
	_wait_timers.append(timer)
	timer.start()
	await timer.timeout
	_wait_timers.erase(timer)
	timer.queue_free()
	return _same_visit(owner_state, visit)


func wait_for_animation(owner_state: TutorialState, visit: int) -> bool:
	while _same_visit(owner_state, visit):
		if overlay.first_animation_pass_finished:
			return true
		await get_tree().process_frame
	return false


func prepare_match() -> bool:
	player_score = 0
	enemy_score = 0
	player_mana = 0
	enemy_mana = 0
	active_side = Side.PLAYER
	first_player_card = null
	scripted_enemy_card = null
	closing_player_card = null
	_pending_cycle = null
	cycle_visualizer.clear_visualization()
	for card: UnitCard in board_controller.get_all_cards():
		if is_instance_valid(card):
			card.destroy()
	board_controller.clear_board()
	for slot: CardSlot in player_slots + enemy_slots:
		slot.clear_slot(false)
	var player_cards: Array[Card] = _create_unit_deck(tutorial_setup.player_card_ids)
	if not _running:
		return false
	var enemy_cards: Array[Card] = _create_unit_deck(tutorial_setup.enemy_card_ids)
	if not _running:
		_free_unparented_cards(player_cards)
		return false
	var scenario_error: String = _get_scenario_error(player_cards, enemy_cards)
	if not scenario_error.is_empty():
		_free_unparented_cards(player_cards)
		_free_unparented_cards(enemy_cards)
		fail_tutorial(scenario_error)
		return false
	player_hand.setup_deck(player_cards)
	enemy_hand.setup_deck(enemy_cards)
	_lock_player_input()
	update_info_labels()
	score_changed.emit(player_score, enemy_score)
	return true


func draw_scripted_card(for_player: bool, card_id: int) -> UnitCard:
	var hand: TutorialHand = player_hand if for_player else enemy_hand
	var card: UnitCard = hand.draw_card_by_id(card_id)
	if card == null:
		fail_tutorial("%s cannot draw scripted card ID %d." % [hand.name, card_id])
		return null
	_set_pickable_recursive(card, false)
	var sound: AudioStream = (
		tutorial_setup.player_draw_sound if for_player else tutorial_setup.enemy_draw_sound
	)
	var position: Vector2 = hand.global_position
	if hand.deck_sprite != null:
		position = hand.deck_sprite.global_position
	_play_spatial_sound(sound, position, for_player, 0.25)
	update_info_labels()
	return card


func allow_player_card(card_id: int) -> void:
	active_side = Side.PLAYER
	_selected_card = player_hand.find_unit_by_id(card_id)
	if _selected_card == null:
		fail_tutorial("Player hand contains no playable copy of required ID %d." % card_id)
		return
	var slots: Array[CardSlot] = get_empty_slots(Side.PLAYER)
	if slots.is_empty():
		fail_tutorial("There is no free player slot for the required tutorial card.")
		return
	_set_pickable_recursive(_selected_card, true)
	card_dragger.set_allowed_card(_selected_card, slots)
	overlay.start_card_glow(
		_selected_card,
		tutorial_setup.card_glow_intensity_min,
		tutorial_setup.card_glow_intensity_max,
		tutorial_setup.card_glow_duration
	)


func _on_card_drop_requested(card: Card, slot: CardSlot) -> void:
	if (
		not is_state_active(current_state)
		or card != _selected_card
		or (current_state != place_first_card_state and current_state != place_closing_card_state)
	):
		card_dragger.reject_last_drop(card)
		return
	var unit: UnitCard = card as UnitCard
	if not try_play_unit(unit, slot, Side.PLAYER):
		card_dragger.reject_last_drop(card)
		return
	overlay.stop_card_glow()
	_lock_player_input()
	_play_spatial_sound(tutorial_setup.placing_card_sound, slot.global_position, true, 0.25)
	player_card_placed.emit(unit, slot)


func try_play_unit(card: UnitCard, slot: CardSlot, side: int) -> bool:
	# Same Hand -> CardSlot -> BoardController transaction as GameDecisionEngine.
	if not is_instance_valid(card) or not is_instance_valid(slot) or active_side != side:
		return false
	var hand: TutorialHand = player_hand if side == Side.PLAYER else enemy_hand
	var slots: Array[CardSlot] = player_slots if side == Side.PLAYER else enemy_slots
	if (
		not hand.cards_in_hand.has(card)
		or not slots.has(slot)
		or slot.card_in_slot
		or card.is_enemy_card != (side == Side.ENEMY)
		or slot.is_enemy_slot != (side == Side.ENEMY)
	):
		return false
	if not hand.remove_card(card):
		return false
	if not slot.place_card(card):
		hand.add_existing_card(card)
		return false
	if board_controller.add_card(card) == Card.INVALID_BOARD_ID:
		var returned_card: Card = slot.clear_slot()
		if returned_card != null:
			hand.add_existing_card(returned_card)
		return false
	_set_pickable_recursive(card, false)
	return true


func get_empty_slots(side: int) -> Array[CardSlot]:
	var source: Array[CardSlot] = player_slots if side == Side.PLAYER else enemy_slots
	var empty: Array[CardSlot] = []
	for slot: CardSlot in source:
		if is_instance_valid(slot) and not slot.card_in_slot:
			empty.append(slot)
	return empty


func play_scripted_enemy_card(owner_state: TutorialState, visit: int) -> bool:
	if not _same_visit(owner_state, visit):
		return false
	var card: UnitCard = enemy_hand.find_unit_by_id(tutorial_setup.enemy_first_play_id)
	var slots: Array[CardSlot] = get_empty_slots(Side.ENEMY)
	if card == null or slots.is_empty():
		fail_tutorial(
			(
				"Enemy hand is missing required ID %d, or it has no free slot."
				% tutorial_setup.enemy_first_play_id
			)
		)
		return false
	var slot: CardSlot = slots[0]
	var start_position: Vector2 = card.global_position
	var start_rotation: float = card.global_rotation
	var start_scale: Vector2 = card.global_scale
	if not try_play_unit(card, slot, Side.ENEMY):
		fail_tutorial("Enemy could not place its scripted card.")
		return false
	scripted_enemy_card = card
	card.global_position = start_position
	card.global_rotation = start_rotation
	card.global_scale = start_scale
	var duration: float = maxf(tutorial_setup.enemy_play_duration, 0.01)
	var target: Vector2 = slot.global_position
	var middle: Vector2 = start_position.lerp(target, 0.5) + Vector2(0.0, -100.0)
	_enemy_motion_tween = create_tween()
	(
		_enemy_motion_tween
		. tween_property(card, "global_position", middle, duration * 0.45)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_enemy_motion_tween.parallel().tween_property(card, "global_rotation", 0.05, duration * 0.45)
	(
		_enemy_motion_tween
		. tween_property(card, "global_position", target, duration * 0.55)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_enemy_motion_tween.parallel().tween_property(
		card, "global_rotation", slot.global_rotation, duration * 0.55
	)
	_enemy_motion_tween.parallel().tween_property(
		card, "global_scale", Vector2.ONE, duration * 0.55
	)
	_play_spatial_sound(tutorial_setup.placing_card_sound, target, false, 0.25)
	if not await wait_seconds(duration, owner_state, visit):
		return false
	if not is_instance_valid(card):
		fail_tutorial("Enemy card disappeared before its reveal.")
		return false
	card.set_card_hide(false)
	return true


func show_connection_preview() -> bool:
	if not is_instance_valid(first_player_card) or not is_instance_valid(scripted_enemy_card):
		fail_tutorial("The first two tutorial cards are missing from the board.")
		return false
	var data: CycleData = CycleData.new()
	data.card_ids.assign([first_player_card.board_id, scripted_enemy_card.board_id])
	data.edges = board_controller.get_edges_between(data.card_ids)
	if data.edges.is_empty():
		fail_tutorial("The first player card and enemy card share no directed connection.")
		return false
	cycle_visualizer.icon_pulse_duration = tutorial_setup.preview_icon_pulse_duration
	cycle_visualizer.icon_intensity_min = tutorial_setup.preview_icon_intensity_min
	cycle_visualizer.icon_intensity_max = tutorial_setup.preview_icon_intensity_max
	cycle_visualizer.arrow_pulse_duration = tutorial_setup.preview_arrow_pulse_duration
	cycle_visualizer.arrow_alpha_min = tutorial_setup.preview_arrow_alpha_min
	cycle_visualizer.arrow_alpha_max = tutorial_setup.preview_arrow_alpha_max
	cycle_visualizer.show_connection_preview(data, board_controller)
	return true


func show_tutorial_cycle() -> bool:
	_pending_cycle = board_controller.find_cycle_data()
	if _pending_cycle.card_ids.size() != 3:
		fail_tutorial("Scripted cards must create a real three-card cycle; none was fabricated.")
		return false
	cycle_visualizer.icon_pulse_duration = _normal_icon_pulse_duration
	cycle_visualizer.icon_intensity_min = _normal_icon_intensity_min
	cycle_visualizer.icon_intensity_max = _normal_icon_intensity_max
	cycle_visualizer.show_cycle(_pending_cycle, board_controller)
	_play_spatial_sound(tutorial_setup.cycle_sound, Vector2.ZERO, true, 0.55)
	return true


func resolve_tutorial_cycle(owner_state: TutorialState, visit: int) -> bool:
	if not _same_visit(owner_state, visit) or _pending_cycle == null:
		return false
	# Stop all icon tweens before destroying their nodes; remove the arrows as well.
	cycle_visualizer.clear_visualization()
	var total_points: int = 0
	var ids: Array[int] = _pending_cycle.card_ids.duplicate()
	for index: int in range(ids.size()):
		if not _same_visit(owner_state, visit):
			return false
		var card: UnitCard = board_controller.remove_card(ids[index])
		if not is_instance_valid(card):
			fail_tutorial("A cycle participant disappeared during resolution.")
			return false
		total_points += card.get_points()
		if not tutorial_setup.explosion_sounds.is_empty():
			var sound: AudioStream = tutorial_setup.explosion_sounds[
				index % tutorial_setup.explosion_sounds.size()
			]
			_play_spatial_sound(sound, card.global_position, false, 0.2)
		card.destroy()
		if not await wait_seconds(tutorial_setup.destroy_card_interval, owner_state, visit):
			return false
	_pending_cycle = null
	player_score = mini(player_score + total_points, tutorial_setup.player_winning_score)
	update_info_labels()
	score_changed.emit(player_score, enemy_score)
	if player_score < tutorial_setup.player_winning_score:
		fail_tutorial("The real card points are insufficient for the tutorial victory.")
		return false
	return true


func update_info_labels() -> void:
	if tutorial_setup == null:
		return
	_set_label(
		player_score_label,
		"#7CFC00",
		"%d / %d" % [player_score, tutorial_setup.player_winning_score]
	)
	_set_label(
		enemy_score_label, "#ff5555", "%d / %d" % [enemy_score, tutorial_setup.enemy_winning_score]
	)
	if player_hand != null:
		_set_label(player_deck_label, "#ECFFDC", str(player_hand.get_deck_size()))
	if enemy_hand != null:
		_set_label(enemy_deck_label, "#ECFFDC", str(enemy_hand.get_deck_size()))


func fail_tutorial(message: String) -> void:
	push_warning("TutorialController: " + message)
	_stop_flow()
	if is_instance_valid(overlay):
		overlay.show_problem()


func _stop_flow() -> void:
	_running = false
	_revision += 1
	_next_state = null
	_cancel_waits()
	if current_state != null:
		current_state.exit()
	current_state = null
	if _enemy_motion_tween != null and _enemy_motion_tween.is_valid():
		_enemy_motion_tween.kill()
	_enemy_motion_tween = null
	_lock_player_input()
	if is_instance_valid(cycle_visualizer):
		cycle_visualizer.clear_visualization()
	if is_instance_valid(overlay):
		overlay.stop_card_glow()
		overlay.hide_all_panels()
		overlay.resolve_button.hide()
		overlay.adventure_button.hide()
		if tutorial_setup != null:
			overlay.reset_state_animation(tutorial_setup.default_animation_name)


func _on_skip_pressed() -> void:
	if tutorial_setup != null and tutorial_setup.allow_skip:
		_leave_for_adventure(true)


func _on_adventure_pressed() -> void:
	if is_state_active(finish_tutorial_state) and overlay.first_animation_pass_finished:
		_leave_for_adventure(false)


func _leave_for_adventure(skipped: bool) -> void:
	if _leaving:
		return
	var destination: PackedScene = load(tutorial_setup.adventure_scene_path) as PackedScene
	if destination == null:
		push_warning("TutorialController: adventure_scene_path is not a loadable PackedScene.")
		return
	_leaving = true
	var result: Error = get_tree().change_scene_to_packed(destination)
	if result != OK:
		_leaving = false
		push_warning("TutorialController: scene change failed with error %d." % result)
		return
	_stop_flow()
	if skipped:
		tutorial_skipped.emit()


func _lock_player_input() -> void:
	if is_instance_valid(card_dragger):
		card_dragger.clear_allowed_card()
	_selected_card = null
	for hand: TutorialHand in [player_hand, enemy_hand]:
		if not is_instance_valid(hand):
			continue
		for card: Card in hand.cards_in_hand:
			if is_instance_valid(card):
				_set_pickable_recursive(card, false)


func _set_pickable_recursive(node: Node, value: bool) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).input_pickable = value
	for child: Node in node.get_children():
		_set_pickable_recursive(child, value)


func _same_visit(state: TutorialState, visit: int) -> bool:
	return is_state_active(state) and _revision == visit


func _cancel_waits() -> void:
	for timer: Timer in _wait_timers.duplicate():
		if is_instance_valid(timer):
			timer.stop()
			timer.timeout.emit()
	_wait_timers.clear()


func _initialize_states() -> void:
	enter_state = _make_state(enter_state, "EnterState", "enter_state.gd")
	place_first_card_state = _make_state(
		place_first_card_state, "PlaceFirstCard", "place_first_card_state.gd"
	)
	wait_for_enemy_card_state = _make_state(
		wait_for_enemy_card_state, "WaitForEnemyCard", "wait_for_enemy_card_state.gd"
	)
	explain_connection_state = _make_state(
		explain_connection_state, "ExplainConnection", "explain_connection_state.gd"
	)
	place_closing_card_state = _make_state(
		place_closing_card_state, "PlaceClosingCard", "place_closing_card_state.gd"
	)
	watch_cycle_state = _make_state(watch_cycle_state, "WatchCycle", "watch_cycle_state.gd")
	finish_tutorial_state = _make_state(
		finish_tutorial_state, "FinishTutorial", "finish_tutorial_state.gd"
	)


func _make_state(existing: TutorialState, state_name: String, filename: String) -> TutorialState:
	var state: TutorialState = existing
	if state == null:
		var state_script: Script = load("res://tutorial/states/" + filename) as Script
		state = state_script.new() as TutorialState
		state.name = state_name
		add_child(state)
	else:
		state.name = state_name
	state.setup(self)
	return state


func _initialize_slots() -> void:
	for slot: CardSlot in player_slots:
		slot.is_enemy_slot = false
	for slot: CardSlot in enemy_slots:
		slot.is_enemy_slot = true


func _get_reference_errors() -> Array[String]:
	var errors: Array[String] = []
	if tutorial_setup == null:
		errors.append("Assign tutorial_setup.")
	if board_controller == null:
		errors.append("Assign board_controller.")
	if player_hand == null or enemy_hand == null or player_hand == enemy_hand:
		errors.append("Assign two different TutorialHand nodes.")
	if card_dragger == null:
		errors.append("Assign a TutorialCardDragger node.")
	if player_slots.size() < 2 or enemy_slots.is_empty():
		errors.append("Assign at least two player slots and one enemy slot.")
	var seen: Dictionary = {}
	for slot: CardSlot in player_slots + enemy_slots:
		if slot == null:
			errors.append("Slot arrays contain a null entry.")
		elif seen.has(slot.get_instance_id()):
			errors.append("A slot is assigned more than once.")
		else:
			seen[slot.get_instance_id()] = true
	return errors


func _create_unit_deck(ids: Array[int]) -> Array[Card]:
	var cards: Array[Card] = []
	for card_id: int in ids:
		var card: Card = CardManager.call("create_card_by_id", card_id) as Card
		if card == null or not card is UnitCard:
			if is_instance_valid(card):
				card.queue_free()
			_free_unparented_cards(cards)
			fail_tutorial(
				"ID %d is missing or is not a UnitCard. Spells are unsupported here." % card_id
			)
			return []
		cards.append(card)
	return cards


func _get_scenario_error(player_cards: Array[Card], enemy_cards: Array[Card]) -> String:
	var first: UnitCard = _find_in_deck(player_cards, tutorial_setup.player_first_play_id)
	var enemy: UnitCard = _find_in_deck(enemy_cards, tutorial_setup.enemy_first_play_id)
	var closing: UnitCard = _find_in_deck(player_cards, tutorial_setup.player_second_play_id)
	if first == null or enemy == null or closing == null:
		return "A scripted play ID could not be created as a unit."
	var forward: bool = (
		board_controller.can_connect(first, enemy)
		and board_controller.can_connect(enemy, closing)
		and board_controller.can_connect(closing, first)
	)
	var reverse: bool = (
		board_controller.can_connect(first, closing)
		and board_controller.can_connect(closing, enemy)
		and board_controller.can_connect(enemy, first)
	)
	if not forward and not reverse:
		return "The three scripted IDs do not form a directed three-card cycle. Check their types."
	if (
		first.get_points() + enemy.get_points() + closing.get_points()
		< tutorial_setup.player_winning_score
	):
		return "The three scripted cards do not contain enough points for the configured victory."
	return ""


func _find_in_deck(cards: Array[Card], card_id: int) -> UnitCard:
	for card: Card in cards:
		if card.card_id == card_id:
			return card as UnitCard
	return null


func _free_unparented_cards(cards: Array[Card]) -> void:
	for card: Card in cards:
		if is_instance_valid(card) and card.get_parent() == null:
			card.queue_free()


func _set_label(label: RichTextLabel, color_hex: String, value: String) -> void:
	if label != null:
		label.bbcode_enabled = true
		label.text = "[color=%s]%s[/color]" % [color_hex, value]


func _play_spatial_sound(
	sound: AudioStream, position: Vector2, player_side: bool, end_offset: float
) -> void:
	if sound == null:
		return
	var audio: Node = get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sound"):
		audio.call("play_spatial_sound", sound, position, false, player_side, end_offset)


func _exit_tree() -> void:
	_running = false
	_revision += 1
	_cancel_waits()
	if _enemy_motion_tween != null and _enemy_motion_tween.is_valid():
		_enemy_motion_tween.kill()
