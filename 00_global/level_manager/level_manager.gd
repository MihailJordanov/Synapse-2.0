extends Node

signal level_unlocked(level_id: String)
signal level_defeated(level_id: String)
signal level_secret_changed(level_id: String, is_secret: bool)

const SAVE_PATH: String = "user://levels.json"
const DEFAULT_LEVEL: String = "A01"

var secret_levels: Array[String] = []
var unlocked_levels: Array[String] = []
var defeated_levels: Array[String] = []


func _ready() -> void:
	_load_levels()


func unlock_level(level_id: String) -> bool:
	level_id = _normalize_level_id(level_id)

	if level_id.is_empty() or unlocked_levels.has(level_id):
		return false

	unlocked_levels.append(level_id)
	_save_levels()
	level_unlocked.emit(level_id)

	return true


func defeat_level(level_id: String) -> bool:
	level_id = _normalize_level_id(level_id)

	if level_id.is_empty() or defeated_levels.has(level_id):
		return false

	var was_locked: bool = not unlocked_levels.has(level_id)

	if was_locked:
		unlocked_levels.append(level_id)

	defeated_levels.append(level_id)
	_save_levels()

	if was_locked:
		level_unlocked.emit(level_id)

	level_defeated.emit(level_id)

	return true


func set_level_secret(level_id: String, is_secret: bool = true) -> bool:
	level_id = _normalize_level_id(level_id)

	if level_id.is_empty():
		return false

	if is_secret:
		if secret_levels.has(level_id):
			return false

		secret_levels.append(level_id)
	else:
		if not secret_levels.has(level_id):
			return false

		secret_levels.erase(level_id)

	_save_levels()
	level_secret_changed.emit(level_id, is_secret)

	return true


func is_level_unlocked(level_id: String) -> bool:
	level_id = _normalize_level_id(level_id)
	return not level_id.is_empty() and unlocked_levels.has(level_id)


func is_level_defeated(level_id: String) -> bool:
	level_id = _normalize_level_id(level_id)
	return not level_id.is_empty() and defeated_levels.has(level_id)


func is_level_secret(level_id: String) -> bool:
	level_id = _normalize_level_id(level_id)
	return not level_id.is_empty() and secret_levels.has(level_id)


func get_level_status(level_id: String) -> Dictionary:
	level_id = _normalize_level_id(level_id)

	return {
		"secret": is_level_secret(level_id),
		"unlocked": is_level_unlocked(level_id),
		"defeated": is_level_defeated(level_id)
	}


func get_unlocked_levels(zone: String = "") -> Array[String]:
	return _get_levels_for_zone(unlocked_levels, zone)


func get_defeated_levels(zone: String = "") -> Array[String]:
	return _get_levels_for_zone(defeated_levels, zone)


func get_secret_levels(zone: String = "") -> Array[String]:
	return _get_levels_for_zone(secret_levels, zone)


func get_unlocked_count(zone: String = "") -> int:
	return get_unlocked_levels(zone).size()


func get_defeated_count(zone: String = "") -> int:
	return get_defeated_levels(zone).size()


func get_secret_count(zone: String = "") -> int:
	return get_secret_levels(zone).size()


func _get_levels_for_zone(levels: Array[String], zone: String) -> Array[String]:
	zone = zone.strip_edges().to_upper()

	if zone.is_empty():
		return levels.duplicate()

	if zone.length() != 1:
		return []

	var result: Array[String] = []

	for level_id in levels:
		if level_id.begins_with(zone):
			result.append(level_id)

	return result


func _load_levels() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_create_default_save()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		_create_default_save()
		return

	var data: Variant = JSON.parse_string(file.get_as_text())

	if not data is Dictionary:
		_create_default_save()
		return

	secret_levels = _read_level_array(data.get("secret", []))
	unlocked_levels = _read_level_array(data.get("unlocked", []))
	defeated_levels = _read_level_array(data.get("defeated", []))

	if not unlocked_levels.has(DEFAULT_LEVEL):
		unlocked_levels.append(DEFAULT_LEVEL)

	for level_id in defeated_levels:
		if not unlocked_levels.has(level_id):
			unlocked_levels.append(level_id)

	_save_levels()


func _read_level_array(data: Variant) -> Array[String]:
	var result: Array[String] = []

	if not data is Array:
		return result

	for value in data:
		var level_id: String = _normalize_level_id(str(value))

		if not level_id.is_empty() and not result.has(level_id):
			result.append(level_id)

	return result


func _save_levels() -> void:
	secret_levels.sort()
	unlocked_levels.sort()
	defeated_levels.sort()

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("LevelManager: Could not open the save file.")
		return

	var data: Dictionary = {
		"secret": secret_levels,
		"unlocked": unlocked_levels,
		"defeated": defeated_levels
	}

	file.store_string(JSON.stringify(data, "\t"))


func _create_default_save() -> void:
	secret_levels.clear()
	unlocked_levels = [DEFAULT_LEVEL]
	defeated_levels.clear()
	_save_levels()


func _normalize_level_id(level_id: String) -> String:
	level_id = level_id.strip_edges().to_upper()

	if level_id.length() < 3:
		return ""

	var zone: String = level_id.substr(0, 1)
	var number: String = level_id.substr(1)

	if zone < "A" or zone > "Z":
		return ""

	if number.length() < 2:
		return ""

	for character in number:
		if character < "0" or character > "9":
			return ""

	return level_id
