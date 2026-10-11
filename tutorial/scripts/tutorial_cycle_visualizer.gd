class_name TutorialCycleVisualizer
extends CycleVisualizer

@export_range(0.01, 10.0, 0.01) var arrow_pulse_duration: float = 0.8
@export_range(0.0, 1.0, 0.01) var arrow_alpha_min: float = 0.3
@export_range(0.0, 1.0, 0.01) var arrow_alpha_max: float = 0.75

var _arrow_pulse_tween: Tween = null
var _edge_tweens: Array[Tween] = []


func show_connection_preview(connection_data: CycleData, board: BoardController) -> void:
	# show_cycle draws the provided edges; they need not form a cycle yet.
	super.show_cycle(connection_data, board)
	_apply_arrow_alpha(arrow_alpha_min)
	_arrow_pulse_tween = create_tween().set_loops()
	_arrow_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_pulse_tween.tween_method(
		_apply_arrow_alpha, arrow_alpha_min, arrow_alpha_max, maxf(arrow_pulse_duration, 0.01)
	)
	_arrow_pulse_tween.tween_method(
		_apply_arrow_alpha, arrow_alpha_max, arrow_alpha_min, maxf(arrow_pulse_duration, 0.01)
	)


func show_cycle(cycle_data: CycleData, board: BoardController) -> void:
	# The original icon glow continues, but new cycle arrows have full opacity.
	super.show_cycle(cycle_data, board)


func clear_visualization() -> void:
	_stop_arrow_pulse()
	for tween: Tween in _edge_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_edge_tweens.clear()
	# Hide immediately, even though queue_free itself is deferred.
	for line: Line2D in _active_lines:
		if is_instance_valid(line):
			line.hide()
	for arrow: Polygon2D in _active_arrows:
		if is_instance_valid(arrow):
			arrow.hide()
	super.clear_visualization()


func _create_edge(from_card: Card, to_card: Card) -> void:
	# Bind growth to the LINE, so clearing a preview cannot leave a live tween
	# capturing a freed Line2D (the original visualizer binds it to itself).
	var line: Line2D = line_template.duplicate() as Line2D
	if line == null:
		return
	add_child(line)
	line.show()
	line.clear_points()
	var from_position: Vector2 = to_local(from_card.global_position)
	var to_position: Vector2 = to_local(to_card.global_position)
	line.add_point(from_position)
	line.add_point(from_position)
	_active_lines.append(line)
	var arrow: Polygon2D = _create_arrow(from_position, to_position, line.default_color)
	add_child(arrow)
	_active_arrows.append(arrow)
	var tween: Tween = line.create_tween()
	_edge_tweens.append(tween)
	(
		tween
		. tween_method(
			_grow_line.bind(line, from_position, to_position),
			0.0,
			1.0,
			maxf(animation_duration, 0.001)
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func _grow_line(
	progress: float, line: Line2D, from_position: Vector2, to_position: Vector2
) -> void:
	if is_instance_valid(line):
		line.set_point_position(1, from_position.lerp(to_position, progress))


func _apply_arrow_alpha(alpha: float) -> void:
	for line: Line2D in _active_lines:
		if is_instance_valid(line):
			line.modulate.a = alpha
	for arrow: Polygon2D in _active_arrows:
		if is_instance_valid(arrow):
			arrow.modulate.a = alpha


func _stop_arrow_pulse() -> void:
	if _arrow_pulse_tween != null and _arrow_pulse_tween.is_valid():
		_arrow_pulse_tween.kill()
	_arrow_pulse_tween = null


func _exit_tree() -> void:
	_stop_arrow_pulse()
	super._exit_tree()
