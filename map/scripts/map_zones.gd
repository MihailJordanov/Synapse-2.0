@icon("res://resources/icons/zone.svg")
class_name MapZones
extends Node2D


func _ready() -> void:
	var areas: Array[Node] = find_children("*_Area2D", "Area2D", true, false)

	for node in areas:
		var area: Area2D = node as Area2D
		var zone_name: String = str(area.name).trim_suffix("_Area2D")
		var zone_letter: String = zone_name.trim_prefix("Zone_")
		var zone: CanvasItem = find_child(zone_name, true, false) as CanvasItem
		var clouds: CanvasItem = find_child("Cl_Z_" + zone_letter, true, false) as CanvasItem
		var is_unlocked: bool = ZoneManager.is_zone_unlocked(zone_letter)

		if zone == null:
			push_warning("No zone found with the name: " + zone_name)
			continue

		zone.visible = false
		area.visible = is_unlocked
		area.input_pickable = is_unlocked

		if clouds != null:
			clouds.visible = not is_unlocked

		area.mouse_entered.connect(_on_zone_mouse_entered.bind(zone))
		area.mouse_exited.connect(_on_zone_mouse_exited.bind(zone))

	ZoneManager.zone_unlocked.connect(_on_zone_unlocked)


func _on_zone_mouse_entered(zone: CanvasItem) -> void:
	zone.visible = true


func _on_zone_mouse_exited(zone: CanvasItem) -> void:
	zone.visible = false


func _on_zone_unlocked(zone_letter: String) -> void:
	var area: Area2D = find_child("Zone_" + zone_letter + "_Area2D", true, false) as Area2D
	var zone: CanvasItem = find_child("Zone_" + zone_letter, true, false) as CanvasItem
	var clouds: CanvasItem = find_child("Cl_Z_" + zone_letter, true, false) as CanvasItem

	if area != null:
		area.visible = true
		area.input_pickable = true

	if zone != null:
		zone.visible = false

	if clouds != null:
		clouds.visible = false
