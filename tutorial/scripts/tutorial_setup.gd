class_name TutorialSetup
extends Node

## Full decks include the initial hands AND every scripted draw.
## Duplicate IDs represent separate physical cards.
@export_category("Unit Decks — full decks, including initial hands")
@export var player_card_ids: Array[int] = []
@export var enemy_card_ids: Array[int] = []

@export_category("Initial Hands — drawn from the full decks")
@export var player_initial_hand_ids: Array[int] = []
@export var enemy_initial_hand_ids: Array[int] = []

@export_category("Scripted Draws")
@export var player_first_draw_id: int = -1
@export var enemy_first_draw_id: int = -1
@export var player_second_draw_id: int = -1

@export_category("Scripted Plays")
@export var player_first_play_id: int = -1
@export var enemy_first_play_id: int = -1
@export var player_second_play_id: int = -1

@export_category("Rules")
@export_range(1, 100, 1) var player_winning_score: int = 3
@export_range(1, 100, 1) var enemy_winning_score: int = 3
@export var allow_skip: bool = false
@export_file("*.tscn") var adventure_scene_path: String = ""
@export var adventure_button_text: String = "Begin Your Adventure"

@export_category("Pacing — seconds")
@export_range(0.0, 5.0, 0.01) var initial_draw_interval: float = 0.1
@export_range(0.01, 5.0, 0.01) var draw_settle_time: float = 0.3
@export_range(0.01, 5.0, 0.01) var player_drop_settle_time: float = 0.3
@export_range(0.0, 5.0, 0.01) var enemy_think_time: float = 0.35
@export_range(0.01, 5.0, 0.01) var enemy_play_duration: float = 0.5
@export_range(0.0, 5.0, 0.01) var enemy_reveal_time: float = 0.25
@export_range(0.0, 10.0, 0.01) var explain_connection_time: float = 1.5
@export_range(0.0, 5.0, 0.01) var destroy_card_interval: float = 0.5
@export_range(0.0, 10.0, 0.01) var after_destroy_wait: float = 1.0

@export_category("Card Glow — exposure I, one direction")
@export_range(0.01, 10.0, 0.01) var card_glow_duration: float = 1.0
@export var card_glow_intensity_min: float = -1.0
@export var card_glow_intensity_max: float = 1.0

@export_category("Connection Preview")
@export_range(0.01, 10.0, 0.01) var preview_icon_pulse_duration: float = 1.0
@export var preview_icon_intensity_min: float = -0.5
@export var preview_icon_intensity_max: float = 0.3
@export_range(0.01, 10.0, 0.01) var preview_arrow_pulse_duration: float = 0.8
@export_range(0.0, 1.0, 0.01) var preview_arrow_alpha_min: float = 0.3
@export_range(0.0, 1.0, 0.01) var preview_arrow_alpha_max: float = 0.75

@export_category("State Animations")
@export var default_animation_name: StringName = &"RESET"

@export_category("Optional Header UI")
@export var player_display_name: String = "Player"
@export var enemy_display_name: String = "Training Partner"
@export var player_icon: Texture2D
@export var enemy_icon: Texture2D
@export var player_name_label: RichTextLabel
@export var enemy_name_label: RichTextLabel
@export var player_icon_rect: TextureRect
@export var enemy_icon_rect: TextureRect

@export_category("Optional Sounds — assign the existing audio resources")
@export var player_draw_sound: AudioStream
@export var enemy_draw_sound: AudioStream
@export var placing_card_sound: AudioStream
@export var cycle_sound: AudioStream
@export var explosion_sounds: Array[AudioStream] = []


func apply_header() -> void:
	if player_name_label != null:
		player_name_label.text = player_display_name
	if enemy_name_label != null:
		enemy_name_label.text = enemy_display_name
	if player_icon_rect != null:
		player_icon_rect.texture = player_icon
	if enemy_icon_rect != null:
		enemy_icon_rect.texture = enemy_icon


func get_configuration_errors() -> Array[String]:
	var errors: Array[String] = []
	_validate_draw_sequence(
		player_card_ids,
		player_initial_hand_ids,
		[player_first_draw_id, player_second_draw_id],
		"Player",
		errors
	)
	_validate_draw_sequence(
		enemy_card_ids, enemy_initial_hand_ids, [enemy_first_draw_id], "Enemy", errors
	)

	var player_available: Array[int] = player_initial_hand_ids.duplicate()
	player_available.append(player_first_draw_id)
	_validate_play(player_available, player_first_play_id, "Player first play", errors)
	player_available.append(player_second_draw_id)
	_validate_play(player_available, player_second_play_id, "Player closing play", errors)
	var enemy_available: Array[int] = enemy_initial_hand_ids.duplicate()
	enemy_available.append(enemy_first_draw_id)
	_validate_play(enemy_available, enemy_first_play_id, "Enemy first play", errors)

	if adventure_scene_path.is_empty() or not ResourceLoader.exists(adventure_scene_path):
		errors.append("Assign an existing adventure_scene_path in TutorialSetup.")
	return errors


func _validate_draw_sequence(
	full_deck: Array[int],
	initial_hand: Array[int],
	draws: Array[int],
	side_name: String,
	errors: Array[String]
) -> void:
	var remaining: Array[int] = full_deck.duplicate()
	for card_id: int in full_deck:
		if card_id <= 0:
			errors.append("%s deck contains an invalid ID: %d." % [side_name, card_id])
	for card_id: int in initial_hand + draws:
		var index: int = remaining.find(card_id)
		if card_id <= 0 or index < 0:
			errors.append(
				"%s: deck is missing a copy of scripted draw ID %d." % [side_name, card_id]
			)
		else:
			remaining.remove_at(index)


func _validate_play(
	available: Array[int], card_id: int, play_name: String, errors: Array[String]
) -> void:
	var index: int = available.find(card_id)
	if card_id <= 0 or index < 0:
		errors.append("%s: card ID %d will not be in the hand." % [play_name, card_id])
	else:
		available.remove_at(index)
