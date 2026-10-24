class_name SceneFader
extends CanvasLayer

## Drop-in fade (same look/animation as the zone and main map fades).
## Fades in when the scene starts; change_scene() fades out, then switches scene.

@export var fade_in_on_ready: bool = true

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _is_changing: bool = false


func _ready() -> void:
	if fade_in_on_ready:
		animation_player.play("fade_in")


func change_scene(scene_path: String) -> void:
	if _is_changing or scene_path.is_empty():
		return

	_is_changing = true
	animation_player.play("fade_out")
	await animation_player.animation_finished

	var result: Error = get_tree().change_scene_to_file(scene_path)

	if result != OK:
		_is_changing = false
		push_error("SceneFader: Could not open %s (error %d)." % [scene_path, result])
