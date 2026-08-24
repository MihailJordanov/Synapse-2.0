class_name KnightLegendEffect
extends LegendEffect


@export_range(0, 10, 1)
var extra_starting_draws: int = 1


func get_starting_extra_draws() -> int:
	return extra_starting_draws
