class_name NameEntry
extends Control

## Between the start tutorial and the main map: Tavi asks for the player's name,
## gives the first icon and marks the start tutorial as completed.
## If the tutorial was already completed (replayed later), it goes straight to the main map.

const MAIN_MAP_SCENE_PATH: String = "res://map/main_map.tscn"
const FIRST_ICON_ID: int = 1000
const MIN_NAME_LENGTH: int = 3
const MAX_NAME_LENGTH: int = 10

enum Face { WAVE, POINT, PRESENT, WORRIED, DETERMINED, SAD }

## Seconds the "nice to meet you" message stays before going to the map.
@export_range(0.5, 10.0, 0.1) var goodbye_delay: float = 3.0

@onready var content: Control = %Content
@onready var tavi_sprite: Sprite2D = %TaviSprite
@onready var speech_label: RichTextLabel = %SpeechLabel
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var confirm_button: Button = %ConfirmButton
@onready var hint_label: Label = %HintLabel
@onready var gift_icon: TextureRect = %GiftIcon
@onready var scene_fader: SceneFader = %SceneFader

var _is_done: bool = false


func _ready() -> void:
	if TutorialManager.is_completed(TutorialManager.START_TUTORIAL):
		content.hide()
		scene_fader.change_scene.call_deferred(MAIN_MAP_SCENE_PATH)
		return

	gift_icon.hide()
	name_line_edit.max_length = MAX_NAME_LENGTH
	name_line_edit.text = PlayerDataManager.get_player_name()
	name_line_edit.text_changed.connect(_on_name_changed)
	name_line_edit.text_submitted.connect(_on_name_submitted)
	confirm_button.pressed.connect(_confirm)

	speech_label.text = TaviLines.NAME_ASK
	tavi_sprite.frame = Face.WAVE
	_on_name_changed(name_line_edit.text)

	# Soft entrance on top of the scene fade.
	content.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(content, "modulate:a", 1.0, 0.6)
	tween.tween_callback(name_line_edit.grab_focus)


func _clean_name(raw: String) -> String:
	return raw.strip_edges()


func _is_valid(player_name: String) -> bool:
	var length: int = player_name.length()
	return length >= MIN_NAME_LENGTH and length <= MAX_NAME_LENGTH


func _on_name_changed(new_text: String) -> void:
	var player_name: String = _clean_name(new_text)
	var valid: bool = _is_valid(player_name)

	confirm_button.disabled = not valid

	if player_name.is_empty() or valid:
		hint_label.text = "%d-%d characters" % [MIN_NAME_LENGTH, MAX_NAME_LENGTH]
		hint_label.modulate = Color(1, 1, 1, 0.6)
	else:
		hint_label.text = "Too short - at least %d characters" % MIN_NAME_LENGTH
		hint_label.modulate = Color("#ff7a7a")


func _on_name_submitted(_text: String) -> void:
	_confirm()


func _confirm() -> void:
	if _is_done:
		return

	var player_name: String = _clean_name(name_line_edit.text)

	if not _is_valid(player_name):
		Audio.ui_error()
		return

	_is_done = true
	name_line_edit.editable = false
	confirm_button.disabled = true

	PlayerDataManager.set_player_name(player_name)
	PlayerDataManager.unlock_icon(FIRST_ICON_ID)
	PlayerDataManager.set_player_icon(FIRST_ICON_ID)
	TutorialManager.complete(TutorialManager.START_TUTORIAL)

	speech_label.text = TaviLines.NAME_CONFIRMED.format({"name": player_name})
	tavi_sprite.frame = Face.PRESENT
	_show_gift()

	await get_tree().create_timer(goodbye_delay).timeout

	var tween: Tween = create_tween()
	tween.tween_property(content, "modulate:a", 0.0, 0.4)
	await tween.finished

	scene_fader.change_scene(MAIN_MAP_SCENE_PATH)


func _show_gift() -> void:
	var texture: Texture2D = PlayerDataManager.get_icon_texture(FIRST_ICON_ID)

	if texture == null:
		return

	gift_icon.texture = texture
	gift_icon.pivot_offset = gift_icon.size * 0.5
	gift_icon.scale = Vector2(0.2, 0.2)
	gift_icon.show()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(gift_icon, "scale", Vector2.ONE, 0.45)
