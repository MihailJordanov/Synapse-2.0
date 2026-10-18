class_name TutorialWaitForEnemyCardState
extends TutorialState

var _can_continue: bool = false


func enter() -> void:
	_can_continue = false

	var button := tutorial.overlay.your_opponent_play_card_ok_button
	button.disabled = true
	button.show()
	button.pressed.connect(_on_continue_pressed)

	var settings: TutorialSetup = tutorial.tutorial_setup
	tutorial.active_side = TutorialController.Side.ENEMY

	if tutorial.draw_scripted_card(false, settings.enemy_first_draw_id) == null:
		return

	if not await wait_seconds(
		settings.draw_settle_time + settings.enemy_think_time
	):
		return

	if not await tutorial.play_scripted_enemy_card(self, visit):
		return

	if not await wait_seconds(settings.enemy_reveal_time):
		return

	_can_continue = true
	button.disabled = false


func _on_continue_pressed() -> void:
	if not is_active() or not _can_continue:
		return

	_can_continue = false
	tutorial.overlay.your_opponent_play_card_ok_button.disabled = true
	change_to(tutorial.explain_connection_state)


func exit() -> void:
	_can_continue = false

	var button := tutorial.overlay.your_opponent_play_card_ok_button
	if button.pressed.is_connected(_on_continue_pressed):
		button.pressed.disconnect(_on_continue_pressed)

	button.disabled = true
	button.hide()
	super.exit()
