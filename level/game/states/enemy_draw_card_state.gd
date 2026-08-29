class_name EnemyDrawCardState extends State

const ENEMY_DRAW_CARD = preload("uid://bpuhebv2ydrj8")


func enter() -> void:
	var draw_count: int = 1

	if not fsm.enemy_first_draw_done:
		fsm.enemy_first_draw_done = true

		if fsm.level_controller != null:
			draw_count += fsm.level_controller.get_enemy_starting_extra_draws()

	for i in range(draw_count):
		if fsm.enemy_hand.deck.is_empty():
			break

		Audio.play_spatial_sound(
			ENEMY_DRAW_CARD,
			fsm.player_hand.deck_sprite.global_position,
			false,
			false,
			0.25
		)

		fsm.enemy_hand.draw_card()

	fsm.set_state_info("Enemy Draw Card")

	if not await fsm.wait_seconds(0.3, self):
		return

	change_to(fsm.enemy_play_card_state)
