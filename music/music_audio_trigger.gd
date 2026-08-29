@icon("res://resources/icons/music_trigger.svg")
class_name MusicAutoTrigger extends Node

@export var track: AudioStream
@export var loop: bool = true
@export_range(-80.0, 6.0, 0.5) var volume_db: float = 0.0
@export var reverb: Audio.REVERB_TYPE = Audio.REVERB_TYPE.NONE


func _ready() -> void:
	if track:
		Audio.play_music(track, loop, volume_db)

	Audio.set_reverb(reverb)
