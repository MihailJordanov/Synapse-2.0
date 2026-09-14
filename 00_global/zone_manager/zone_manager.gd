extends Node

signal zone_unlocked(zone: String)

const SAVE_PATH: String = "user://unlocked_zones.json"
const DEFAULT_ZONE: String = "A"

var unlocked_zones: Array[String] = []


func _ready() -> void:
	_load_zones()


func unlock_zone(zone: String) -> bool:
	zone = _normalize_zone(zone)

	if zone.is_empty() or unlocked_zones.has(zone):
		return false

	unlocked_zones.append(zone)
	_save_zones()
	zone_unlocked.emit(zone)

	return true


func is_zone_unlocked(zone: String) -> bool:
	zone = _normalize_zone(zone)
	return unlocked_zones.has(zone)


func _load_zones() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		unlocked_zones = [DEFAULT_ZONE]
		_save_zones()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		_create_default_save()
		return

	var data: Variant = JSON.parse_string(file.get_as_text())

	if not data is Dictionary or not data.has("unlocked_zones") or not data["unlocked_zones"] is Array:
		_create_default_save()
		return

	unlocked_zones.clear()

	for zone: Variant in data["unlocked_zones"]:
		var normalized_zone: String = _normalize_zone(str(zone))

		if not normalized_zone.is_empty() and not unlocked_zones.has(normalized_zone):
			unlocked_zones.append(normalized_zone)

	if not unlocked_zones.has(DEFAULT_ZONE):
		unlocked_zones.append(DEFAULT_ZONE)

	_save_zones()


func _save_zones() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("ZoneManager: The save file cannot be opened.")
		return

	var data: Dictionary = {
		"unlocked_zones": unlocked_zones
	}

	file.store_string(JSON.stringify(data, "\t"))


func _create_default_save() -> void:
	unlocked_zones = [DEFAULT_ZONE]
	_save_zones()


func _normalize_zone(zone: String) -> String:
	zone = zone.strip_edges().to_upper()

	if zone.length() != 1:
		push_warning("ZoneManager: The zone must be a single letter.")
		return ""

	return zone
