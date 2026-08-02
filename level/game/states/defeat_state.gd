class_name DefeatState extends State


func enter() -> void:
	fsm.game_finished.emit(false)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	print("Defeat!")
