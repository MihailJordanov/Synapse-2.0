extends Node

const UNIT_CARD_SCENE: PackedScene = preload("uid://3n4o4rhbvn11")
const UNITS_DATA_PATH: String = "res://data/cards/units_cards.json"
var _cards_database: Dictionary = {}


func _ready() -> void:
	_load_database()


func _load_database() -> void:
	if not FileAccess.file_exists(UNITS_DATA_PATH):
		push_error("SaveManager: File not found at path:" + UNITS_DATA_PATH)
		return
		
	var file = FileAccess.open(UNITS_DATA_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		_cards_database = json.data
	else:
			push_error("SaveManager: Error parsing JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])


func create_card_by_id(card_id: int) -> Card:
	var str_id: String = str(card_id)
	
	if not _cards_database.has(str_id):
		push_warning("SaveManager: Card with ID %d does not exist in the database!" % card_id)
		return null
		
	var card_data: Dictionary = _cards_database[str_id]
	var new_card: Card = null
	
	if str_id.begins_with("1"):
		var unit_card = UNIT_CARD_SCENE.instantiate() as UnitCard
		if unit_card:
			var target_types: Array[int] = []
			target_types.assign(card_data.get("target_types", []))
			
			var source_types: Array[int] = []
			source_types.assign(card_data.get("source_types", []))
			
			unit_card.set_all_types(target_types, source_types)
			unit_card.set_points(card_data.get("points", 1))
			
			new_card = unit_card
			
	# Тук в бъдеще може да добавя else if str_id.begins_with("2"): за SpellCard!

	return new_card
