class_name Hand
extends Node2D

signal deck_changed

@export_category("General")
@export var height: float = 0.0
@export var is_enemy: bool = false
@export var deck_sprite: Sprite2D

@export_category("Layout")
@export var preferred_card_spacing: float = 150.0
@export var minimum_card_spacing: float = 38.0
@export var max_hand_width: float = 850.0

@export var max_arc_angle: float = 12.0
@export var arc_height_offset: float = 30.0

@export_category("Animation")
@export var animation_duration: float = 0.22
@export var animation_ease: Tween.EaseType = Tween.EASE_OUT
@export var animation_transition: Tween.TransitionType = Tween.TRANS_QUAD

@export_category("Hover")
@export var hover_scale: float = 1.3
@export var hover_raise: float = 170.0
@export var hover_neighbor_push: float = 45.0
@export var hover_neighbor_falloff: float = 0.55

@export_category("Debug")
@export var debug_draw_with_space: bool = true


var cards_in_hand: Array[Card] = []
var deck: Array[Card] = []

var hovered_card: Card = null
var dragged_card: Card = null

var _card_tweens: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if not debug_draw_with_space:
		return

	if is_enemy:
		return

	if event is InputEventKey:
		if (
			event.pressed
			and not event.is_echo()
			and event.keycode == KEY_SPACE
		):
			draw_card()


func setup_deck(source_cards: Array) -> void:
	clear_hand_and_deck()

	for item in source_cards:
		var card := item as Card

		if card == null:
			continue

		card.is_enemy_card = is_enemy
		card.is_card_hide = is_enemy

		deck.append(card)

	deck.shuffle()


func draw_card() -> Card:
	if deck.is_empty():
		return null

	var card: Card = deck[0]
	deck.remove_at(0)

	if not is_instance_valid(card):
		push_error(
			"Hand.draw_card: Invalid card in deck."
		)
		return null

	deck_changed.emit()

	add_existing_card(card)

	return card


func add_existing_card(card: Card) -> void:
	if card == null:
		return

	if cards_in_hand.has(card):
		return

	cards_in_hand.append(card)

	card.is_enemy_card = is_enemy
	card.is_card_hide = is_enemy

	if card.get_parent() == null:
		add_child(card)

	elif card.get_parent() != self:
		card.reparent(self, true)

	if deck_sprite != null:
		card.global_position = deck_sprite.global_position
		card.global_rotation = deck_sprite.global_rotation

	card.scale = Vector2.ONE

	rearrange_hand()


func remove_card(card: Card) -> bool:
	if not cards_in_hand.has(card):
		return false

	cards_in_hand.erase(card)

	if hovered_card == card:
		hovered_card = null

	if dragged_card == card:
		dragged_card = null

	_cancel_card_tween(card)

	rearrange_hand()

	return true


# ---------------------------------------------------------
# Hover
# ---------------------------------------------------------

func set_hovered_card(card: Card) -> void:
	if is_enemy:
		return

	if hovered_card == card:
		return

	if card != null and not cards_in_hand.has(card):
		card = null

	hovered_card = card

	rearrange_hand()


func clear_hovered_card(card: Card = null) -> void:
	if card != null and hovered_card != card:
		return

	if hovered_card == null:
		return

	hovered_card = null

	rearrange_hand()


# ---------------------------------------------------------
# Drag
# ---------------------------------------------------------

func begin_drag(card: Card) -> void:
	if card == null:
		return

	dragged_card = card

	if hovered_card == card:
		hovered_card = null

	_cancel_card_tween(card)

	# Rearrange the remaining hand around the temporary gap.
	rearrange_hand()


func end_drag(card: Card) -> void:
	if dragged_card != card:
		return

	dragged_card = null

	rearrange_hand()


# ---------------------------------------------------------
# Layout
# ---------------------------------------------------------

