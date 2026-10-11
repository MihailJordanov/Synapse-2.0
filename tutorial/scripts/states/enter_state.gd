class_name TutorialEnterState
extends TutorialState


func enter() -> void:
	if not tutorial.prepare_match():
		return
	var settings: TutorialSetup = tutorial.tutorial_setup
	if not await _deal_initial_hands():
		return
	if not await wait_for_animation():
		return
	if tutorial.draw_scripted_card(true, settings.player_first_draw_id) == null:
		return
	if not await wait_seconds(settings.draw_settle_time):
		return
	change_to(tutorial.place_first_card_state)


func _deal_initial_hands() -> bool:
	var settings: TutorialSetup = tutorial.tutorial_setup
	var count: int = maxi(
		settings.player_initial_hand_ids.size(), settings.enemy_initial_hand_ids.size()
	)
	for index: int in range(count):
		if index < settings.player_initial_hand_ids.size():
			if tutorial.draw_scripted_card(true, settings.player_initial_hand_ids[index]) == null:
				return false
			if not await wait_seconds(settings.initial_draw_interval):
				return false
		if index < settings.enemy_initial_hand_ids.size():
			if tutorial.draw_scripted_card(false, settings.enemy_initial_hand_ids[index]) == null:
				return false
			if not await wait_seconds(settings.initial_draw_interval):
				return false
	return true
