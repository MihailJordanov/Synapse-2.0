@icon("res://resources/icons/empty_slot.svg")
class_name CardSlot extends Node2D

@export var is_enemy_slot: bool = false

var card_in_slot: bool = false
var current_card: Card = null


func place_card(card: Card) -> bool:
	if card == null or card_in_slot:
		return false

	if card.is_enemy_card != is_enemy_slot:
		return false

	if card.get_parent() == null:
		add_child(card)
	elif card.get_parent() != self:
		card.reparent(self, true)

	card.current_slot = self

	current_card = card
	card_in_slot = true

	card.z_as_relative = true
	card.z_index = 2

	_animate_card_into_slot(card)

	return true

func clear_slot(detach_card: bool = true) -> Card:
	var old_card := current_card
	card_in_slot = false
	current_card = null
	if old_card:
		old_card.current_slot = null
		if detach_card and old_card.get_parent() == self:
			remove_child(old_card)
	return old_card

func _animate_card_into_slot(card: Card) -> void:
	var tween: Tween = card.create_tween()

	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(
		card,
		"position",
		Vector2.ZERO,
		0.22
	)

	tween.tween_property(
		card,
		"rotation",
		0.0,
		0.22
	)

	tween.tween_property(
		card,
		"scale",
		Vector2.ONE,
		0.22
	)

func remove_card_reference(card: Card) -> void:
	if current_card != card:
		return

	current_card = null
	card_in_slot = false

	if card.current_slot == self:
		card.current_slot = null
