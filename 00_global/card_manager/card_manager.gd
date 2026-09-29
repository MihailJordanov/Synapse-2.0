extends Node


const UNIT_CARD_SCENE: PackedScene = preload("uid://3n4o4rhbvn11")
const SPELL_CARD_SCENE: PackedScene = preload("uid://v0yc3fbsaiwq")
const UNITS_DATA_PATH: String = "res://data/cards/units_cards.json"
const SPELLS_DATA_PATH: String = "res://data/cards/spell_cards.json"
const COLLECTION_SAVE_PATH: String = "user://card_collection.json"
const PLAYER_DECK_SAVE_PATH: String = "user://player_deck.json"

var _cards_database: Dictionary = {}
var _unit_collection: Dictionary = {}
var _spell_collection: Dictionary = {}
var _unit_deck: Array[int] = []
var _spell_deck: Array[int] = []


func _ready() -> void:
	_load_databases()
	_load_collection()
	_load_player_deck()


func is_card_in_collection(card_id: int) -> bool:
	return get_card_collection_count(card_id) > 0


func is_card_in_deck(card_id: int) -> bool:
	return get_card_deck_count(card_id) > 0
	

func add_card_to_collection(
	card_id: int,
	amount: int = 1
) -> bool:
	if not _cards_database.has(str(card_id)):
		push_warning(
			"CardManager: Unknown card %d."
			% card_id
		)
		return false

	if amount <= 0:
		return false

	var current_count: int = (
		get_card_collection_count(card_id)
	)

	var maximum_count: int = (
		get_max_card_copies_in_collection(card_id)
	)

	if current_count + amount > maximum_count:
		return false

	if _is_unit_card_id(card_id):
		_unit_collection[card_id] = (
			current_count + amount
		)

	elif _is_spell_card_id(card_id):
		_spell_collection[card_id] = (
			current_count + amount
		)

	else:
		return false

	_save_collection()
	return true
	
	
func add_card_to_deck(card_id: int) -> bool:
	if not can_add_card_to_deck(card_id):
		return false

	if _is_unit_card_id(card_id):
		_unit_deck.append(card_id)

	elif _is_spell_card_id(card_id):
		_spell_deck.append(card_id)

	else:
		return false

	_save_player_deck()
	return true
	
	


func get_unit_deck() -> Array[int]:
	return _unit_deck.duplicate()


func get_spell_deck() -> Array[int]:
	return _spell_deck.duplicate()


func get_unit_collection() -> Array[int]:
	return _get_collection_card_ids(
		_unit_collection
	)


func get_spell_collection() -> Array[int]:
	return _get_collection_card_ids(
		_spell_collection
	)



func _load_collection() -> void:
	if not FileAccess.file_exists(
		COLLECTION_SAVE_PATH
	):
		_create_default_collection()
		return

	var data: Variant = _read_save_file(
		COLLECTION_SAVE_PATH
	)

	if not data is Dictionary:
		_create_default_collection()
		return

	_unit_collection = _read_collection_counts(
		data.get("unit_cards", {}),
		true
	)

	_spell_collection = _read_collection_counts(
		data.get("spell_cards", {}),
		false
	)

	_save_collection()


func _load_player_deck() -> void:
	if not FileAccess.file_exists(PLAYER_DECK_SAVE_PATH):
		_create_default_player_deck()
		return

	var data: Variant = _read_save_file(PLAYER_DECK_SAVE_PATH)

	if not data is Dictionary:
		_create_default_player_deck()
		return

	_unit_deck = _read_deck_card_ids(data.get("unit_deck", []),true)
	_spell_deck = _read_deck_card_ids(data.get("spell_deck", []),false)
	_remove_deck_cards_outside_collection()
	_save_player_deck()


func _create_default_collection() -> void:
	_unit_collection.clear()
	_spell_collection.clear()

	for card_id: int in range(11000, 11010):
		if _cards_database.has(str(card_id)):
			_unit_collection[card_id] = 1

	_save_collection()


func _create_default_player_deck() -> void:
	_unit_deck.clear()
	_spell_deck.clear()

	for card_id in range(11000, 11010):
		_unit_deck.append(card_id)

	_save_player_deck()


