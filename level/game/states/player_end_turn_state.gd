class_name PlayerEndTurnState extends State


func enter() -> void:
	fsm.set_state_info("Player End Turn")
	fsm.enable_end_turn_button()
	if not fsm.control_button_pressed.is_connected(_on_end_turn_pressed):
		fsm.control_button_pressed.connect(_on_end_turn_pressed)


func exit() -> void:
	fsm.disable_turn_button()
	if fsm.control_button_pressed.is_connected(_on_end_turn_pressed):
		fsm.control_button_pressed.disconnect(_on_end_turn_pressed)


func _on_end_turn_pressed() -> void:
	if fsm.current_state != self:
		return

	var terminal: State = fsm.score_terminal_state()
	if terminal != null:
		change_to(terminal)
		return

	change_to(fsm.enemy_start_turn_state)
