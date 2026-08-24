class_name LegendEffect
extends Resource


func get_starting_extra_draws() -> int:
	return 0

func on_turn_start(_fsm: GameDecisionEngine,_side: GameDecisionEngine.Side,_turn_number: int) -> bool:
	return false