func _save_collection() -> void:
	var data: Dictionary = {
		"unit_cards": _unit_collection,
		"spell_cards": _spell_collection
	}

	_write_save_file(COLLECTION_SAVE_PATH, data)


func _save_player_deck() -> void:
	var data: Dictionary = {
		"unit_deck": _unit_deck,
		"spell_deck": _spell_deck
	}

	_write_save_file(PLAYER_DECK_SAVE_PATH, data)


func _read_save_file(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("CardManager: Could not open save file: " + path)
		return null

	var data: Variant = JSON.parse_string(file.get_as_text())

	if data == null:
		push_error("CardManager: Invalid JSON in save file: " + path)

	return data


func _write_save_file(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("CardManager: Could not write save file: " + path)
		return

	file.store_string(JSON.stringify(data, "\t"))


func _read_card_ids(data: Variant, units: bool) -> Array[int]:
	var result: Array[int] = []

	if not data is Array:
		return result

	for value in data:
		var card_id: int = int(value)
		var is_correct_type: bool = _is_unit_card_id(card_id) if units else _is_spell_card_id(card_id)

		if is_correct_type and not result.has(card_id):
			result.append(card_id)

	return result


func _remove_deck_cards_outside_collection() -> void:
	_unit_deck = _sanitize_deck(
		_unit_deck,
		true
	)

	_spell_deck = _sanitize_deck(
		_spell_deck,
		false
	)
	
func _sanitize_deck(
	deck: Array[int],
	units: bool
) -> Array[int]:
	var result: Array[int] = []
	var used_counts: Dictionary = {}

	for card_id: int in deck:
		if not _is_correct_card_type(
			card_id,
			units
		):
			continue

		var owned_count: int = (
			get_card_collection_count(card_id)
		)

		var maximum_in_deck: int = (
			get_max_card_copies_in_deck(card_id)
		)

		var allowed_count: int = mini(
			owned_count,
			maximum_in_deck
		)

		var current_count: int = int(
			used_counts.get(card_id, 0)
		)

		if current_count >= allowed_count:
			continue

		result.append(card_id)
		used_counts[card_id] = current_count + 1

	return result


func _load_databases() -> void:
	_cards_database.clear()

	_load_database_file(UNITS_DATA_PATH)
	_load_database_file(SPELLS_DATA_PATH)

func _load_database_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error(
			"CardManager: File not found at path: %s"
			% path
		)
		return

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error(
			"CardManager: Could not open file: %s"
			% path
		)
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: Error = json.parse(json_string)

	if error != OK:
		push_error(
			"CardManager: Error parsing %s at line %d: %s"
			% [
				path,
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return

	if not json.data is Dictionary:
		push_error(
			"CardManager: Root JSON value must be a Dictionary: %s"
			% path
		)
		return

	var loaded_cards := json.data as Dictionary

	for id: Variant in loaded_cards:
		var string_id := str(id)

		if _cards_database.has(string_id):
			push_warning(
				"CardManager: Duplicate card ID %s in %s."
				% [string_id, path]
			)

		_cards_database[string_id] = loaded_cards[id]


func get_unit_card_data(card_id: int) -> Dictionary:
	if not _is_unit_card_id(card_id):
		return {}

	var data: Variant = _cards_database.get(str(card_id))

	if not data is Dictionary:
		return {}

	return (data as Dictionary).duplicate(true)


func create_card_by_id(card_id: int) -> Card:
	var string_id := str(card_id)

	if not _cards_database.has(string_id):
		push_warning(
			"CardManager: Card with ID %d does not exist."
			% card_id
		)
		return null

	var card_data: Variant = _cards_database[string_id]

	if not card_data is Dictionary:
		push_error(
			"CardManager: Invalid data for card %d."
			% card_id
		)
		return null

	var data := card_data as Dictionary
	var new_card: Card

	if _is_unit_card_id(card_id):
		new_card = _create_unit_card(data)

	elif _is_spell_card_id(card_id):
		new_card = _create_spell_card(data)

	else:
		push_error(
			"CardManager: Unsupported card ID range: %d"
			% card_id
		)
		return null

	if new_card == null:
		return null

	new_card.card_id = card_id
	_apply_common_card_data(new_card, data)

	return new_card


func _create_unit_card(data: Dictionary) -> UnitCard:
	var unit_card := UNIT_CARD_SCENE.instantiate() as UnitCard

	if unit_card == null:
		push_error(
			"CardManager: Could not instantiate UnitCard."
		)
		return null

	var target_types: Array[int] = []
	target_types.assign(
		data.get("target_types", [])
	)

	var source_types: Array[int] = []
	source_types.assign(
		data.get("source_types", [])
	)

	unit_card.set_all_types(
		target_types,
		source_types
	)

	unit_card.set_points(
		int(data.get("points", 1))
	)

	return unit_card


func _create_spell_card(data: Dictionary) -> SpellCard:
	var spell_card := SPELL_CARD_SCENE.instantiate() as SpellCard

	if spell_card == null:
		push_error(
			"CardManager: Could not instantiate SpellCard."
		)
		return null

	var target_mode_string := str(
		data.get("target_mode", "no_target")
	)

	var effect_type := str(
		data.get("effect_type", "")
	)

	var requirement_type := str(
		data.get("requirement_type", "none")
	).to_lower()

	var target_mode := _parse_target_mode(
		target_mode_string
	)

	var effect := _create_spell_effect(
		effect_type,
		data
	)

	if effect == null:
		spell_card.queue_free()
		return null

	var requirement := _create_spell_requirement(
		requirement_type
	)

	if requirement_type != "none" and requirement == null:
		spell_card.queue_free()
		return null

	spell_card.setup(target_mode,effect,requirement)
	spell_card.set_mana_cost(int(data.get("mana_cost", 0)))
	spell_card.set_description(str(data.get("description", "")))

	return spell_card
	
	
func _create_spell_effect(effect_type: String,data: Dictionary) -> SpellEffect:
	match effect_type.to_lower():
		"add_points":
			return AddPointSpellEffect.new(
				int(data.get("effect_amount", 0)))

		"remove_points":
			return RemovePointSpellEffect.new(int(data.get("effect_amount", 0)))
			
		"modify_connection_type":
			return _create_modify_connection_type_effect(data)
			
		"swap_target_source_types":
			return SwapTargetSourceTypesSpellEffect.new()
			
		"steal_enemy_unit":
			return StealEnemyUnitSpellEffect.new()
		_:
			push_error(
				"CardManager: Unsupported spell effect '%s'."
				% effect_type
			)
			return null


func _parse_target_mode(value: String) -> SpellCard.TargetMode:
	match value.to_lower():
		"no_target":
			return SpellCard.TargetMode.NO_TARGET

		"any_unit":
			return SpellCard.TargetMode.ANY_UNIT

		"friendly_unit":
			return SpellCard.TargetMode.FRIENDLY_UNIT

		"enemy_unit":
			return SpellCard.TargetMode.ENEMY_UNIT

		_:
			push_warning(
				"CardManager: Unknown target mode '%s'. Using NO_TARGET."
				% value
			)

			return SpellCard.TargetMode.NO_TARGET


func _apply_common_card_data(card: Card,data: Dictionary) -> void:

	_apply_card_texture(card, data)


func _is_unit_card_id(card_id: int) -> bool:
	return card_id >= 11000 and card_id <= 11999


func _is_spell_card_id(card_id: int) -> bool:
	return card_id >= 21000 and card_id <= 21999
	

func _apply_card_texture(card: Card,data: Dictionary) -> void:
	var texture_path := str(
		data.get("texture_path", "")
	)

	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		push_warning(
			"CardManager: Texture does not exist: %s"
			% texture_path
		)
		return

	var texture := load(texture_path) as Texture2D

	if texture == null:
		push_warning(
			"CardManager: Resource is not a Texture2D: %s"
			% texture_path
		)
		return

	var card_texture := card.get_node_or_null("%CardTexture") as TextureRect

	if card_texture:
		card_texture.texture = texture
		return


	push_warning(
		"CardManager: Card %d has no supported texture node."
		% card.card_id
	)


func _create_spell_requirement(requirement_type: String) -> SpellRequirement:
	match requirement_type.to_lower():
		"none":
			return null

		"has_any_unit":
			return HasAnyUnitRequirement.new()

		"has_friendly_unit":
			return HasFriendlyUnitRequirement.new()

		"has_enemy_unit":
			return HasEnemyUnitRequirement.new()

		_:
			push_error(
				"CardManager: Unsupported spell requirement '%s'."
				% requirement_type
			)
			return null


func _create_modify_connection_type_effect(
	data: Dictionary
) -> SpellEffect:
	var connection_type_string := str(
		data.get("connection_type", "")
	).to_lower()

	var operation_string := str(
		data.get("operation", "")
	).to_lower()

	var type_number := int(
		data.get("type_number", 0)
	)

	if type_number < 1 or type_number > UnitCard.MAX_TYPES_COUNT:
		push_error(
			"CardManager: Invalid type_number %d."
			% type_number
		)
		return null


	var connection_type: ModifyConnectionTypeSpellEffect.ConnectionType

	match connection_type_string:
		"target":
			connection_type = (
				ModifyConnectionTypeSpellEffect
				.ConnectionType
				.TARGET
			)

		"source":
			connection_type = (
				ModifyConnectionTypeSpellEffect
				.ConnectionType
				.SOURCE
			)

		_:
			push_error(
				"CardManager: Invalid connection_type '%s'."
				% connection_type_string
			)
			return null


	var operation: ModifyConnectionTypeSpellEffect.Operation

	match operation_string:
		"add":
			operation = (
				ModifyConnectionTypeSpellEffect
				.Operation
				.ADD
			)

		"remove":
			operation = (
				ModifyConnectionTypeSpellEffect
				.Operation
				.REMOVE
			)

		_:
			push_error(
				"CardManager: Invalid operation '%s'."
				% operation_string
			)
			return null


	return ModifyConnectionTypeSpellEffect.new(
		connection_type,
		operation,
		type_number
	)
	
func remove_card_from_deck(card_id: int) -> bool:
	if _is_unit_card_id(card_id):
		if not _unit_deck.has(card_id):
			return false

		_unit_deck.erase(card_id)

	elif _is_spell_card_id(card_id):
		if not _spell_deck.has(card_id):
			return false

		_spell_deck.erase(card_id)

	else:
		return false

	_save_player_deck()
	return true


func get_spell_card_data(card_id: int) -> Dictionary:
	if not _is_spell_card_id(card_id):
		return {}

	var data: Variant = _cards_database.get(str(card_id))

	if not data is Dictionary:
		return {}

	return (data as Dictionary).duplicate(true)


func get_unit_deck_total_points() -> int:
	var total_points: int = 0

	for card_id: int in _unit_deck:
		var card_data: Dictionary = get_unit_card_data(card_id)

		if card_data.is_empty():
			continue

		total_points += int(card_data.get("points", 0))

	return total_points


func get_spell_deck_average_mana() -> float:
	if _spell_deck.is_empty():
		return 0.0

	var total_mana: int = 0
	var valid_spell_count: int = 0

	for card_id: int in _spell_deck:
		var card_data: Dictionary = get_spell_card_data(card_id)

		if card_data.is_empty():
			continue

		total_mana += maxi(
			int(card_data.get("mana_cost", 0)),
			0
		)

		valid_spell_count += 1

	if valid_spell_count == 0:
		return 0.0

	return snappedf(
		float(total_mana) / float(valid_spell_count),
		0.1
	)

func get_card_collection_count(card_id: int) -> int:
	if _is_unit_card_id(card_id):
		return int(_unit_collection.get(card_id, 0))

	if _is_spell_card_id(card_id):
		return int(_spell_collection.get(card_id, 0))

	return 0


func get_card_deck_count(card_id: int) -> int:
	if _is_unit_card_id(card_id):
		return _unit_deck.count(card_id)

	if _is_spell_card_id(card_id):
		return _spell_deck.count(card_id)

	return 0
	
	
func get_max_card_copies_in_deck(card_id: int) -> int:
	var card_data: Dictionary = get_card_data(card_id)

	if card_data.is_empty():
		return 0

	return maxi(
		int(card_data.get("max_copies_in_deck", 1)),
		0
	)


func get_max_card_copies_in_collection(card_id: int) -> int:
	var card_data: Dictionary = get_card_data(card_id)

	if card_data.is_empty():
		return 0

	return maxi(
		int(card_data.get(
			"max_copies_in_collection",
			999
		)),
		0
	)
	
func get_card_data(card_id: int) -> Dictionary:
	var data: Variant = _cards_database.get(
		str(card_id)
	)

	if not data is Dictionary:
		return {}

	return (data as Dictionary).duplicate(true)
	
	
func get_card_available_deck_copies(
	card_id: int
) -> int:
	var owned_count: int = (
		get_card_collection_count(card_id)
	)

	var deck_count: int = (
		get_card_deck_count(card_id)
	)

	var maximum_in_deck: int = (
		get_max_card_copies_in_deck(card_id)
	)

	return maxi(
		mini(
			owned_count,
			maximum_in_deck
		) - deck_count,
		0
	)
	
func can_add_card_to_deck(card_id: int) -> bool:
	if not is_card_in_collection(card_id):
		return false

	return (
		get_card_available_deck_copies(card_id) > 0
	)


func can_remove_card_from_deck(
	card_id: int
) -> bool:
	return get_card_deck_count(card_id) > 0
	
func remove_card_from_collection(
	card_id: int,
	amount: int = 1
) -> bool:
	if amount <= 0:
		return false

	var current_count: int = (
		get_card_collection_count(card_id)
	)

	var new_count: int = current_count - amount

	if new_count < 0:
		return false

	if new_count < get_card_deck_count(card_id):
		push_warning(
			"CardManager: Cannot remove deck-bound copies of card %d."
			% card_id
		)
		return false

	if _is_unit_card_id(card_id):
		if new_count == 0:
			_unit_collection.erase(card_id)
		else:
			_unit_collection[card_id] = new_count

	elif _is_spell_card_id(card_id):
		if new_count == 0:
			_spell_collection.erase(card_id)
		else:
			_spell_collection[card_id] = new_count

	else:
		return false

	_save_collection()
	return true
	

func _get_collection_card_ids(
	collection: Dictionary
) -> Array[int]:
	var result: Array[int] = []

	for value: Variant in collection.keys():
		var card_id: int = int(value)

		if int(collection[value]) > 0:
			result.append(card_id)

	result.sort()
	return result
	
	
func _read_collection_counts(
	data: Variant,
	units: bool
) -> Dictionary:
	var result: Dictionary = {}

	if data is Dictionary:
		for id_value: Variant in data:
			var card_id: int = int(id_value)
			var count: int = maxi(
				int(data[id_value]),
				0
			)

			if not _is_correct_card_type(
				card_id,
				units
			):
				continue

			if not _cards_database.has(str(card_id)):
				continue

			var maximum: int = (
				get_max_card_copies_in_collection(
					card_id
				)
			)

			count = mini(count, maximum)

			if count > 0:
				result[card_id] = count

		return result

	if data is Array:
		for value: Variant in data:
			var card_id: int = int(value)

			if not _is_correct_card_type(
				card_id,
				units
			):
				continue

			if not _cards_database.has(str(card_id)):
				continue

			result[card_id] = (
				int(result.get(card_id, 0)) + 1
			)

	return result
	
	
func _is_correct_card_type(
	card_id: int,
	units: bool
) -> bool:
	if units:
		return _is_unit_card_id(card_id)

	return _is_spell_card_id(card_id)
	
	
func _read_deck_card_ids(
	data: Variant,
	units: bool
) -> Array[int]:
	var result: Array[int] = []

	if not data is Array:
		return result

	for value: Variant in data:
		var card_id: int = int(value)

		if not _is_correct_card_type(
			card_id,
			units
		):
			continue

		if not _cards_database.has(str(card_id)):
			continue

		result.append(card_id)

	return result
