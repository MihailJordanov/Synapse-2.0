class_name WitchLegendEffect
extends LegendEffect


@export_range(1, 20, 1)
var trigger_every_turns: int = 3

@export_range(0, 10, 1)
var mana_amount: int = 1


func on_turn_start(fsm: GameDecisionEngine,side: GameDecisionEngine.Side,turn_number: int) -> bool:
	if turn_number % trigger_every_turns != 0:
		return false

	fsm.add_mana(side, mana_amount)

	return true
