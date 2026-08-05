@icon( "res://resources/icons/controller.svg" )
class_name LevelController extends Node

var player_deck: Array[Node2D] = []
var enemy_deck: Array[Node2D] = []


func _ready() -> void:
	_generate_decks()


func _generate_decks() -> void:
	var player_card_ids: Array[int] = [11000, 21000, 11002, 11003, 11004, 21000, 11006, 11007, 11008, 11009]
	var enemy_card_ids: Array[int] = [11009, 11008, 11007, 11006, 11005, 11004, 11003, 11002, 11001, 11000]

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
