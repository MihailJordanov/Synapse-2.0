@icon( "res://resources/icons/controller.svg" )
class_name LevelController extends Node

var player_deck: Array[Node2D] = []
var enemy_deck: Array[Node2D] = []


func _ready() -> void:
	_generate_decks()


func _generate_decks() -> void:
	var player_card_ids: Array[int] = [21002, 11008, 21001, 11003, 21002, 21000, 21001, 11007, 11008, 11009]
	var enemy_card_ids: Array[int] = [11009, 21002, 11007, 21001, 11005, 21000, 11003, 21000, 11001, 21001]

	#var player_card_ids: Array[int] = [21001, 21001, 21001, 21001, 21001, 21001, 21001, 21001, 21001, 21001]
	#var enemy_card_ids: Array[int] = [21001, 21001, 21001, 21001, 21001, 21001, 21001, 21001, 21001, 21001]
	
	#var player_card_ids: Array[int] = [11000,11000,11000,11000,11000,11000,11000,11000,11000,11000,11000,1100011000,11000,11000]
	#var enemy_card_ids: Array[int] = [11000,11000,11000,11000,11000,11000,11000,11000,11000,11000,11000,1100011000,11000,11000]
		
	for card_id in player_card_ids:
		var card = CardManager.create_card_by_id(card_id)
		if card:
			player_deck.append(card)

	for card_id in enemy_card_ids:
		var card = CardManager.create_card_by_id(card_id)
		if card:
			enemy_deck.append(card)
