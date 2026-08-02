class_name BoardController extends Node

@export var allow_self_loops: bool = false

var cards_by_id: Dictionary = {}
var outgoing_edges: Dictionary = {}
var incoming_edges: Dictionary = {}
var _next_board_id: int = 1

var _tarjan_next_index: int = 0
var _tarjan_stack: Array[int] = []
var _tarjan_indices: Dictionary = {}
var _tarjan_lowlink: Dictionary = {}
var _tarjan_on_stack: Dictionary = {}
var _tarjan_cycle_members: Dictionary = {}
var _type_change_callbacks: Dictionary = {}

func clear_board() -> void:
	for id_variant in cards_by_id.keys():
		_disconnect_card_signal(int(id_variant))
		var card := cards_by_id[id_variant] as UnitCard
		if is_instance_valid(card):
			card.board_id = Card.INVALID_BOARD_ID
	cards_by_id.clear()
	outgoing_edges.clear()
	incoming_edges.clear()
	_type_change_callbacks.clear()
	_next_board_id = 1

func add_card(card: UnitCard) -> int:
	if not is_instance_valid(card):
		return Card.INVALID_BOARD_ID
	if card.board_id != Card.INVALID_BOARD_ID and cards_by_id.get(card.board_id) == card:
		return card.board_id
	var board_id := _next_board_id
	_next_board_id += 1
	cards_by_id[board_id] = card
	outgoing_edges[board_id] = [] as Array[int]
	incoming_edges[board_id] = [] as Array[int]
	card.board_id = board_id
	_connect_card_signal(card, board_id)
	for other_variant in cards_by_id.keys():
		var other_id := int(other_variant)
		if other_id == board_id:
			continue
		var other := cards_by_id[other_id] as UnitCard
		if can_connect(card, other):
			add_edge(board_id, other_id)
		if can_connect(other, card):
			add_edge(other_id, board_id)
	if allow_self_loops and can_connect(card, card):
		add_edge(board_id, board_id)
	return board_id

func remove_card(card_id: int) -> UnitCard:
	if not cards_by_id.has(card_id):
		return null
	var card := cards_by_id[card_id] as UnitCard
	for from_id in get_incoming(card_id):
		remove_edge(from_id, card_id)
	for to_id in get_outgoing(card_id):
		remove_edge(card_id, to_id)
	_disconnect_card_signal(card_id)
	cards_by_id.erase(card_id)
	outgoing_edges.erase(card_id)
	incoming_edges.erase(card_id)
	if is_instance_valid(card):
		card.board_id = Card.INVALID_BOARD_ID
	return card

func remove_cards(card_ids: Array[int]) -> Array[UnitCard]:
	var unique_ids: Array[int] = []
	var snapshot: Array[UnitCard] = []
	for card_id in card_ids:
		if cards_by_id.has(card_id) and not unique_ids.has(card_id):
			unique_ids.append(card_id)
			snapshot.append(cards_by_id[card_id] as UnitCard)
	for card_id in unique_ids:
		remove_card(card_id)
	return snapshot

func add_edge(from_id: int, to_id: int) -> void:
	if not cards_by_id.has(from_id) or not cards_by_id.has(to_id):
		return
	if from_id == to_id and not allow_self_loops:
		return
	var outgoing: Array = outgoing_edges[from_id]
	var incoming: Array = incoming_edges[to_id]
	if not outgoing.has(to_id):
		outgoing.append(to_id)
	if not incoming.has(from_id):
		incoming.append(from_id)

func remove_edge(from_id: int, to_id: int) -> void:
	if outgoing_edges.has(from_id):
		(outgoing_edges[from_id] as Array).erase(to_id)
	if incoming_edges.has(to_id):
		(incoming_edges[to_id] as Array).erase(from_id)

func can_connect(from_card: UnitCard, to_card: UnitCard) -> bool:
	if from_card == null or to_card == null:
		return false
	for target_type in from_card.target_types:
		if to_card.source_types.has(target_type):
			return true
	return false

func rebuild_connections(card_id: int) -> void:
	if not cards_by_id.has(card_id):
		return
	for to_id in get_outgoing(card_id):
		remove_edge(card_id, to_id)
	for from_id in get_incoming(card_id):
		remove_edge(from_id, card_id)
	var card := cards_by_id[card_id] as UnitCard
	for other_variant in cards_by_id.keys():
		var other_id := int(other_variant)
		if other_id == card_id:
			continue
		var other := cards_by_id[other_id] as UnitCard
		if can_connect(card, other):
			add_edge(card_id, other_id)
		if can_connect(other, card):
			add_edge(other_id, card_id)
	if allow_self_loops and can_connect(card, card):
		add_edge(card_id, card_id)

