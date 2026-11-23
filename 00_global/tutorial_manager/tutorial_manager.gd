extends Node

## Global tutorial progress (autoload "TutorialManager").
## Saved separately from player data in user://tutorials.json:
##   { "save_version": 1, "completed": { "start_tutorial": true, ... } }
##
## Add a new tutorial: add an id constant below and call
##   TutorialManager.is_completed(TutorialManager.MY_TUTORIAL)
##   TutorialManager.complete(TutorialManager.MY_TUTORIAL)

signal tutorial_completed(tutorial_id: String)
signal tutorial_reset(tutorial_id: String)

const SAVE_PATH: String = "user://tutorials.json"
const SAVE_VERSION: int = 1

#region /// tutorial ids
const START_TUTORIAL: String = "start_tutorial"
const FIRST_ZONE_TUTORIAL: String = "first_zone_tutorial"
const COLLECTION_TUTORIAL: String = "collection_tutorial"
## Scripted battle about spells and mana, after the first clear of A02 (tutorial/spell_tutorial).
## Done only after Tavi showed the Collection afterwards (the battle itself is SPELL_TUTORIAL_BATTLE).
const SPELL_TUTORIAL: String = "spell_tutorial"
const SPELL_TUTORIAL_BATTLE: String = "spell_tutorial_battle"

## Per zone: "zone_intro_B" etc. (Tavi guides to a newly unlocked zone, once).
static func zone_intro_id(zone_letter: String) -> String:
	return "zone_intro_" + zone_letter.strip_edges().to_upper()
#endregion

var _completed: Dictionary = {}  # tutorial_id -> true


func _ready() -> void:
	_load()


func is_completed(tutorial_id: String) -> bool:
	return bool(_completed.get(tutorial_id, false))


## Marks a tutorial as done. Returns true if it was not completed before.
func complete(tutorial_id: String) -> bool:
	if tutorial_id.is_empty() or is_completed(tutorial_id):
		return false

	_completed[tutorial_id] = true
	_save()
	tutorial_completed.emit(tutorial_id)
	return true


## Makes a tutorial show again (e.g. "replay tutorial" in settings, or testing).
func reset(tutorial_id: String) -> void:
	if not _completed.has(tutorial_id):
		return

	_completed.erase(tutorial_id)
	_save()
	tutorial_reset.emit(tutorial_id)


func reset_all() -> void:
	_completed.clear()
	_save()


#region /// save / load

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_migrate_from_player_data()
		_save()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return

	var data: Variant = JSON.parse_string(file.get_as_text())

	if not data is Dictionary:
		push_warning("TutorialManager: invalid tutorials.json, starting fresh.")
		return

	var completed: Variant = data.get("completed", {})

	if completed is Dictionary:
		for tutorial_id in completed:
			if bool(completed[tutorial_id]):
				_completed[str(tutorial_id)] = true


## Older saves kept the flags in player_data.json - copy them once.
func _migrate_from_player_data() -> void:
	var legacy: Dictionary = PlayerDataManager.legacy_tutorial_flags

	if bool(legacy.get("start_tutorial_completed", false)):
		_completed[START_TUTORIAL] = true

	if bool(legacy.get("first_zone_tutorial_completed", false)):
		_completed[FIRST_ZONE_TUTORIAL] = true


func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("TutorialManager: Could not open the save file.")
		return

	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"completed": _completed
	}

	file.store_string(JSON.stringify(data, "\t"))

#endregion
