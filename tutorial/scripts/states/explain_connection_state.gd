class_name TutorialExplainConnectionState
extends TutorialState


func enter() -> void:
	if not tutorial.show_connection_preview():
		return
	if not await wait_seconds(tutorial.tutorial_setup.explain_connection_time):
		return
	tutorial.active_side = TutorialController.Side.PLAYER
	if tutorial.draw_scripted_card(true, tutorial.tutorial_setup.player_second_draw_id) == null:
		return
	if not await wait_seconds(tutorial.tutorial_setup.draw_settle_time):
		return
	# The preview visualizer is deliberately NOT cleared at this transition.
	change_to(tutorial.place_closing_card_state)
