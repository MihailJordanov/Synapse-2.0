@icon("res://resources/icons/zone.svg")
class_name Zones
extends Node2D


func _ready() -> void:
	var areas: Array[Node] = find_children("*_Area2D", "Area2D", true, false)

	for node in areas:
		var area: Area2D = node as Area2D
		var zone_name: String = str(area.name).trim_suffix("_Area2D")
		var zone: CanvasItem = find_child(zone_name, true, false) as CanvasItem

		if zone == null:
			push_warning("Не е намерена зона с име: " + zone_name)
			continue

		zone.visible = false
		area.mouse_entered.connect(_on_zone_mouse_entered.bind(zone))
		area.mouse_exited.connect(_on_zone_mouse_exited.bind(zone))


func _on_zone_mouse_entered(zone: CanvasItem) -> void:
	zone.visible = true


func _on_zone_mouse_exited(zone: CanvasItem) -> void:
	zone.visible = false
