class_name SumPointsState extends State

func enter() -> void:
	match fsm.score_policy:
		GameDecisionEngine.ScorePolicy.ACTIVE_SIDE_GETS_ALL:
			fsm.add_score(fsm.active_side, fsm.pending_total_points)
		GameDecisionEngine.ScorePolicy.EACH_OWNER_GETS_OWN:
			fsm.add_score(GameDecisionEngine.Side.PLAYER, fsm.pending_player_owned_points)
			fsm.add_score(GameDecisionEngine.Side.ENEMY, fsm.pending_enemy_owned_points)
	fsm.clear_resolution_context()
	fsm.finish_resolution()