func find_cycle_participants() -> Array[int]:
	_tarjan_next_index = 0
	_tarjan_stack.clear()
	_tarjan_indices.clear()
	_tarjan_lowlink.clear()
	_tarjan_on_stack.clear()
	_tarjan_cycle_members.clear()
	for id_variant in cards_by_id.keys():
		var id := int(id_variant)
		if not _tarjan_indices.has(id):
			_strongconnect(id)
	var result: Array[int] = []
	for id_variant in _tarjan_cycle_members.keys():
		result.append(int(id_variant))
	result.sort()
	return result

func _strongconnect(vertex: int) -> void:
	_tarjan_indices[vertex] = _tarjan_next_index
	_tarjan_lowlink[vertex] = _tarjan_next_index
	_tarjan_next_index += 1

	_tarjan_stack.append(vertex)
	_tarjan_on_stack[vertex] = true

	var neighbours: Array[int] = get_outgoing(vertex)

	for neighbour: int in neighbours:
		if not _tarjan_indices.has(neighbour):
			_strongconnect(neighbour)

			var current_lowlink: int = int(
				_tarjan_lowlink[vertex]
			)
			var neighbour_lowlink: int = int(
				_tarjan_lowlink[neighbour]
			)

			_tarjan_lowlink[vertex] = mini(
				current_lowlink,
				neighbour_lowlink
			)

		elif bool(_tarjan_on_stack.get(neighbour, false)):
			var current_lowlink: int = int(
				_tarjan_lowlink[vertex]
			)
			var neighbour_index: int = int(
				_tarjan_indices[neighbour]
			)

			_tarjan_lowlink[vertex] = mini(
				current_lowlink,
				neighbour_index
			)

	if int(_tarjan_lowlink[vertex]) != int(
		_tarjan_indices[vertex]
	):
		return

	var component: Array[int] = []

	while not _tarjan_stack.is_empty():
		var member_variant: Variant = _tarjan_stack.pop_back()
		var member: int = int(member_variant)

		_tarjan_on_stack[member] = false
		component.append(member)

		if member == vertex:
			break

	var is_cycle: bool = component.size() > 1

	if component.size() == 1:
		var single_member: int = component[0]
		is_cycle = get_outgoing(single_member).has(single_member)

	if is_cycle:
		for member: int in component:
			_tarjan_cycle_members[member] = true
			
			
func get_card(card_id: int) -> UnitCard:
	return cards_by_id.get(card_id) as UnitCard

func get_all_cards() -> Array[UnitCard]:
	var result: Array[UnitCard] = []
	for card in cards_by_id.values():
		result.append(card as UnitCard)
	return result

func get_all_card_ids() -> Array[int]:
	var result: Array[int] = []
	for id_variant in cards_by_id.keys():
		result.append(int(id_variant))
	result.sort()
	return result

func get_outgoing(card_id: int) -> Array[int]:
	var result: Array[int] = []
	for id_variant in outgoing_edges.get(card_id, []):
		result.append(int(id_variant))
	return result

func get_incoming(card_id: int) -> Array[int]:
	var result: Array[int] = []
	for id_variant in incoming_edges.get(card_id, []):
		result.append(int(id_variant))
	return result

func _connect_card_signal(card: UnitCard, board_id: int) -> void:
	var callback := Callable(self, "_on_card_connection_types_changed").bind(board_id)
	_type_change_callbacks[board_id] = callback
	if not card.connection_types_changed.is_connected(callback):
		card.connection_types_changed.connect(callback)

func _disconnect_card_signal(board_id: int) -> void:
	if not cards_by_id.has(board_id) or not _type_change_callbacks.has(board_id):
		return
	var card := cards_by_id[board_id] as UnitCard
	var callback: Callable = _type_change_callbacks[board_id]
	if is_instance_valid(card) and card.connection_types_changed.is_connected(callback):
		card.connection_types_changed.disconnect(callback)
	_type_change_callbacks.erase(board_id)

func _on_card_connection_types_changed(board_id: int) -> void:
	rebuild_connections(board_id)
