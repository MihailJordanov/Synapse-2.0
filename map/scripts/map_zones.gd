@icon("res://resources/icons/zone.svg")
class_name MapZones
extends Node2D

#region /// zones banners
const ZONE_A_BANNER = preload("uid://c2ns76638smwn")
const ZONE_B_BANNER = preload("uid://cq33ildwxllpw")

const ZONE_BANNERS: Dictionary = {
	"A": ZONE_A_BANNER,
	"B": ZONE_B_BANNER
}
#endregion

#region /// zones inform
const ZONE_A_INFO: String = "[color=#62ff90]GREENHEART VALE[/color]\n[font_size=24]A peaceful start"
const ZONE_B_INFO: String = "[color=#3785ff]WESTHARBOR[/color]\n[font_size=24]Trade by the sea"

const ZONE_INFOS: Dictionary = {
	"A": ZONE_A_INFO,
	"B": ZONE_B_INFO
}
#endregion

const START_ZONE: String = "A"
const START_PULSE_ANIMATION: StringName = &"start_pulse"

@onready var play_button: Button = %PlayButton
@onready var roll_up_button: Button = %RollUpButton
@onready var zone_texture_rect: TextureRect = %ZoneTextureRect
@onready var info_rich_text_label: RichTextLabel = %InfoRichTextLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var map_camera: MapCamera = %MapCamera2D
@onready var animation_player_start_here: AnimationPlayer = %AnimationPlayer_start_here

var areas: Dictionary = {}
var zones: Dictionary = {}
var clouds: Dictionary = {}

var selected_zone: String = ""
var is_scroll_open: bool = false
var is_animating: bool = false
var hovered_zone: String = ""


func _ready() -> void:
	_cache_zones()
	_setup_zones()

	play_button.pressed.connect(_on_play_button_pressed)
	roll_up_button.pressed.connect(_on_roll_up_button_pressed)

	if not ZoneManager.zone_unlocked.is_connected(_on_zone_unlocked):
		ZoneManager.zone_unlocked.connect(_on_zone_unlocked)

	_update_start_hint()


func _cache_zones() -> void:
	var found_areas: Array[Node] = find_children("*_Area2D", "Area2D", true, false)

	for node in found_areas:
		var area: Area2D = node as Area2D
		var zone_name: String = str(area.name).trim_suffix("_Area2D")
		var zone_letter: String = zone_name.trim_prefix("Zone_")
		var zone: CanvasItem = find_child(zone_name, true, false) as CanvasItem
		var cloud: CanvasItem = find_child("Cl_Z_" + zone_letter, true, false) as CanvasItem

		areas[zone_letter] = area

		if zone != null:
			zones[zone_letter] = zone

		if cloud != null:
			clouds[zone_letter] = cloud


func _setup_zones() -> void:
	for zone_letter in areas:
		var area: Area2D = areas[zone_letter]
		var zone: CanvasItem = zones.get(zone_letter)
		var cloud: CanvasItem = clouds.get(zone_letter)
		var is_unlocked: bool = ZoneManager.is_zone_unlocked(zone_letter)

		if zone == null:
			push_warning("No zone found with the name: Zone_" + zone_letter)
			continue

		zone.visible = false
		area.visible = is_unlocked
		area.input_pickable = is_unlocked

		if cloud != null:
			cloud.visible = not is_unlocked

		area.mouse_entered.connect(_on_zone_mouse_entered.bind(zone_letter, zone))
		area.mouse_exited.connect(_on_zone_mouse_exited.bind(zone_letter, zone))
		area.input_event.connect(_on_zone_input_event.bind(zone_letter))


func _on_zone_mouse_entered(zone_letter: String,zone: CanvasItem) -> void:
	hovered_zone = zone_letter

	if not is_scroll_open:
		zone.visible = true

	_update_start_hint()


func _on_zone_mouse_exited(zone_letter: String,zone: CanvasItem) -> void:
	if hovered_zone == zone_letter:
		hovered_zone = ""

	zone.visible = false
	_update_start_hint()


func _on_zone_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int,
	zone_letter: String
) -> void:
	var is_pressed: bool = false

	if event is InputEventMouseButton:
		is_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	elif event is InputEventScreenTouch:
		is_pressed = event.pressed

	if not is_pressed:
		return

	get_viewport().set_input_as_handled()
	_open_zone(zone_letter)


func _open_zone(zone_letter: String) -> void:
	if is_scroll_open or is_animating:
		return

	selected_zone = zone_letter
	is_scroll_open = true
	is_animating = true

	_update_start_hint()

	map_camera.set_input_enabled(false)
	_set_zone_interaction(false)
	_set_zone_information(zone_letter)

	animation_player.play("unroll_scroll")
	await animation_player.animation_finished

	is_animating = false



func _set_zone_information(zone_letter: String) -> void:
	zone_texture_rect.texture = ZONE_BANNERS.get(zone_letter) as Texture2D
	info_rich_text_label.text = str(ZONE_INFOS.get(zone_letter, ""))


func _set_zone_interaction(enabled: bool) -> void:
	for zone_letter in areas:
		var area: Area2D = areas[zone_letter]
		var zone: CanvasItem = zones.get(zone_letter)
		var should_enable: bool = enabled and ZoneManager.is_zone_unlocked(zone_letter)

		area.visible = should_enable
		area.input_pickable = should_enable

		if zone != null:
			zone.visible = false


func _on_roll_up_button_pressed() -> void:
	if not is_scroll_open or is_animating:
		return

	is_animating = true
	animation_player.play("roll_up_scroll")
	await animation_player.animation_finished

	is_scroll_open = false
	is_animating = false

	_set_zone_interaction(true)
	map_camera.set_input_enabled(true)

	await get_tree().process_frame
	_update_start_hint()
	

func _on_play_button_pressed() -> void:
	pass


func _on_zone_unlocked(zone_letter: String) -> void:
	var area: Area2D = areas.get(zone_letter)
	var zone: CanvasItem = zones.get(zone_letter)
	var cloud: CanvasItem = clouds.get(zone_letter)

	if area != null and not is_scroll_open:
		area.visible = true
		area.input_pickable = true

	if zone != null:
		zone.visible = false

	if cloud != null:
		cloud.visible = false

	_update_start_hint()


func _update_start_hint() -> void:
	var should_play: bool = (
		_get_unlocked_zone_count() == 1
		and ZoneManager.is_zone_unlocked(START_ZONE)
		and hovered_zone.is_empty()
		and not is_scroll_open
	)

	if should_play:
		_start_hint_animation()
	else:
		_stop_hint_animation()


func _get_unlocked_zone_count() -> int:
	var unlocked_count: int = 0

	for zone_letter in areas:
		if ZoneManager.is_zone_unlocked(zone_letter):
			unlocked_count += 1

	return unlocked_count
	
	
func _start_hint_animation() -> void:
	if (
		animation_player_start_here.is_playing()
		and animation_player_start_here.current_animation
			== START_PULSE_ANIMATION
	):
		return

	animation_player_start_here.play(START_PULSE_ANIMATION)


func _stop_hint_animation() -> void:
	if not animation_player_start_here.is_playing():
		return

	animation_player_start_here.stop()

	if animation_player_start_here.has_animation(&"RESET"):
		animation_player_start_here.play(&"RESET")
		animation_player_start_here.advance(0.0)
		animation_player_start_here.stop()
