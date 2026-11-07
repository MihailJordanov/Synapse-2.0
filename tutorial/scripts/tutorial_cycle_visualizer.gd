class_name TutorialCycleVisualizer
extends CycleVisualizer

## Tutorial-only, extra flashy version of the cycle visualizer:
## glowing lines, energy sparks running along each connection, bouncing arrow heads,
## and matching type icons that pop and sparkle.

@export_range(0.01, 10.0, 0.01) var arrow_pulse_duration: float = 0.8
@export_range(0.0, 1.0, 0.01) var arrow_alpha_min: float = 0.3
@export_range(0.0, 1.0, 0.01) var arrow_alpha_max: float = 0.75

@export_category("Tutorial FX")
## Glow under each line: width multiplier and opacity.
@export var glow_width_multiplier: float = 2.8
@export_range(0.0, 1.0, 0.01) var glow_alpha: float = 0.35
## Energy sparks travelling along each connection.
@export_range(0, 8, 1) var sparks_per_edge: int = 3
@export_range(0.1, 5.0, 0.05) var spark_travel_time: float = 0.9
@export var spark_size: float = 9.0
## Matching type icons: pop scale and seconds between sparkle bursts.
@export var icon_pop_scale: float = 1.45
@export_range(0.2, 5.0, 0.05) var icon_sparkle_interval: float = 1.1

var _arrow_pulse_tween: Tween = null
var _edge_tweens: Array[Tween] = []
var _fx_nodes: Array[Node] = []
var _fx_tweens: Array[Tween] = []
var _popping_icons: Array[TextureRect] = []
var _sparkle_timer: Timer = null


func show_connection_preview(connection_data: CycleData, board: BoardController) -> void:
	# show_cycle draws the provided edges; they need not form a cycle yet.
	super.show_cycle(connection_data, board)
	_start_icon_fx()
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
	_start_icon_fx()


func clear_visualization() -> void:
	_stop_arrow_pulse()
	_stop_fx()

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


#region /// edges (line + glow + sparks + bouncing head)