func rearrange_hand() -> void:
	var size: int = cards_in_hand.size()

	if size == 0:
		return

	var spacing: float = _calculate_spacing(size)

	var total_width: float = float(size - 1) * spacing
	var start_x: float = -total_width * 0.5

	var center_index: float = float(size - 1) * 0.5

	for i: int in range(size):
		var card: Card = cards_in_hand[i]

		if not is_instance_valid(card):
			continue

		if card == dragged_card:
			continue

		_cancel_card_tween(card)

		var normalized: float = 0.0

		if center_index > 0.0:
			normalized = (
				float(i) - center_index
			) / center_index

		var local_x: float = (
			start_x
			+ float(i) * spacing
		)

		var curve_y: float = (
			-pow(normalized, 2.0)
			* arc_height_offset
		)

		var local_y: float = height + curve_y

		var target_rotation: float = (
			normalized
			* deg_to_rad(max_arc_angle)
		)

		var target_scale := Vector2.ONE

		# -------------------------------------------
		# Hover interaction
		# -------------------------------------------

		if hovered_card != null:
			var hovered_index: int = (
				cards_in_hand.find(hovered_card)
			)

			if hovered_index >= 0:
				var distance: int = i - hovered_index

				if card == hovered_card:
					target_scale = Vector2.ONE * hover_scale

					if is_enemy:
						local_y += hover_raise
					else:
						local_y -= hover_raise

					target_rotation = (
						PI if is_enemy else 0.0
					)

				else:
					local_x += _calculate_hover_push(
						distance
					)

		if is_enemy:
			local_x = -local_x
			local_y = height - curve_y

			target_rotation = (
				-target_rotation + PI
			)

		var target_position: Vector2 = to_global(
			Vector2(
				local_x,
				local_y
			)
		)

		_animate_card(
			card,
			target_position,
			target_rotation,
			target_scale
		)

		_update_z_index(card, i)


func _calculate_spacing(card_count: int) -> float:
	if card_count <= 1:
		return preferred_card_spacing

	var required_width: float = (
		float(card_count - 1)
		* preferred_card_spacing
	)

	if required_width <= max_hand_width:
		return preferred_card_spacing

	var compressed_spacing: float = (
		max_hand_width
		/ float(card_count - 1)
	)

	return max(
		minimum_card_spacing,
		compressed_spacing
	)


func _calculate_hover_push(distance: int) -> float:
	if distance == 0:
		return 0.0

	var abs_distance: int = abs(distance)

	var amount: float = (
		hover_neighbor_push
		* pow(
			hover_neighbor_falloff,
			float(abs_distance - 1)
		)
	)

	if distance < 0:
		return -amount

	return amount


func _update_z_index(card: Card,index: int) -> void:
	if card.current_slot != null:
		card.z_as_relative = true
		card.z_index = 1
		return

	card.z_as_relative = true

	if card == hovered_card:
		card.z_index = 500
	else:
		card.z_index = 10 + index


func _animate_card(
	card: Card,
	target_position: Vector2,
	target_rotation: float,
	target_scale: Vector2
) -> void:
	var tween: Tween = card.create_tween()

	tween.set_parallel(true)

	tween.set_ease(animation_ease)
	tween.set_trans(animation_transition)

	_card_tweens[
		card.get_instance_id()
	] = tween

	tween.tween_property(
		card,
		"global_position",
		target_position,
		animation_duration
	)

	tween.tween_property(
		card,
		"rotation",
		target_rotation,
		animation_duration
	)

	tween.tween_property(
		card,
		"scale",
		target_scale,
		animation_duration
	)


func _cancel_card_tween(card: Card) -> void:
	if card == null:
		return

	var id: int = card.get_instance_id()

	if not _card_tweens.has(id):
		return

	var tween := _card_tweens[id] as Tween

	if tween != null and tween.is_valid():
		tween.kill()

	_card_tweens.erase(id)


func clear_hand_and_deck() -> void:
	for card: Card in cards_in_hand + deck:
		if (
			is_instance_valid(card)
			and card.get_parent() != null
		):
			card.get_parent().remove_child(card)

	cards_in_hand.clear()
	deck.clear()

	hovered_card = null
	dragged_card = null

	_card_tweens.clear()


func set_deck(new_deck: Array[Card]) -> void:
	deck = new_deck
	deck_changed.emit()


func get_deck_size() -> int:
	return deck.size()
