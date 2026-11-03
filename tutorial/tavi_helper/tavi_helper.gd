class_name TaviHelper
extends CanvasLayer

## Reusable Tavi: speech bubble + arrows.
## - point_at_control(): arrow on the UI layer, follows the Control's screen rect every frame
##   (works for buttons inside animated/scaled parents).
## - point_at_world(): arrow added as a child of a world Node2D, so it moves with the map/camera.
##
## Usage: var tavi := TaviHelper.create(self)

enum Face { WAVE, POINT, PRESENT, WORRIED, DETERMINED, SAD }

## Where the UI arrow sits around the control (it always points at the control).
enum ArrowSide { RIGHT, LEFT, TOP, BOTTOM }

signal continue_pressed

const CONTINUE_HINT: String = "\n[right][font_size=24][color=#9fb6c4]Click to continue[/color][/font_size][/right]"

# Loaded at runtime (not preload) to avoid a script <-> own scene cyclic reference.
const SCENE_PATH: String = "res://tutorial/tavi_helper/tavi_helper.tscn"
const ARROW_TEXTURE: Texture2D = preload("res://level/tavi_guide/assets/tavi_arrow.png")

## Where TaviRoot goes when say(..., at_top = true). The bottom position is the one set in the scene.
@export var top_position: Vector2 = Vector2(10.0, -20.0)

const ARROW_SCALE: float = 4.0
const BOB_DISTANCE: float = 14.0
const BOB_PERIOD: float = 0.8

@onready var tavi_root: Control = %TaviRoot
@onready var tavi_sprite: Sprite2D = %TaviSprite
@onready var speech_label: RichTextLabel = %SpeechLabel
@onready var ui_arrow: Sprite2D = %UIArrow

var _tavi_visible: bool = false
var _tavi_tween: Tween = null
var _tavi_rest_position: Vector2
var _bottom_position: Vector2

var _target_control: Control = null
var _arrow_side: ArrowSide = ArrowSide.RIGHT
var _default_bubble_width: float = 0.0
var _click_catcher: Control = null
var _world_arrow: Sprite2D = null
var _world_arrow_base: Vector2
var _world_arrow_direction: Vector2 = Vector2.DOWN
var _time: float = 0.0


static func create(parent: Node) -> TaviHelper:
	var helper := (load(SCENE_PATH) as PackedScene).instantiate() as TaviHelper
	parent.add_child(helper)
	return helper


func _ready() -> void:
	_bottom_position = tavi_root.position
	_tavi_rest_position = _bottom_position
	tavi_root.hide()
	ui_arrow.hide()
	ui_arrow.rotation = 0.0  # texture points left -> arrow sits on the right of the control
	var panel: Control = _get_speech_panel()
	_default_bubble_width = panel.offset_right - panel.offset_left  # from the scene, not the (maybe not laid out) size

	# Full-screen invisible catcher used by wait_for_click().
	_click_catcher = Control.new()
	_click_catcher.name = "ClickCatcher"
	_click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.hide()
	_click_catcher.gui_input.connect(_on_click_catcher_input)
	add_child(_click_catcher)
	move_child(_click_catcher, 0)  # below Tavi and the arrow


func _exit_tree() -> void:
	_free_world_arrow()


func _process(delta: float) -> void:
	_time += delta
	var bob: float = (0.5 - 0.5 * cos(TAU * _time / BOB_PERIOD)) * BOB_DISTANCE

	_update_ui_arrow(bob)

	if is_instance_valid(_world_arrow):
		_world_arrow.position = _world_arrow_base - _world_arrow_direction * bob


#region /// speech

## at_top = true moves Tavi to top_position (e.g. when the bottom is busy with buttons).
func say(text: String, face: Face = Face.POINT, at_top: bool = false) -> void:
	speech_label.text = text
	_shrink_bubble_height()
	tavi_sprite.frame = face

	var target_position: Vector2 = top_position if at_top else _bottom_position

	if _tavi_visible:
		if target_position != _tavi_rest_position:
			_tavi_rest_position = target_position
			_kill_tavi_tween()
			_tavi_tween = create_tween()
			_tavi_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tavi_tween.tween_property(tavi_root, "position", _tavi_rest_position, 0.3)
		return

	_tavi_rest_position = target_position

	_tavi_visible = true
	_kill_tavi_tween()

	tavi_root.show()
	tavi_root.modulate.a = 0.0
	tavi_root.position = _tavi_rest_position + Vector2(-60.0, 0.0)

	_tavi_tween = create_tween().set_parallel()
	_tavi_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tavi_tween.tween_property(tavi_root, "position", _tavi_rest_position, 0.35)
	_tavi_tween.tween_property(tavi_root, "modulate:a", 1.0, 0.25)


func hide_tavi() -> void:
	if not _tavi_visible:
		return

	_tavi_visible = false
	_kill_tavi_tween()

	_tavi_tween = create_tween().set_parallel()
	_tavi_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tavi_tween.tween_property(tavi_root, "position", _tavi_rest_position + Vector2(-60.0, 0.0), 0.25)
	_tavi_tween.tween_property(tavi_root, "modulate:a", 0.0, 0.25)
	_tavi_tween.chain().tween_callback(tavi_root.hide)