func _create_edge(from_card: Card, to_card: Card) -> void:
	# Bind growth to the LINE, so clearing a preview cannot leave a live tween
	# capturing a freed Line2D (the original visualizer binds it to itself).
	var line: Line2D = line_template.duplicate() as Line2D
	if line == null:
		return

	var from_position: Vector2 = to_local(from_card.global_position)
	var to_position: Vector2 = to_local(to_card.global_position)

	# Soft glow under the line.
	var glow: Line2D = line_template.duplicate() as Line2D
	glow.show()
	glow.clear_points()
	glow.width = line_template.width * glow_width_multiplier
	glow.default_color = Color(line_template.default_color, glow_alpha)
	glow.add_point(from_position)
	glow.add_point(from_position)
	add_child(glow)
	_fx_nodes.append(glow)

	add_child(line)
	line.show()
	line.clear_points()
	line.add_point(from_position)
	line.add_point(from_position)
	_active_lines.append(line)

	# Arrow head built around its tip, so it can bounce in place.
	var arrow: Polygon2D = _create_tip_arrow(from_position, to_position, line.default_color)
	add_child(arrow)
	_active_arrows.append(arrow)

	var tween: Tween = line.create_tween()
	_edge_tweens.append(tween)
	(
		tween
		. tween_method(
			_grow_lines.bind(line, glow, from_position, to_position),
			0.0,
			1.0,
			maxf(animation_duration, 0.001)
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)

	var bounce: Tween = arrow.create_tween().set_loops()
	bounce.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce.tween_property(arrow, "scale", Vector2(1.35, 1.35), 0.35)
	bounce.tween_property(arrow, "scale", Vector2.ONE, 0.35)
	_fx_tweens.append(bounce)

	_add_edge_sparks(from_position, to_position, line.default_color)


func _create_tip_arrow(from_position: Vector2, to_position: Vector2, arrow_color: Color) -> Polygon2D:
	var direction: Vector2 = (to_position - from_position).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var arrow := Polygon2D.new()
	arrow.position = to_position
	arrow.polygon = PackedVector2Array([
		Vector2.ZERO,
		-direction * arrow_length + perpendicular * arrow_half_width,
		-direction * arrow_length - perpendicular * arrow_half_width,
	])
	arrow.color = arrow_color
	return arrow


func _add_edge_sparks(from_position: Vector2, to_position: Vector2, color: Color) -> void:
	var spark_color: Color = color.lightened(0.55)

	for index in range(sparks_per_edge):
		var spark := Polygon2D.new()
		var s: float = spark_size * 0.5
		spark.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
		spark.color = spark_color
		spark.position = from_position
		spark.modulate.a = 0.0
		add_child(spark)
		_fx_nodes.append(spark)

		var tween: Tween = spark.create_tween().set_loops()
		tween.tween_interval(spark_travel_time * float(index) / float(maxi(sparks_per_edge, 1)))
		tween.tween_callback(spark.set.bind("position", from_position))
		tween.tween_property(spark, "modulate:a", 1.0, 0.08)
		tween.parallel().tween_property(spark, "position", to_position, spark_travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.1)
		_fx_tweens.append(tween)


func _grow_lines(
	progress: float, line: Line2D, glow: Line2D, from_position: Vector2, to_position: Vector2
) -> void:
	var end: Vector2 = from_position.lerp(to_position, progress)

	if is_instance_valid(line):
		line.set_point_position(1, end)

	if is_instance_valid(glow):
		glow.set_point_position(1, end)

#endregion


#region /// matching type icons (pop + sparkles)

func _start_icon_fx() -> void:
	for icon: TextureRect in _pulsing_icons:
		if not is_instance_valid(icon):
			continue

		_popping_icons.append(icon)
		icon.pivot_offset = icon.size * 0.5

		var pop: Tween = icon.create_tween().set_loops()
		pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(icon, "scale", Vector2(icon_pop_scale, icon_pop_scale), 0.25)
		pop.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pop.tween_property(icon, "scale", Vector2.ONE, 0.35)
		pop.tween_interval(maxf(icon_sparkle_interval - 0.6, 0.0))
		_fx_tweens.append(pop)

	if _popping_icons.is_empty():
		return

	_burst_icon_sparkles()
	_sparkle_timer = Timer.new()
	_sparkle_timer.wait_time = icon_sparkle_interval
	_sparkle_timer.autostart = true
	add_child(_sparkle_timer)
	_sparkle_timer.timeout.connect(_burst_icon_sparkles)


func _burst_icon_sparkles() -> void:
	for icon: TextureRect in _popping_icons:
		if not is_instance_valid(icon) or not icon.is_visible_in_tree():
			continue

		var sparkles := CPUParticles2D.new()
		sparkles.one_shot = true
		sparkles.explosiveness = 0.9
		sparkles.amount = 10
		sparkles.lifetime = 0.6
		sparkles.spread = 180.0
		sparkles.initial_velocity_min = 60.0
		sparkles.initial_velocity_max = 140.0
		sparkles.gravity = Vector2.ZERO
		sparkles.damping_min = 120.0
		sparkles.damping_max = 200.0
		sparkles.scale_amount_min = 3.0
		sparkles.scale_amount_max = 5.0
		sparkles.color = Color(1.0, 0.95, 0.6)
		sparkles.z_as_relative = false
		sparkles.z_index = 1200
		add_child(sparkles)
		sparkles.global_position = icon.get_global_rect().get_center()
		sparkles.emitting = true
		sparkles.finished.connect(sparkles.queue_free)


func _stop_fx() -> void:
	for tween: Tween in _fx_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_fx_tweens.clear()

	for node: Node in _fx_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_fx_nodes.clear()

	for icon: TextureRect in _popping_icons:
		if is_instance_valid(icon):
			icon.scale = Vector2.ONE
	_popping_icons.clear()

	if is_instance_valid(_sparkle_timer):
		_sparkle_timer.queue_free()
	_sparkle_timer = null

#endregion


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
	_stop_fx()
	super._exit_tree()
