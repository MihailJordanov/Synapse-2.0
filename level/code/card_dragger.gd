@icon("res://resources/icons/deck_dragger.svg")
class_name CardDragger extends Node2D

signal card_drop_requested(card: Card, slot: CardSlot)

const COLLISION_MASK_CARD: int = 3
const COLLISION_MASK_CARD_SLOT: int = 4

@export_category("Drag Feel")
@export var drag_scale: float = 1.35
@export var drag_follow_speed: float = 18.0
@export var drag_rotation_strength: float = 0.003
@export var drag_max_rotation_degrees: float = 8.0
@export var drop_animation_duration: float = 0.22

var enabled: bool = false
var allowed_slots: Array[CardSlot] = []
var card_being_dragged: Card
var hovered_card: Card
var _origin_parent: Node
var _origin_global_position: Vector2
var _origin_rotation: float
var _last_hovered_card: Card = null
var _last_mouse_position: Vector2

func _process(_delta: float) -> void:
	if card_being_dragged != null:
		_update_dragged_card()
		return

	_update_hovered_card()

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
	if card == null:
		return

	if card.current_slot != null:
		return

	if card.is_enemy_card:
		return

	card_being_dragged = card

	_origin_parent = card.get_parent()
	_origin_global_position = card.global_position
	_origin_rotation = card.rotation

	_last_mouse_position = get_global_mouse_position()

	if _origin_parent is Hand:
		var hand := _origin_parent as Hand

		hand.clear_hovered_card(card)
		hand.begin_drag(card)

	_last_hovered_card = null

	card.z_as_relative = false
	card.z_index = 1000

	var tween: Tween = card.create_tween()

	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(
		card,
		"scale",
		Vector2.ONE * drag_scale,
		0.15
	)

	tween.tween_property(
		card,
		"rotation",
		0.0,
		0.12
	)
	
	
func finish_drag() -> void:
	if card_being_dragged == null:
		return

	var card: Card = card_being_dragged

	var slot: CardSlot = (
		raycast_check_for_card_slot()
	)

	card_being_dragged = null

	if slot != null:
		if (
			allowed_slots.has(slot)
			and not slot.card_in_slot
		):
			card_drop_requested.emit(
				card,
				slot
			)

			return

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

	if _origin_parent is Hand:
		var hand := _origin_parent as Hand

		hand.end_drag(card)
		return

	var tween: Tween = card.create_tween()

	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(
		card,
		"global_position",
		_origin_global_position,
		drop_animation_duration
	)

	tween.tween_property(
		card,
		"rotation",
		_origin_rotation,
		drop_animation_duration
	)

	tween.tween_property(
		card,
		"scale",
		Vector2.ONE,
		drop_animation_duration
	)
	
	
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


func _update_hovered_card() -> void:
	if not enabled:
		_clear_hover()
		return

	var card: Card = raycast_check_for_card()

	if card == _last_hovered_card:
		return

	if _last_hovered_card != null:
		var previous_hand := (
			_last_hovered_card.get_parent()
			as Hand
		)

		if previous_hand != null:
			previous_hand.clear_hovered_card(
				_last_hovered_card
			)

	_last_hovered_card = card

	if card != null:
		var hand := card.get_parent() as Hand

		if hand != null:
			hand.set_hovered_card(card)


func _clear_hover() -> void:
	if _last_hovered_card == null:
		return

	var hand := (
		_last_hovered_card.get_parent()
		as Hand
	)

	if hand != null:
		hand.clear_hovered_card(
			_last_hovered_card
		)

	_last_hovered_card = null
	
	
func _update_dragged_card() -> void:
	if card_being_dragged == null:
		return

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)

	var card_position: Vector2 = (
		card_being_dragged.global_position
	)

	var weight: float = clamp(
		drag_follow_speed * get_process_delta_time(),
		0.0,
		1.0
	)

	card_being_dragged.global_position = (
		card_position.lerp(
			mouse_position,
			weight
		)
	)

	var mouse_delta: Vector2 = (
		mouse_position
		- _last_mouse_position
	)

	var desired_rotation: float = clamp(
		mouse_delta.x
		* drag_rotation_strength,
		deg_to_rad(-drag_max_rotation_degrees),
		deg_to_rad(drag_max_rotation_degrees)
	)

	card_being_dragged.rotation = lerp(
		card_being_dragged.rotation,
		desired_rotation,
		0.18
	)

	_last_mouse_position = mouse_position
