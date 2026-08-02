class_name VictoryState extends State


func enter() -> void:
	fsm.game_finished.emit(true)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	print("Victory!")
