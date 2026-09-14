class_name MapCamera
extends Camera2D

@onready var level_bounds: LevelBounds = %LevelBounds

@export_range(0.1, 5.0, 0.1) var min_zoom: float = 0.5
@export_range(0.1, 5.0, 0.1) var max_zoom: float = 2.0
@export_range(1.01, 2.0, 0.01) var zoom_step: float = 1.15

var is_mouse_dragging: bool = false
var touches: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_adjust_zoom_to_bounds()
	_clamp_camera()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_mouse_dragging = event.pressed

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_position(zoom.x * zoom_step, event.position)

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_position(zoom.x / zoom_step, event.position)

	elif event is InputEventMouseMotion and is_mouse_dragging:
		global_position -= event.relative / zoom.x
		_clamp_camera()

	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)

	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	var old_touches: Dictionary = touches.duplicate()
	touches[event.index] = event.position

	if touches.size() == 1:
		if old_touches.has(event.index):
			global_position -= (event.position - old_touches[event.index]) / zoom.x
			_clamp_camera()
		return

	if touches.size() < 2:
		return

	var indexes: Array = touches.keys()
	var first_index: int = indexes[0]
	var second_index: int = indexes[1]

	if not old_touches.has(first_index) or not old_touches.has(second_index):
		return

	var old_first: Vector2 = old_touches[first_index]
	var old_second: Vector2 = old_touches[second_index]
	var new_first: Vector2 = touches[first_index]
	var new_second: Vector2 = touches[second_index]

	var old_distance: float = old_first.distance_to(old_second)
	var new_distance: float = new_first.distance_to(new_second)

	if old_distance == 0.0:
		return

	var touch_center: Vector2 = (new_first + new_second) * 0.5
	_zoom_at_position(zoom.x * new_distance / old_distance, touch_center)

func _zoom_at_position(new_zoom: float, screen_position: Vector2) -> void:
	var old_zoom: float = zoom.x
	var minimum_allowed_zoom: float = _get_min_allowed_zoom()
	var maximum_allowed_zoom: float = maxf(max_zoom, minimum_allowed_zoom)
	new_zoom = clampf(new_zoom, minimum_allowed_zoom, maximum_allowed_zoom)

	if is_equal_approx(old_zoom, new_zoom):
		return

	var screen_center: Vector2 = get_viewport_rect().size * 0.5
	var world_position: Vector2 = global_position + (screen_position - screen_center) / old_zoom

	zoom = Vector2.ONE * new_zoom
	global_position = world_position - (screen_position - screen_center) / new_zoom

	_clamp_camera()

func _clamp_camera() -> void:
	if level_bounds == null:
		return

	var bounds_left: float = level_bounds.global_position.x
	var bounds_top: float = level_bounds.global_position.y
	var bounds_right: float = bounds_left + level_bounds.width
	var bounds_bottom: float = bounds_top + level_bounds.height
	var half_view: Vector2 = get_viewport_rect().size * 0.5 / zoom

	var minimum_x: float = bounds_left + half_view.x
	var maximum_x: float = bounds_right - half_view.x
	var minimum_y: float = bounds_top + half_view.y
	var maximum_y: float = bounds_bottom - half_view.y

	if minimum_x > maximum_x:
		global_position.x = (bounds_left + bounds_right) * 0.5
	else:
		global_position.x = clampf(global_position.x, minimum_x, maximum_x)

	if minimum_y > maximum_y:
		global_position.y = (bounds_top + bounds_bottom) * 0.5
	else:
		global_position.y = clampf(global_position.y, minimum_y, maximum_y)
		
func _get_min_allowed_zoom() -> float:
	if level_bounds == null:
		return min_zoom

	var viewport_size: Vector2 = get_viewport_rect().size
	var bounds_size := Vector2(level_bounds.width, level_bounds.height)
	var bounds_zoom: float = maxf(viewport_size.x / bounds_size.x, viewport_size.y / bounds_size.y)

	return maxf(min_zoom, bounds_zoom)
	
func _adjust_zoom_to_bounds() -> void:
	var minimum_allowed_zoom: float = _get_min_allowed_zoom()
	var maximum_allowed_zoom: float = maxf(max_zoom, minimum_allowed_zoom)
	var new_zoom: float = clampf(zoom.x, minimum_allowed_zoom, maximum_allowed_zoom)

	zoom = Vector2.ONE * new_zoom
	
func _on_viewport_size_changed() -> void:
	_adjust_zoom_to_bounds()
	_clamp_camera()
