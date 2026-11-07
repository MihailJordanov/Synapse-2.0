class_name PixelExplosion
extends Node2D

## Big pixel-art explosion built from code (no assets needed):
## white flash + shockwave ring + pixel debris + sparks + rising embers + smoke.
##
##   PixelExplosion.spawn(get_tree().current_scene, global_pos, Color.ORANGE, 1.0)
##
## power scales size, speed and particle counts (1.0 = normal, 1.5 = huge).

const LIFETIME: float = 2.2

var _tint: Color = Color.ORANGE
var _power: float = 1.0
var _flash_radius: float = 0.0
var _flash_alpha: float = 0.0
var _ring_radius: float = 0.0
var _ring_width: float = 0.0
var _ring_alpha: float = 0.0


static func spawn(parent: Node, at_global_position: Vector2, tint: Color = Color.ORANGE, power: float = 1.0) -> PixelExplosion:
	var explosion := PixelExplosion.new()
	explosion._tint = tint
	explosion._power = maxf(power, 0.2)
	explosion.z_as_relative = false
	explosion.z_index = 1500
	parent.add_child(explosion)
	explosion.global_position = at_global_position
	explosion._play()
	return explosion


func _play() -> void:
	var p: float = _power

	# Debris: chunky pixels flying out and falling.
	_add_particles(int(55 * p), 0.95, Vector2(260, 560) * p, Vector2(0, 700), Vector2(7, 13) * p,
		_ramp([Color.WHITE, _tint.lightened(0.2), _tint, _tint.darkened(0.6)]), 4.0)
	# Sparks: small, fast, bright.
	_add_particles(int(45 * p), 0.5, Vector2(520, 900) * p, Vector2.ZERO, Vector2(3, 5) * p,
		_ramp([Color(1, 1, 0.85), Color(1, 0.85, 0.3), Color(1, 0.45, 0.1, 0.0)]), 8.0)
	# Embers: slowly rising.
	_add_particles(int(22 * p), 1.6, Vector2(60, 160) * p, Vector2(0, -120), Vector2(4, 6) * p,
		_ramp([_tint.lightened(0.4), _tint, Color(_tint.r, _tint.g, _tint.b, 0.0)]), 1.5)
	# Smoke: big soft-grey squares.
	_add_particles(int(14 * p), 1.4, Vector2(40, 140) * p, Vector2(0, -40), Vector2(18, 30) * p,
		_ramp([Color(0.35, 0.32, 0.3, 0.75), Color(0.25, 0.22, 0.2, 0.4), Color(0.2, 0.2, 0.2, 0.0)]), 3.0)

	# Flash + shockwave are drawn in _draw().
	var tween: Tween = create_tween().set_parallel()
	tween.tween_method(_set_flash, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_ring, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _add_particles(
	amount: int, lifetime: float, speed: Vector2, gravity_vector: Vector2,
	size: Vector2, color_ramp: Gradient, damping_value: float
) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.randomness = 0.4
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	particles.gravity = gravity_vector
	particles.damping_min = damping_value * 40.0
	particles.damping_max = damping_value * 80.0
	particles.scale_amount_min = size.x
	particles.scale_amount_max = size.y
	particles.scale_amount_curve = _shrink_curve()
	particles.color_ramp = color_ramp
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0 * _power
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(particles)
	particles.emitting = true


func _ramp(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()

	for index in range(colors.size()):
		offsets.append(float(index) / float(maxi(colors.size() - 1, 1)))
		packed.append(colors[index])

	gradient.offsets = offsets
	gradient.colors = packed
	return gradient


func _shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _set_flash(progress: float) -> void:
	_flash_radius = lerpf(10.0, 90.0, progress) * _power
	_flash_alpha = 1.0 - progress
	queue_redraw()


func _set_ring(progress: float) -> void:
	_ring_radius = lerpf(12.0, 170.0, progress) * _power
	_ring_width = lerpf(14.0, 2.0, progress) * _power
	_ring_alpha = 1.0 - progress
	queue_redraw()


func _draw() -> void:
	if _flash_alpha > 0.0:
		draw_circle(Vector2.ZERO, _flash_radius, Color(1, 1, 0.92, _flash_alpha * 0.85))

	if _ring_alpha > 0.0:
		var ring_color: Color = _tint.lightened(0.35)
		ring_color.a = _ring_alpha
		draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 40, ring_color, _ring_width)
