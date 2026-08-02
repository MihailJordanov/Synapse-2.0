@icon("res://resources/icons/deck_dragger.svg")
class_name CardDragger extends Node2D

signal card_drop_requested(card: Card, slot: CardSlot)

const COLLISION_MASK_CARD: int = 3
const COLLISION_MASK_CARD_SLOT: int = 4

var enabled: bool = false
var allowed_slots: Array[CardSlot] = []
var card_being_dragged: Card
var hovered_card: Card
var _origin_parent: Node
var _origin_global_position: Vector2
var _origin_rotation: float

func _process(_delta: float) -> void:
	if enabled and card_being_dragged:
		card_being_dragged.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card := raycast_check_for_card()
			if card:
				start_drag(card)
		else:
			finish_drag()

func set_play_context(value: bool, slots: Array[CardSlot]) -> void:
	enabled = value
	allowed_slots = slots.duplicate()
	if not enabled and card_being_dragged:
		_restore_dragged_card()

func start_drag(card: Card) -> void:
	if card == null or card.current_slot != null or card.is_enemy_card:
		return
	card_being_dragged = card
	_origin_parent = card.get_parent()
	_origin_global_position = card.global_position
	_origin_rotation = card.rotation
	card.rotation = 0.0
	card.z_as_relative = false
	card.z_index = 100
	card.scale = Vector2(1.1, 1.1)

func finish_drag() -> void:
	if card_being_dragged == null:
		return
	var card := card_being_dragged
	var slot := raycast_check_for_card_slot()
	card_being_dragged = null
	card.scale = Vector2.ONE
	if slot and allowed_slots.has(slot) and not slot.card_in_slot:
		card_drop_requested.emit(card, slot)
	else:
		_restore_card(card)

func reject_last_drop(card: Card) -> void:
	_restore_card(card)

func _restore_dragged_card() -> void:
	var card := card_being_dragged
	card_being_dragged = null
	_restore_card(card)

func _restore_card(card: Card) -> void:
	if card == null:
		return
	card.z_as_relative = true
	card.z_index = 0
	card.scale = Vector2.ONE
	if _origin_parent is Hand:
		(_origin_parent as Hand).rearrange_hand()
	else:
		card.global_position = _origin_global_position
		card.rotation = _origin_rotation

func raycast_check_for_card() -> Card:
	var params: PhysicsPointQueryParameters2D = \
		PhysicsPointQueryParameters2D.new()

	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD

	var results: Array[Dictionary] = \
		get_world_2d().direct_space_state.intersect_point(params)

	var best: Card = null

	for hit: Dictionary in results:
		var collider: Node = hit.get("collider") as Node

		if collider == null:
			continue

		var card: Card = collider.get_parent() as Card

		if card == null:
			continue

		if card.is_enemy_card:
			continue

		if best == null or card.z_index > best.z_index:
			best = card

	return best
	
	
func raycast_check_for_card_slot() -> CardSlot:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_CARD_SLOT
	var result := get_world_2d().direct_space_state.intersect_point(params)
	if result.is_empty():
		return null
	return (result[0].collider as Node).get_parent() as CardSlot
