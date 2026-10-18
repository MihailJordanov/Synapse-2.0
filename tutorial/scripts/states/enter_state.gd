class_name TutorialEnterState
extends TutorialState

var _stage: int = 0


func enter() -> void:
	_stage = 0

	var button := tutorial.overlay.enter_game_button
	button.text = "Hi, Tavi!"
	button.disabled = true
	button.show()
	button.pressed.connect(_on_enter_game_pressed)

	tutorial.overlay.enter_state_text.text = (
		"Hi! I'm Tavi, your adventure buddy.\n"
		+ "Let's learn the ropes together!"
	)

	if not tutorial.prepare_match():
		return

	if not await _deal_initial_hands():
		return

	if not await wait_for_animation():
		return

	_stage = 1
	button.disabled = false


func _on_enter_game_pressed() -> void:
	if not is_active():
		return

	var button := tutorial.overlay.enter_game_button

	if _stage == 1:
		_stage = 0
		button.disabled = true
		button.hide()

		tutorial.overlay.enter_state_text.text = (
			"Your first battle awaits!\n"
			+ "I'll help you make your first cycle."
		)

		if not await wait_seconds(1.0):
			return

		_stage = 2
		button.text = "Let's go!"
		button.disabled = false
		button.show()

	elif _stage == 2:
		_stage = 3
		button.disabled = true
		button.hide()

		var settings: TutorialSetup = tutorial.tutorial_setup

		if tutorial.draw_scripted_card(
			true, settings.player_first_draw_id
		) == null:
			return

		if not await wait_seconds(settings.draw_settle_time):
			return

		change_to(tutorial.place_first_card_state)


func exit() -> void:
	_stage = 0

	var button := tutorial.overlay.enter_game_button
	if button.pressed.is_connected(_on_enter_game_pressed):
		button.pressed.disconnect(_on_enter_game_pressed)

	button.disabled = true
	button.hide()
	super.exit()

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
