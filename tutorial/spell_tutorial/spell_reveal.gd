class_name SpellReveal
extends Control

## Transition after the first clear of A02: a pitch-black card with light effects slowly
## comes closer, then waits for a click -> the spell tutorial.

const SCENE_PATH: String = "res://tutorial/spell_tutorial/spell_reveal.tscn"
const CARD_TEXTURE: Texture2D = preload("res://card/assets/spell_card_back.png")
const HINT_TEXT: String = "Click the card!"

const CARD_HEIGHT: float = 430.0  # on screen, at full size
const START_SCALE: float = 0.12
const GROW_TIME: float = 1.8
const RAY_COUNT: int = 14
const RAY_SPEED: float = 0.25  # rad / s
const GLOW_COLOR: Color = Color(1.0, 0.82, 0.4)


## Rotating light rays behind the card.
class Rays extends Node2D:
	var angle: float = 0.0
	var strength: float = 0.0
	var radius: float = 700.0
	var count: int = 14
	var color: Color = Color.WHITE

	func _draw() -> void:
		if strength <= 0.0:
			return

		var half_width: float = PI / float(count) * 0.45

		for i in range(count):
			var a: float = angle + TAU * float(i) / float(count)
			var points := PackedVector2Array([
				Vector2.ZERO,
				Vector2.from_angle(a - half_width) * radius,
				Vector2.from_angle(a + half_width) * radius
			])
			var inner := Color(color, 0.35 * strength)
			var outer := Color(color, 0.0)
			draw_polygon(points, PackedColorArray([inner, outer, outer]))


var _holder: Node2D
var _rays: Rays
var _outline: Sprite2D
var _card: Sprite2D
var _hint: Label
var _flash: ColorRect
var _base_scale: float = 1.0
var _time: float = 0.0
var _can_click: bool = false
var _leaving: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color(0.02, 0.01, 0.04)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center: Vector2 = get_viewport_rect().size * 0.5
	_base_scale = CARD_HEIGHT / float(CARD_TEXTURE.get_height())

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_rays = Rays.new()
	_rays.count = RAY_COUNT
	_rays.color = GLOW_COLOR
	_rays.position = center
	_rays.material = additive
	add_child(_rays)

	_holder = Node2D.new()
	_holder.position = center
	_holder.scale = Vector2.ONE * START_SCALE
	add_child(_holder)

	_holder.add_child(_create_halo(additive))
	_holder.add_child(_create_sparkles(additive))

	# Glowing edge: a slightly bigger copy of the card behind it.
	_outline = Sprite2D.new()
	_outline.texture = CARD_TEXTURE
	_outline.scale = Vector2.ONE * _base_scale * 1.07
	_outline.modulate = GLOW_COLOR
	_outline.material = additive
	_holder.add_child(_outline)

	_card = Sprite2D.new()
	_card.texture = CARD_TEXTURE
	_card.scale = Vector2.ONE * _base_scale
	_card.modulate = Color.BLACK
	_holder.add_child(_card)

	_hint = Label.new()
	_hint.text = HINT_TEXT
	_hint.add_theme_font_size_override("font_size", 40)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_hint.add_theme_constant_override("outline_size", 10)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(600.0, 60.0)
	_hint.position = Vector2(center.x - 300.0, center.y + CARD_HEIGHT * 0.5 + 40.0)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.0, 0.0, 0.0, 1.0)  # starts as a fade-in from black
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_play_intro()


func _play_intro() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.4)
	tween.tween_property(_holder, "scale", Vector2.ONE, GROW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_rays, "strength", 1.0, GROW_TIME)
	tween.parallel().tween_property(_holder, "rotation", 0.0, GROW_TIME).from(-0.25)
	await tween.finished

	_can_click = true
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	_time += delta
	_rays.angle += RAY_SPEED * delta
	_rays.queue_redraw()

	# The edge light breathes; once it can be clicked the card also pulses a little.
	var wave: float = 0.5 + 0.5 * sin(_time * 4.0)
	_outline.modulate.a = 0.55 + 0.45 * wave

	if _can_click and not _leaving:
		_card.scale = Vector2.ONE * _base_scale * (1.0 + 0.025 * wave)
		_hint.modulate.a = 0.6 + 0.4 * wave


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventScreenTouch and event.pressed)
	)

	if not pressed or not _can_click or _leaving:
		return

	var card_rect := Rect2(_holder.position - Vector2(CARD_HEIGHT * 0.4, CARD_HEIGHT * 0.5), Vector2(CARD_HEIGHT * 0.8, CARD_HEIGHT))

	if not card_rect.has_point(event.position):
		return

	accept_event()
	_leave()


func _leave() -> void:
	_leaving = true
	_hint.hide()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_holder, "scale", Vector2.ONE * 1.6, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_rays, "strength", 2.0, 0.45)
	tween.tween_property(_flash, "color:a", 1.0, 0.45)
	await tween.finished

	get_tree().change_scene_to_file(SpellTutorial.SCENE_PATH)


func _create_halo(material_add: Material) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(GLOW_COLOR, 0.8))
	gradient.set_color(1, Color(GLOW_COLOR, 0.0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256

	var halo := Sprite2D.new()
	halo.texture = texture
	halo.scale = Vector2.ONE * (CARD_HEIGHT * 1.8 / 256.0)
	halo.material = material_add
	return halo


func _create_sparkles(material_add: Material) -> CPUParticles2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(GLOW_COLOR, 0.0))

	var sparkles := CPUParticles2D.new()
	sparkles.amount = 70
	sparkles.lifetime = 1.4
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(CARD_HEIGHT * 0.42, CARD_HEIGHT * 0.55)
	sparkles.direction = Vector2.UP
	sparkles.spread = 180.0
	sparkles.gravity = Vector2(0.0, -30.0)
	sparkles.initial_velocity_min = 20.0
	sparkles.initial_velocity_max = 70.0
	sparkles.scale_amount_min = 3.0
	sparkles.scale_amount_max = 7.0
	sparkles.color_ramp = ramp
	sparkles.material = material_add
	return sparkles
