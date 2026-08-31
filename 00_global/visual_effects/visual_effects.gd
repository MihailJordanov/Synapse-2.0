#Visual Effects
extends Node

signal camera_shook( strength : float )
	
func camera_shake( strength : float = 1.0 ) -> void:
	camera_shook.emit( strength )
	pass
