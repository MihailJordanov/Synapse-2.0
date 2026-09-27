extends Node


signal legend_unlocked(legend_id: int)
signal equipped_legend_changed(legend_id: int)


const LEGENDS_DATA_PATH: String = "res://data/legends/legends.json"



const LEGEND_COLLECTION_SAVE_PATH: String = "user://legend_collection.json"



const MIN_LEGEND_ID: int = 31000
const MAX_LEGEND_ID: int = 31999


var _legends_database: Dictionary = {}
var _unlocked_legends: Array[int] = []
var _equipped_legend_id: int = 0


func _ready() -> void:
	_load_legends_database()
	_load_legend_collection()
	
	
func _load_legends_database() -> void:
	_legends_database.clear()

	if not FileAccess.file_exists(LEGENDS_DATA_PATH):
		push_error(
			"LegendManager: File not found: %s"
			% LEGENDS_DATA_PATH
		)
		return

	var file := FileAccess.open(
		LEGENDS_DATA_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"LegendManager: Could not open: %s"
			% LEGENDS_DATA_PATH
		)
		return

	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error(
			"LegendManager: JSON error at line %d: %s"
			% [
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return

	if not json.data is Dictionary:
		push_error(
			"LegendManager: Database root must be a Dictionary."
		)
		return

	var database_data := json.data as Dictionary

	for id_value: Variant in database_data:
		var legend_id: int = int(id_value)
		var entry: Variant = database_data[id_value]

		if not _is_valid_legend_id(legend_id):
			push_warning(
				"LegendManager: Invalid legend ID %d."
				% legend_id
			)
			continue

		if not entry is Dictionary:
			continue

		var resource_path: String = str(
			(entry as Dictionary).get(
				"resource_path",
				""
			)
		)

		if resource_path.is_empty():
			continue

		if not ResourceLoader.exists(resource_path):
			push_warning(
				"LegendManager: Resource does not exist: %s"
				% resource_path
			)
			continue

		var legend := ResourceLoader.load(
			resource_path
		) as Legend

		if legend == null:
			push_warning(
				"LegendManager: Invalid Legend resource: %s"
				% resource_path
			)
			continue

		if legend.legend_id != legend_id:
			push_warning(
				"LegendManager: ID mismatch for %s."
				% resource_path
			)
			continue

		_legends_database[legend_id] = legend
		
		
func _load_legend_collection() -> void:
	if not FileAccess.file_exists(
		LEGEND_COLLECTION_SAVE_PATH
	):
		_create_default_legend_collection()
		return

	var file := FileAccess.open(
		LEGEND_COLLECTION_SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		_create_default_legend_collection()
		return

	var data: Variant = JSON.parse_string(
		file.get_as_text()
	)

	file.close()

	if not data is Dictionary:
		_create_default_legend_collection()
		return

	var save_data := data as Dictionary

	_unlocked_legends = _read_legend_ids(
		save_data.get("unlocked_legends", [])
	)

	_equipped_legend_id = int(
		save_data.get("equipped_legend", 0)
	)

	if not _unlocked_legends.has(
		_equipped_legend_id
	):
		_equipped_legend_id = 0

	_save_legend_collection()
	
	
func _create_default_legend_collection() -> void:
	_unlocked_legends.clear()
	_equipped_legend_id = 0
	_save_legend_collection()
	
	
func _save_legend_collection() -> void:
	var file := FileAccess.open(
		LEGEND_COLLECTION_SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"LegendManager: Could not save collection."
		)
		return

	var data: Dictionary = {
		"unlocked_legends": _unlocked_legends,
		"equipped_legend": _equipped_legend_id
	}

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	
	
func _read_legend_ids(data: Variant) -> Array[int]:
	var result: Array[int] = []

	if not data is Array:
		return result

	for value: Variant in data:
		var legend_id: int = int(value)

		if not _legends_database.has(legend_id):
			continue

		if result.has(legend_id):
			continue

		result.append(legend_id)

	return result


func _is_valid_legend_id(legend_id: int) -> bool:
	return (
		legend_id >= MIN_LEGEND_ID
		and legend_id <= MAX_LEGEND_ID
	)
	
func has_legend(legend_id: int) -> bool:
	return _legends_database.has(legend_id)


func get_legend(legend_id: int) -> Legend:
	return _legends_database.get(legend_id) as Legend


func get_unlocked_legend_ids() -> Array[int]:
	return _unlocked_legends.duplicate()


func get_unlocked_legends() -> Array[Legend]:
	var result: Array[Legend] = []

	for legend_id: int in _unlocked_legends:
		var legend: Legend = get_legend(legend_id)

		if legend:
			result.append(legend)

	return result


func is_legend_unlocked(legend_id: int) -> bool:
	return _unlocked_legends.has(legend_id)


func unlock_legend(legend_id: int) -> bool:
	if not _legends_database.has(legend_id):
		push_warning(
			"LegendManager: Unknown legend ID %d."
			% legend_id
		)
		return false

	if _unlocked_legends.has(legend_id):
		return false

	_unlocked_legends.append(legend_id)
	_save_legend_collection()

	legend_unlocked.emit(legend_id)
	return true
	
	
func equip_legend(legend_id: int) -> bool:
	if not _unlocked_legends.has(legend_id):
		push_warning(
			"LegendManager: Legend %d is not unlocked."
			% legend_id
		)
		return false

	if _equipped_legend_id == legend_id:
		return false

	_equipped_legend_id = legend_id
	_save_legend_collection()

	equipped_legend_changed.emit(legend_id)
	return true


func unequip_legend() -> bool:
	if _equipped_legend_id == 0:
		return false

	_equipped_legend_id = 0
	_save_legend_collection()

	equipped_legend_changed.emit(0)
	return true
	
func get_equipped_legend_id() -> int:
	return _equipped_legend_id


func get_equipped_legend() -> Legend:
	return get_legend(_equipped_legend_id)
	
func create_equipped_legend_instance() -> Legend:
	var legend: Legend = get_equipped_legend()

	if legend == null:
		return null

	return legend.duplicate(true) as Legend
