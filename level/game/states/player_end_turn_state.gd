class_name PlayerEndTurnState extends State


func enter() -> void:
	_update_state_info()
	fsm.enable_end_turn_button()
	if not fsm.control_button_pressed.is_connected(_on_end_turn_pressed):
		fsm.control_button_pressed.connect(_on_end_turn_pressed)


func exit() -> void:
	fsm.disable_turn_button()
	if fsm.control_button_pressed.is_connected(_on_end_turn_pressed):
		fsm.control_button_pressed.disconnect(_on_end_turn_pressed)
	fsm.reset_end_turn_reason()


func _on_end_turn_pressed() -> void:
	if fsm.current_state != self:
		return

	var terminal: State = fsm.score_terminal_state()
	if terminal != null:
		change_to(terminal)
		return

	change_to(fsm.enemy_start_turn_state)
	
func _update_state_info() -> void:
	match fsm.end_turn_reason:
		GameDecisionEngine.EndTurnReason.NO_EMPTY_SLOTS:
			_show_no_empty_slots_message()

		GameDecisionEngine.EndTurnReason.FORCED_SKIP:
			_show_forced_skip_message()

		_:
			_show_normal_end_turn_message()
			
			
func _show_no_empty_slots_message() -> void:
	fsm.set_state_info(
		"[color=#F88379]No empty slots![/color]\n"
		+ "You cannot play another card.\n"
		+ "Pass the turn to the enemy."
	)

func _show_forced_skip_message() -> void:
	fsm.set_state_info(
		"[color=#ffaa00]No playable cards![/color]\n"
		+ "You must pass the turn."
	)

func _show_normal_end_turn_message() -> void:
	fsm.set_state_info(
		"Player End Turn"
	)
