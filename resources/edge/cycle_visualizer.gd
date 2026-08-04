class_name CycleVisualizer extends Node2D

@onready var line_template: Line2D = %Line2D

@export var animation_duration: float = 0.25
@export var arrow_length: float = 20.0
@export var arrow_half_width: float = 9.0

var _active_arrows: Array[Polygon2D] = []
var _active_lines: Array[Line2D] = []


func _ready() -> void:
	line_template.visible = false


func show_cycle(cycle_data: CycleData, board_controller: BoardController) -> void:
	clear_visualization()

	if cycle_data == null:
		return

	for edge: Vector2i in cycle_data.edges:
		var from_card: Card = board_controller.get_card(edge.x)
		var to_card: Card = board_controller.get_card(edge.y)

		if not is_instance_valid(from_card):
			continue

		if not is_instance_valid(to_card):
			continue

		_create_edge(from_card, to_card)


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
