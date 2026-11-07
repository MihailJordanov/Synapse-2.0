class_name Boot
extends Node

## Startup router (project main scene).
## First launch -> start tutorial.
## Otherwise -> the last map screen the player was on (main map or a zone),
## or the main map if that scene is missing.

const TUTORIAL_SCENE_PATH: String = "res://tutorial/tutorial_level.tscn"
const MAIN_MAP_SCENE_PATH: String = "res://map/main_map.tscn"


func _ready() -> void:
	# Deferred: the scene tree is still being set up during _ready().
	_route.call_deferred()


func _route() -> void:
	var target: String = MAIN_MAP_SCENE_PATH

	if not TutorialManager.is_completed(TutorialManager.START_TUTORIAL):
		target = TUTORIAL_SCENE_PATH
	else:
		var last: String = PlayerDataManager.get_last_location()

		if not last.is_empty() and ResourceLoader.exists(last, "PackedScene"):
			target = last

	var result: Error = get_tree().change_scene_to_file(target)

	if result != OK:
		push_error("Boot: Could not open %s (error %d)." % [target, result])
