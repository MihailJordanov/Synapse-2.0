class_name ZoneCompleteScreen
extends Control

## Black screen with Tavi after the first clear of a zone's last level.
## Continue -> main map, where Tavi then guides the player to the new zone
## (that part lives in MapZones + ZoneController, tutorial id "zone_intro_<letter>").

const SCENE_PATH: String = "res://tutorial/zone_complete/zone_complete.tscn"
const MAIN_MAP_SCENE_PATH: String = "res://map/main_map.tscn"

enum Face { WAVE, POINT, PRESENT, WORRIED, DETERMINED, SAD }

## Set by VictoryState before switching here: the zone that was just unlocked.
static var new_zone: String = ""

@onready var content: Control = %Content
@onready var tavi_sprite: Sprite2D = %TaviSprite
@onready var speech_label: RichTextLabel = %SpeechLabel
@onready var continue_button: Button = %ContinueButton
@onready var scene_fader: SceneFader = %SceneFader


func _ready() -> void:
	speech_label.text = TaviLines.ZONE_COMPLETE
	tavi_sprite.frame = Face.WAVE
	continue_button.pressed.connect(_on_continue_pressed)

	content.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(content, "modulate:a", 1.0, 0.6)
	tween.tween_callback(continue_button.grab_focus)


func _on_continue_pressed() -> void:
	continue_button.disabled = true
	Audio.ui_select()

	var tween: Tween = create_tween()
	tween.tween_property(content, "modulate:a", 0.0, 0.4)
	await tween.finished

	scene_fader.change_scene(MAIN_MAP_SCENE_PATH)
