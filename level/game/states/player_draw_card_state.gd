class_name PlayerDrawCardState extends State

const PLAYER_DRAW_CARD = preload("uid://blgnf83h5i7vb")

func enter() -> void:
	var draw_count: int = 1

	if not fsm.player_first_draw_done:
		fsm.player_first_draw_done = true

		if fsm.level_controller != null:
			draw_count += fsm.level_controller.get_player_starting_extra_draws()

	for i in range(draw_count):
		if fsm.player_hand.deck.is_empty():
			break
		
		Audio.play_spatial_sound(
			PLAYER_DRAW_CARD,
			fsm.player_hand.deck_sprite.global_position,
			false,
			true,
			0.25
		)

		fsm.player_hand.draw_card()

	fsm.set_state_info("Player Draw Card")

	if not await fsm.wait_seconds(0.3, self):
		return

	change_to(fsm.player_play_card_state)
