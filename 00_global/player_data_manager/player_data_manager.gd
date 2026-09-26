extends Node

signal player_name_changed(player_name: String)
signal player_icon_changed(icon_id: int)
signal icon_unlocked(icon_id: int)

const SAVE_PATH: String = "user://player_data.json"
const SAVE_VERSION: int = 1
const DEFAULT_ICON_ID: int = 1000
const NO_ICON_ID: int = -1
const ICONS_DATA_PATH: String = "res://data/icons/icons.json"


var player_name: String = ""
var player_icon_id: int = NO_ICON_ID
var icon_ids: Array[int] = []
var icons_data: Dictionary = {}

func _ready() -> void:
	_load_icons_data()
	_load_player_data()


func set_player_name(new_name: String) -> bool:
	new_name = new_name.strip_edges()

	if player_name == new_name:
		return false

	player_name = new_name
	_save_player_data()
	player_name_changed.emit(player_name)

	return true


func set_player_icon(icon_id: int) -> bool:
	if player_icon_id == icon_id:
		return false

	if icon_id != NO_ICON_ID and not icon_ids.has(icon_id):
		return false

	player_icon_id = icon_id
	_save_player_data()
	player_icon_changed.emit(player_icon_id)

	return true


func unlock_icon(icon_id: int) -> bool:
	if icon_id == NO_ICON_ID or icon_ids.has(icon_id):
		return false

	icon_ids.append(icon_id)
	_save_player_data()
	icon_unlocked.emit(icon_id)

	return true


func has_icon(icon_id: int) -> bool:
	return icon_ids.has(icon_id)


func get_player_name() -> String:
	return player_name


func get_player_icon_id() -> int:
	return player_icon_id


func get_icon_ids() -> Array[int]:
	return icon_ids.duplicate()


func _load_player_data() -> void:
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

	player_name = str(data.get("player_name", "")).strip_edges()
	player_icon_id = int(data.get("player_icon_id", NO_ICON_ID))
	icon_ids = _read_int_array(data.get("icon_ids", []))

	if player_icon_id != NO_ICON_ID and not icon_ids.has(player_icon_id):
		player_icon_id = NO_ICON_ID

	_save_player_data()
	

func _read_int_array(data: Variant) -> Array[int]:
	var result: Array[int] = []

	if not data is Array:
		return result

	for value in data:
		var icon_id: int = int(value)

		if icon_id != NO_ICON_ID and not result.has(icon_id):
			result.append(icon_id)

	return result


func _save_player_data() -> void:
	icon_ids.sort()

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("PlayerDataManager: Could not open the save file.")
		return

	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"player_name": player_name,
		"player_icon_id": player_icon_id,
		"icon_ids": icon_ids
	}

	file.store_string(JSON.stringify(data, "\t"))


func _create_default_save() -> void:
	player_name = ""
	player_icon_id = DEFAULT_ICON_ID
	icon_ids = [DEFAULT_ICON_ID]
	_save_player_data()

func get_player_icon_texture() -> Texture2D:
	return get_icon_texture(player_icon_id)


func get_icon_texture(icon_id: int) -> Texture2D:
	var icon_path: String = get_icon_path(icon_id)

	if icon_path.is_empty():
		return null

	if not ResourceLoader.exists(icon_path):
		push_warning("PlayerDataManager: Icon texture does not exist: " + icon_path)
		return null

	return load(icon_path) as Texture2D


func get_icon_path(icon_id: int) -> String:
	if not icons_data.has(icon_id):
		return ""

	return str(icons_data[icon_id])


func _load_icons_data() -> void:
	icons_data.clear()

	if not FileAccess.file_exists(ICONS_DATA_PATH):
		push_error("PlayerDataManager: icons.json was not found.")
		return

	var file: FileAccess = FileAccess.open(ICONS_DATA_PATH, FileAccess.READ)

	if file == null:
		push_error("PlayerDataManager: Could not open icons.json.")
		return

	var data: Variant = JSON.parse_string(file.get_as_text())

	if not data is Dictionary:
		push_error("PlayerDataManager: Invalid icons.json.")
		return

	var icons: Variant = data.get("icons", [])

	if not icons is Array:
		push_error("PlayerDataManager: Icons must be an Array.")
		return

	for icon_data in icons:
		if not icon_data is Dictionary:
			continue

		var icon_id: int = int(icon_data.get("id", NO_ICON_ID))
		var texture_path: String = str(icon_data.get("texture_path", "")).strip_edges()

		if icon_id == NO_ICON_ID or texture_path.is_empty():
			continue

		icons_data[icon_id] = texture_path
