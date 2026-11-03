class_name RewindState
extends State

## FSM state that runs a TurnRewind and then restarts the player's turn.
## Created by TurnRewind at runtime (no scene node needed).

var rewind: TurnRewind


func enter() -> void:
	fsm.set_control_button("", false)
	fsm.card_dragger.set_play_context(false, [])

	await rewind.perform_pending_rewind()

	if fsm.current_state != self:
		return

	# The target snapshot was taken right before player_start_turn_state.enter().
	change_to(fsm.player_start_turn_state)
