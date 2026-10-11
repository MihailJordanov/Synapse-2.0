class_name TutorialPlaceFirstCardState
extends TutorialState

var _accepted: bool = false


func enter() -> void:
	_accepted = false
	tutorial.player_card_placed.connect(_on_card_placed)
	tutorial.allow_player_card(tutorial.tutorial_setup.player_first_play_id)


func exit() -> void:
	if tutorial.player_card_placed.is_connected(_on_card_placed):
		tutorial.player_card_placed.disconnect(_on_card_placed)
	super.exit()


func _on_card_placed(card: UnitCard, _slot: CardSlot) -> void:
	if not is_active() or _accepted:
		return
	_accepted = true
	tutorial.first_player_card = card
	if not await wait_seconds(tutorial.tutorial_setup.player_drop_settle_time):
		return
	change_to(tutorial.wait_for_enemy_card_state)
