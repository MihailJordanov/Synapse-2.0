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
	card.position = Vector2.ZERO
	card.rotation = 0.0
	card.z_index = 0
	card.z_as_relative = true
	card.current_slot = self
	current_card = card
	card_in_slot = true
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
