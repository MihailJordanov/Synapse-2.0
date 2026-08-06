class_name CardPlayContext
extends RefCounted


var caster_side: int
var board_cards: Array[Card] = []
var empty_slots: Array[CardSlot] = []
var available_mana: int = 0


func _init(
	new_caster_side: int,
	new_board_cards: Array[Card],
	new_empty_slots: Array[CardSlot] = [],
	new_available_mana: int = 0
) -> void:
	caster_side = new_caster_side
	board_cards = new_board_cards
	empty_slots = new_empty_slots
	available_mana = maxi(new_available_mana, 0)
