class_name CycleData extends RefCounted

var card_ids: Array[int] = []
var edges: Array[Vector2i] = []


func is_empty() -> bool:
	return card_ids.is_empty()


func clear() -> void:
	card_ids.clear()
	edges.clear()
