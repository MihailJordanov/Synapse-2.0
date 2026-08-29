class_name CheckForCycleState
extends State


const ENEMY_MAKE_CYCLE: AudioStream = preload("uid://6a5d3dg3nqcl")
const PLAYER_MAKE_CYCLE = preload("uid://b44hvuklnypn")

var _waiting_for_confirmation: bool = false


func enter() -> void:
	fsm.clear_resolution_context()
	fsm.clear_cycle_visualization()

	_waiting_for_confirmation = false

	var cycle_data: CycleData = (fsm.board_controller.find_cycle_data())

	if not cycle_data.is_empty():
		fsm.pending_destroy_ids.assign(cycle_data.card_ids)

		fsm.pending_score_enabled = true

		fsm.show_cycle_visualization(cycle_data)

		_play_cycle_sound()

		fsm.set_state_info(
			"[b][color=#F88379]Cycle detected![/color][/b]\n"
			+ "Destroy linked cards.")

		fsm.set_control_button("Resolve",true)

		_start_waiting_for_confirmation()
		return

	if fsm.is_board_full():
		fsm.pending_destroy_ids.assign(fsm.board_controller.get_all_card_ids())

		fsm.pending_score_enabled = false

		fsm.set_state_info(
			"[b][color=#ffaa00]Board Full![/color][/b]\n"
			+ "Clear all cards.")

		fsm.set_control_button("Clear Board",true)

		_start_waiting_for_confirmation()
		return

	fsm.finish_resolution()


func _play_cycle_sound() -> void:
	var cycle_sound: AudioStream


	if fsm.active_side == GameDecisionEngine.Side.PLAYER:
		cycle_sound = PLAYER_MAKE_CYCLE
	else:
		cycle_sound = ENEMY_MAKE_CYCLE

	Audio.play_spatial_sound(
		cycle_sound,
		Vector2.ZERO,
		false,
		false,
		0.55
	)


func exit() -> void:
	_stop_waiting_for_confirmation()
	fsm.set_control_button("", false)


func _start_waiting_for_confirmation() -> void:
	_waiting_for_confirmation = true

	if not fsm.control_button_pressed.is_connected(_on_control_button_pressed):
		fsm.control_button_pressed.connect(_on_control_button_pressed)


func _stop_waiting_for_confirmation() -> void:
	_waiting_for_confirmation = false

	if fsm.control_button_pressed.is_connected(_on_control_button_pressed):
		fsm.control_button_pressed.disconnect(_on_control_button_pressed)


func _on_control_button_pressed() -> void:
	if not _waiting_for_confirmation:
		return

	if fsm.current_state != self:
		return

	_waiting_for_confirmation = false

	fsm.set_control_button("",false)

	change_to(fsm.destroy_card_state)
