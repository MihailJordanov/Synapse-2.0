class_name Legend
extends Resource


@export_group("Info")
@export_range(31000, 31999, 1) var legend_id: int = 31000
@export var legend_name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D

@export_group("Animation")
@export var activation_animation_name: StringName = &""

@export_group("Effect")
@export var effect: LegendEffect


func get_starting_extra_draws() -> int:
	if effect == null:
		return 0

	return effect.get_starting_extra_draws()
