class_name TutorialWaitForEnemyCardState
extends TutorialState


func enter() -> void:
	var settings: TutorialSetup = tutorial.tutorial_setup
	tutorial.active_side = TutorialController.Side.ENEMY
	if tutorial.draw_scripted_card(false, settings.enemy_first_draw_id) == null:
		return
	if not await wait_seconds(settings.draw_settle_time + settings.enemy_think_time):
		return
	if not await tutorial.play_scripted_enemy_card(self, visit):
		return
	if not await wait_seconds(settings.enemy_reveal_time):
		return
	change_to(tutorial.explain_connection_state)
