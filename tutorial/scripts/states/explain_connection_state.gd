class_name TutorialExplainConnectionState
extends TutorialState

var _continuing: bool = false


func enter() -> void:
	_continuing = false

	if not tutorial.show_connection_preview():
		return

	var button := tutorial.overlay.matching_symbols_button
	button.disabled = false
	button.show()
	button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	if not is_active() or _continuing:
		return

	_continuing = true
	tutorial.overlay.matching_symbols_button.disabled = true

	tutorial.active_side = TutorialController.Side.PLAYER

	if tutorial.draw_scripted_card(
		true,
		tutorial.tutorial_setup.player_second_draw_id
	) == null:
		return

	if not await wait_seconds(tutorial.tutorial_setup.draw_settle_time):
		return

	change_to(tutorial.place_closing_card_state)


func exit() -> void:
	var button := tutorial.overlay.matching_symbols_button
	if button.pressed.is_connected(_on_continue_pressed):
		button.pressed.disconnect(_on_continue_pressed)

	button.disabled = true
	button.hide()
	super.exit()
