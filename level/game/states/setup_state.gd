class_name SetupState extends State


func enter() -> void:
	fsm.reset_match()
	fsm.set_state_info("Setup State")

	await get_tree().process_frame

	if fsm.current_state != self:
		return

	fsm.player_hand.setup_deck(
		fsm.level_controller.player_deck
	)
	
	fsm.player_hand.setup_spell_deck(
		fsm.level_controller.player_spell_deck
	)


	fsm.enemy_hand.setup_deck(
		fsm.level_controller.enemy_deck
	)
	
	fsm.enemy_hand.setup_spell_deck(
		fsm.level_controller.enemy_spell_deck
	)

	for _i: int in range(fsm.initial_draw_count):
		fsm.player_hand.draw_card()
		fsm.enemy_hand.draw_card()

	var player_starts: bool = fsm.rng.randi_range(0, 1) == 0

	if player_starts:
		fsm.active_side = GameDecisionEngine.Side.PLAYER
		change_to(fsm.player_start_turn_state)
	else:
		fsm.active_side = GameDecisionEngine.Side.ENEMY
		change_to(fsm.enemy_start_turn_state)
