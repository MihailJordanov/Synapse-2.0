@icon("res://resources/icons/setup.svg")
class_name MapMenuButton
extends TextureButton

## A main map menu button (Collection, Shop, Stories...).
## Hidden until its feature is unlocked: PlayerDataManager.unlock_feature(feature_id).
## MapZones listens to `pressed` and opens target_scene_path with a fade.

## Feature id saved in player_data.json, e.g. "collection", "shop".
@export var feature_id: String = ""
## Scene to open. Empty = not available yet (nothing happens on press).
@export_file("*.tscn") var target_scene_path: String = ""
## Shows the button even when locked (handy while testing in the editor).
@export var always_visible: bool = false


func _ready() -> void:
	_refresh()

	if not PlayerDataManager.feature_unlocked.is_connected(_on_feature_unlocked):
		PlayerDataManager.feature_unlocked.connect(_on_feature_unlocked)


func is_unlocked() -> bool:
	return always_visible or PlayerDataManager.is_feature_unlocked(feature_id)


func _refresh() -> void:
	visible = is_unlocked()


func _on_feature_unlocked(unlocked_feature_id: String) -> void:
	if unlocked_feature_id != feature_id:
		return

	_refresh()

	# Small pop so a live unlock gets noticed.
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
