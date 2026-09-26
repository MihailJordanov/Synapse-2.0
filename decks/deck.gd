class_name Deck
extends Resource

@export var deck_name: String = "New Deck"
@export var unit_card_ids: Array[String] = []
@export var spell_card_ids: Array[String] = []


func get_unit_card_ids() -> Array[String]:
	return unit_card_ids.duplicate()


func get_spell_card_ids() -> Array[String]:
	return spell_card_ids.duplicate()


func get_unit_count() -> int:
	return unit_card_ids.size()


func get_spell_count() -> int:
	return spell_card_ids.size()


func get_total_card_count() -> int:
	return unit_card_ids.size() + spell_card_ids.size()


func get_all_card_ids() -> Array[String]:
	var all_card_ids: Array[String] = unit_card_ids.duplicate()
	all_card_ids.append_array(spell_card_ids)
	return all_card_ids