func _kill_tavi_tween() -> void:
	if _tavi_tween != null and _tavi_tween.is_valid():
		_tavi_tween.kill()


## Moves Tavi's (bottom) spot and optionally changes the bubble width for this scene/step.
## Call before say(). bubble_width <= 0 keeps the scene's default width.
func set_layout(new_position: Vector2, bubble_width: float = 0.0) -> void:
	_bottom_position = new_position
	_set_bubble_width(bubble_width if bubble_width > 0.0 else _default_bubble_width)

	if _tavi_visible and _tavi_rest_position != new_position:
		_tavi_rest_position = new_position
		_kill_tavi_tween()
		_tavi_tween = create_tween()
		_tavi_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tavi_tween.tween_property(tavi_root, "position", new_position, 0.3)


## Shows the text with a "Click to continue" hint and waits for a click anywhere.
## Use with await. Clicks do not reach the game while waiting.
func say_and_wait(text: String, face: Face = Face.POINT, at_top: bool = false) -> void:
	say(text + CONTINUE_HINT, face, at_top)
	_click_catcher.show()
	await continue_pressed
	_click_catcher.hide()


func _on_click_catcher_input(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventScreenTouch and event.pressed)
	)

	if pressed:
		_click_catcher.accept_event()
		continue_pressed.emit()


func _set_bubble_width(width: float) -> void:
	var panel: Control = _get_speech_panel()
	panel.offset_right = panel.offset_left + width
	_shrink_bubble_height()


## The bubble grows with the text; shrink it back after a text/width change.
func _shrink_bubble_height() -> void:
	var panel: Control = _get_speech_panel()
	# Height 0 -> the container grows back to exactly what the text needs (width is kept).
	panel.offset_bottom = panel.offset_top


func _get_speech_panel() -> Control:
	return speech_label.get_parent() as Control

#endregion


#region /// arrows

## UI arrow next to the control (side), pointing at it.
func point_at_control(control: Control, side: ArrowSide = ArrowSide.RIGHT) -> void:
	_target_control = control
	_arrow_side = side

	match side:
		ArrowSide.RIGHT: ui_arrow.rotation = 0.0         # points left
		ArrowSide.LEFT: ui_arrow.rotation = PI           # points right
		ArrowSide.TOP: ui_arrow.rotation = -PI * 0.5     # points down
		ArrowSide.BOTTOM: ui_arrow.rotation = PI * 0.5   # points up


## World arrow as a child of target. local_position is in the target's space,
## direction is where the arrow points (e.g. Vector2.DOWN = arrow above the target).
func point_at_world(target: Node2D, local_position: Vector2, direction: Vector2 = Vector2.DOWN) -> void:
	_free_world_arrow()

	if not is_instance_valid(target):
		return

	_world_arrow_direction = direction.normalized()
	_world_arrow_base = local_position

	_world_arrow = Sprite2D.new()
	_world_arrow.name = "TaviWorldArrow"
	_world_arrow.texture = ARROW_TEXTURE
	_world_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_arrow.z_as_relative = false
	_world_arrow.z_index = 200
	# The texture points left (-X); rotate it to the requested direction.
	_world_arrow.rotation = _world_arrow_direction.angle() - PI
	# Undo the parent's scale so the arrow has the same size everywhere.
	var parent_scale: Vector2 = target.global_scale
	_world_arrow.scale = Vector2(ARROW_SCALE / maxf(absf(parent_scale.x), 0.001), ARROW_SCALE / maxf(absf(parent_scale.y), 0.001))
	_world_arrow.position = local_position
	target.add_child(_world_arrow)


func clear_arrows() -> void:
	_target_control = null
	ui_arrow.hide()
	_free_world_arrow()


func _update_ui_arrow(bob: float) -> void:
	if not is_instance_valid(_target_control) or not _target_control.is_visible_in_tree():
		ui_arrow.hide()
		return

	var xf: Transform2D = _target_control.get_global_transform_with_canvas()
	var size: Vector2 = _target_control.size * xf.get_scale()

	# Hidden while the parent is still scaling in (e.g. the scroll unroll animation).
	if size.x < 40.0:
		ui_arrow.hide()
		return

	var half_length: float = ARROW_TEXTURE.get_width() * ui_arrow.scale.x * 0.5
	var gap: float = half_length + 8.0 + bob
	var center: Vector2 = xf.origin + size * 0.5

	match _arrow_side:
		ArrowSide.RIGHT: ui_arrow.position = Vector2(xf.origin.x + size.x + gap, center.y)
		ArrowSide.LEFT: ui_arrow.position = Vector2(xf.origin.x - gap, center.y)
		ArrowSide.TOP: ui_arrow.position = Vector2(center.x, xf.origin.y - gap)
		ArrowSide.BOTTOM: ui_arrow.position = Vector2(center.x, xf.origin.y + size.y + gap)

	ui_arrow.show()


func _free_world_arrow() -> void:
	if is_instance_valid(_world_arrow):
		_world_arrow.queue_free()

	_world_arrow = null

#endregion
