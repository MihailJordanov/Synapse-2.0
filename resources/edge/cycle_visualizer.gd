class_name CycleVisualizer extends Node2D

@onready var line_template: Line2D = %Line2D

@export var animation_duration: float = 0.25
@export var arrow_length: float = 20.0
@export var arrow_half_width: float = 9.0

# Duration of ONE direction (-1 -> +1); a full pulse takes twice this time.
@export_range(0.01, 10.0, 0.01) var icon_pulse_duration: float = 1
@export var icon_intensity_min: float = -0.5
@export var icon_intensity_max: float = 0.3

var _active_arrows: Array[Polygon2D] = []
var _active_lines: Array[Line2D] = []
var _pulsing_icons: Array[TextureRect] = []
var _original_icon_colors: Array[Color] = []
var _icon_pulse_tween: Tween = null


func _ready() -> void:
	line_template.visible = false


func show_cycle(cycle_data: CycleData, board_controller: BoardController) -> void:
	clear_visualization()

	if cycle_data == null or not is_instance_valid(board_controller):
		return

	for edge: Vector2i in cycle_data.edges:
		var from_card: Card = board_controller.get_card(edge.x)
		var to_card: Card = board_controller.get_card(edge.y)

		if not is_instance_valid(from_card):
			continue

		if not is_instance_valid(to_card):
			continue

		_create_edge(from_card, to_card)
		_collect_edge_icons(from_card as UnitCard, to_card as UnitCard)

	_start_icon_pulse()


func _collect_edge_icons(from_card: UnitCard, to_card: UnitCard) -> void:
	if not is_instance_valid(from_card) or not is_instance_valid(to_card):
		return

	for type_number: int in from_card.target_types:
		if to_card.source_types.has(type_number):
			_register_pulsing_icon(from_card.get_type_icon(type_number, true))
			_register_pulsing_icon(to_card.get_type_icon(type_number, false))


func _register_pulsing_icon(icon: TextureRect) -> void:
	if not is_instance_valid(icon) or not icon.visible or _pulsing_icons.has(icon):
		return
	_pulsing_icons.append(icon)
	_original_icon_colors.append(icon.self_modulate)


func _start_icon_pulse() -> void:
	if _pulsing_icons.is_empty():
		return
	_apply_icon_intensity(icon_intensity_min)
	var duration: float = maxf(icon_pulse_duration, 0.01)
	_icon_pulse_tween = create_tween().set_loops()
	_icon_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_icon_pulse_tween.tween_method(
		_apply_icon_intensity, icon_intensity_min, icon_intensity_max, duration
	)
	_icon_pulse_tween.tween_method(
		_apply_icon_intensity, icon_intensity_max, icon_intensity_min, duration
	)


func _apply_icon_intensity(intensity: float) -> void:
	# Color-picker intensity is exposure: I=0 -> x1, I=-1 -> x0.5, I=1 -> x2.
	var multiplier: float = pow(2.0, intensity)
	for index: int in range(_pulsing_icons.size()):
		var icon: TextureRect = _pulsing_icons[index]
		if not is_instance_valid(icon):
			continue
		var original: Color = _original_icon_colors[index]
		icon.self_modulate = Color(
			original.r * multiplier,
			original.g * multiplier,
			original.b * multiplier,
			original.a
		)


func _stop_icon_pulse() -> void:
	if _icon_pulse_tween != null and _icon_pulse_tween.is_valid():
		_icon_pulse_tween.kill()
	_icon_pulse_tween = null
	for index: int in range(_pulsing_icons.size()):
		var icon: TextureRect = _pulsing_icons[index]
		if is_instance_valid(icon):
			icon.self_modulate = _original_icon_colors[index]
	_pulsing_icons.clear()
	_original_icon_colors.clear()


func _exit_tree() -> void:
	_stop_icon_pulse()


func _create_edge(from_card: Card,to_card: Card) -> void:
	var line: Line2D = line_template.duplicate() as Line2D

	if line == null:
		push_error(
			"CycleVisualizer: Could not duplicate line template."
		)
		return

	add_child(line)

	line.visible = true
	line.clear_points()

	var from_position: Vector2 = to_local(
		from_card.global_position
	)

	var to_position: Vector2 = to_local(
		to_card.global_position
	)

	line.add_point(from_position)
	line.add_point(from_position)

	_active_lines.append(line)
	
	var arrow: Polygon2D = _create_arrow(from_position, to_position, line.default_color)

	add_child(arrow)
	_active_arrows.append(arrow)

	var tween: Tween = create_tween()

	tween.tween_method(
		func(progress: float) -> void:
			if not is_instance_valid(line):
				return

			var current_end: Vector2 = from_position.lerp(
				to_position,
				progress
			)

			line.set_point_position(1, current_end),
		0.0,
		1.0,
		animation_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
func clear_visualization() -> void:
	_stop_icon_pulse()

	for line: Line2D in _active_lines:
		if is_instance_valid(line):
			line.queue_free()

	for arrow: Polygon2D in _active_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()

	_active_lines.clear()
	_active_arrows.clear()


func _create_arrow( from_position: Vector2, to_position: Vector2, arrow_color: Color) -> Polygon2D:
	
	var direction: Vector2 = (to_position - from_position).normalized()

	var perpendicular: Vector2 = Vector2( -direction.y, direction.x )

	var tip: Vector2 = to_position

	var base: Vector2 = ( to_position - direction * arrow_length)

	var arrow: Polygon2D = Polygon2D.new()

	arrow.polygon = PackedVector2Array([
		tip,
		base + perpendicular * arrow_half_width,
		base - perpendicular * arrow_half_width
	])

	arrow.color = arrow_color
	return arrow
