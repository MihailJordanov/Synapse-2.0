extends Node


const UNIT_CARD_SCENE: PackedScene = preload("uid://3n4o4rhbvn11")
const SPELL_CARD_SCENE: PackedScene = preload("uid://v0yc3fbsaiwq")
const UNITS_DATA_PATH: String = "res://data/cards/units_cards.json"
const SPELLS_DATA_PATH: String = "res://data/cards/spell_cards.json"

var _cards_database: Dictionary = {}


func _ready() -> void:
	_load_databases()

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
