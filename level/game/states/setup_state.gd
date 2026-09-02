class_name SetupState extends State

const PLAYER_DRAW_CARD = preload("uid://blgnf83h5i7vb")
const ENEMY_DRAW_CARD = preload("uid://bpuhebv2ydrj8")

func enter() -> void:
	fsm.reset_match()
	fsm.set_state_info("Setup State")

	await get_tree().process_frame

	if fsm.current_state != self:
		return

	await fsm.level_controller.level_setup.setup_finished

	if fsm.current_state != self:
		return

	fsm.player_hand.setup_deck(fsm.level_controller.player_deck)

	fsm.player_hand.setup_spell_deck(fsm.level_controller.player_spell_deck)

	fsm.enemy_hand.setup_deck(fsm.level_controller.enemy_deck)

	fsm.enemy_hand.setup_spell_deck(fsm.level_controller.enemy_spell_deck)

	for _i: int in range(fsm.initial_draw_count):
		_draw_initial_card(GameDecisionEngine.Side.PLAYER)

		await get_tree().create_timer(0.1).timeout

		_draw_initial_card(GameDecisionEngine.Side.ENEMY)


	var player_starts: bool = fsm.rng.randi_range(0, 1) == 0

	if player_starts:
		fsm.active_side = GameDecisionEngine.Side.PLAYER
		change_to(fsm.player_start_turn_state)
	else:
		fsm.active_side = GameDecisionEngine.Side.ENEMY
		change_to(fsm.enemy_start_turn_state)
		
func _draw_initial_card(side: GameDecisionEngine.Side) -> void:
	match side:
		GameDecisionEngine.Side.PLAYER:
			Audio.play_spatial_sound(
				PLAYER_DRAW_CARD,
				fsm.player_hand.deck_sprite.global_position,
				false,
				true,
				0.25
			)
			fsm.player_hand.draw_card()

		GameDecisionEngine.Side.ENEMY:
			Audio.play_spatial_sound(
				ENEMY_DRAW_CARD,
				fsm.enemy_hand.deck_sprite.global_position,
				false,
				false,
				0.25
			)
			fsm.enemy_hand.draw_card()
