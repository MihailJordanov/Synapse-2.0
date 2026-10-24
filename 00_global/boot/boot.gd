class_name Boot
extends Node

## Startup router (project main scene).
## First launch -> start tutorial. Otherwise -> main map.

const TUTORIAL_SCENE_PATH: String = "res://tutorial/tutorial_level.tscn"
const MAIN_MAP_SCENE_PATH: String = "res://map/main_map.tscn"


func _ready() -> void:
	# Deferred: the scene tree is still being set up during _ready().
	_route.call_deferred()


func _route() -> void:
	var target: String = MAIN_MAP_SCENE_PATH

	if not PlayerDataManager.is_start_tutorial_completed():
		target = TUTORIAL_SCENE_PATH

	var result: Error = get_tree().change_scene_to_file(target)

	if result != OK:
		push_error("Boot: Could not open %s (error %d)." % [target, result])
