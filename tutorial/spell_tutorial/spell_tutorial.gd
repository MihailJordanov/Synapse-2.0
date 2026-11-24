class_name SpellTutorial
extends Node

## Spell tutorial: a scripted battle on the real main_level, shown once after the first clear of A02.
## Tavi explains mana (from cycles) and spell cards, the player has to play exactly the glowing card.
## Started from VictoryState (should_start()), returns to zone A through the normal victory panel.
##
## Script (both sides need 7 points, all cards are worth 1 point):
##   P1 -> E1 -> P2 = cycle (3 points, mana +1 = 2 own - 1 enemy, a spell is drawn)
##   E2 -> P3 -> E3 (E3 is not linked to anything)
##   spell +1 point on P3 -> P4 closes E2 -> P3 -> P4 = 4 points -> 7 / 7

const SCENE_PATH: String = "res://tutorial/spell_tutorial/spell_tutorial.tscn"
## Shown first: the black card that leads into this tutorial.
const INTRO_SCENE_PATH: String = "res://tutorial/spell_tutorial/spell_reveal.tscn"
const MAIN_LEVEL_PATH: String = "res://level/main_level.tscn"
const RETURN_SCENE_PATH: String = "res://zones/zones_scenes/zone_a.tscn"
const ENEMY_TEXTURE_PATH: String = "res://tutorial/assets/training _dummy_icon.png"
const ENEMY_NAME: String = "Punchy"
## The tutorial starts after this level is beaten.
const TRIGGER_LEVEL_ID: String = "A02"

const WINNING_SCORE: int = 7
const INITIAL_HAND_SIZE: int = 3
const MONEY_REWARD: Vector2i = Vector2i(10, 10)

# A card links to another when one of its target types is one of the other's source types.
# Cycle 1: P1 -> E1 -> P2 -> P1
const P1: int = 11004  # target 2, source 1
const E1: int = 11009  # target 3, source 2
const P2: int = 11002  # target 1, source 3
# Cycle 2: E2 -> P3 -> P4 -> E2
const E2: int = 11014  # target 4, source 3
const P3: int = 11007  # target 2, source 4
const P4: int = 11009  # target 3, source 2
const E3: int = 11000  # target 1, source 1 -> no link to E2 / P3 / P4
const SPELL: int = 21001  # +1 point to a friendly unit, costs 1 mana

## Decks keep this order. Initial hands: the first 3 cards of each deck (drawn in turns).
## Player draws: turn 1 filler, turn 2 P3, turn 3 filler, turn 4 P4.
const PLAYER_UNITS: Array[int] = [P1, P2, 11005, 11010, P3, 11015, P4, 11010]
const PLAYER_SPELLS: Array[int] = [SPELL, SPELL]
## Enemy draws: turn 1 filler, turn 2 E3, turn 3 filler. Fillers are never played.
const ENEMY_UNITS: Array[int] = [E1, E2, 11001, 11003, E3, 11008, 11005]

const GLOW_MIN: float = -0.4
const GLOW_MAX: float = 0.9
const GLOW_DURATION: float = 0.6
## Arrow above a card (card local space) and above a spell's mana cost.
const CARD_ARROW_OFFSET: Vector2 = Vector2(0.0, -150.0)
const SPELL_COST_ARROW_OFFSET: Vector2 = Vector2(0.0, -128.0)

var _level: Node2D
var _controller: LevelController
var _engine: GameDecisionEngine
var _tavi: TaviHelper
var _mana_target: Control
var _points_target: Control

## Bumped on every state change: an older async step stops when it no longer matches.
var _token: int = 0
var _intro_done: bool = false
var _spell_explained: bool = false
var _last_player_mana: int = 0
var _last_spell_deck_size: int = -1

var _glow_card: CanvasItem = null
var _glow_tween: Tween = null
var _glow_original_modulate: Color = Color.WHITE


static func should_start() -> bool:
	return (
		LevelManager.is_level_defeated(TRIGGER_LEVEL_ID)
		and not TutorialManager.is_completed(TutorialManager.SPELL_TUTORIAL_BATTLE)
		and not TutorialManager.is_completed(TutorialManager.SPELL_TUTORIAL)
	)


## After the battle: Tavi in zone A points at the Collection (spells go into the deck there).
## SPELL_TUTORIAL is completed when the player opens the Collection.
static func is_collection_prompt_pending() -> bool:
	return (
		TutorialManager.is_completed(TutorialManager.SPELL_TUTORIAL_BATTLE)
		and not TutorialManager.is_completed(TutorialManager.SPELL_TUTORIAL)
	)


func _ready() -> void:
	_level = (load(MAIN_LEVEL_PATH) as PackedScene).instantiate() as Node2D
	_controller = _level.get_node("LevelController") as LevelController
	_engine = _level.get_node("Game/GameDecisionEngine") as GameDecisionEngine
	_configure_level()
	add_child(_level)

	_engine.state_changed.connect(_on_state_changed)
	_engine.card_dragger.set_tutorial_lock(true, null)

	_tavi = TaviHelper.create(self)
	_mana_target = _create_arrow_target(_engine.player_mana_inform_label)
	_points_target = _create_arrow_target(_engine.player_victory_points_inform_label)


func _process(_delta: float) -> void:
	if _engine == null:
		return

	if _engine.player_mana > _last_player_mana:
		_pop_label(_engine.player_mana_inform_label)

	_last_player_mana = _engine.player_mana
	_update_spell_deck_sprite()


## The spell deck stays visible the whole tutorial and pops when a spell is drawn from it.
func _update_spell_deck_sprite() -> void:
	var hand: Hand = _engine.player_hand
	var sprite: Sprite2D = hand.spell_deck_sprite

	if sprite == null:
		return

	sprite.visible = true

	var size: int = hand.spell_deck.size()

	if _last_spell_deck_size > size:
		_pop_sprite(sprite)

	_last_spell_deck_size = size


func _pop_sprite(sprite: Sprite2D) -> void:
	var base_scale: Vector2 = sprite.get_meta(&"tutorial_base_scale", sprite.scale)
	sprite.set_meta(&"tutorial_base_scale", base_scale)

	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "scale", base_scale * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate", Color(2.0, 2.0, 1.4), 0.12)
	tween.tween_property(sprite, "scale", base_scale, 0.25)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.25)


#region /// setup

func _configure_level() -> void:
	_controller.player_deck = _make_deck(PLAYER_UNITS, PLAYER_SPELLS)
	_controller.enemy_deck = _make_deck(ENEMY_UNITS, [])
	_controller.enemy_name = ENEMY_NAME
	_controller.enemy_icon_texture = load(ENEMY_TEXTURE_PATH) as Texture2D
	_controller.enemy_legend = null
	_controller.use_legends = false
	_controller.is_player_start_first = true
	_controller.player_winning_score = WINNING_SCORE
	_controller.enemy_winning_score = WINNING_SCORE
	_controller.return_scene_path = RETURN_SCENE_PATH
	_controller.money_reward_range = MONEY_REWARD
	_controller.guaranteed_card_rewards.assign([str(SPELL)])
	_controller.level_id = ""
	_controller.analytics_level_name = "SpellTutorial"
	_controller.play_with_tavi = false

	_engine.initial_draw_count = INITIAL_HAND_SIZE
	_engine.shuffle_decks = false
	_engine.player_starting_mana = 0
	_engine.enemy_starting_mana = 0
	_engine.scripted_enemy_unit_ids.assign([E1, E2, E3])

	var player_hand := _level.get_node_or_null("Hands/PlayerHand") as Hand
	if player_hand != null:
		player_hand.debug_draw_with_space = false


func _make_deck(unit_ids: Array[int], spell_ids: Array[int]) -> Deck:
	var deck := Deck.new()
	deck.deck_name = "Spell Tutorial"

	for card_id in unit_ids:
		deck.unit_card_ids.append(str(card_id))

	for card_id in spell_ids:
		deck.spell_card_ids.append(str(card_id))

	return deck


## Invisible rect around an info label + its icon, so the UI arrow sits left of the icon.
func _create_arrow_target(label: Control) -> Control:
	var target := Control.new()
	target.name = "TaviArrowTarget"
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.position = Vector2(12.0, label.position.y)
	target.size = Vector2(label.position.x + label.size.x - 12.0, label.size.y)
	label.get_parent().add_child(target)
	return target

#endregion


#region /// flow

func _on_state_changed(_previous: State, current: State) -> void:
	_token += 1
	var token: int = _token

	_stop_glow()
	_tavi.clear_arrows()
	_engine.card_dragger.set_tutorial_lock(true, null)

	if current == _engine.victory_state:
		TutorialManager.complete(TutorialManager.SPELL_TUTORIAL_BATTLE)

	# state_changed comes before enter(): let the state set itself up first.
	await get_tree().process_frame

	if token != _token:
		return

	if current == _engine.player_play_card_state:
		_on_player_play_card(token)
	elif current == _engine.select_card_on_board_state:
		_on_select_target()
	elif current == _engine.check_for_cycle_state:
		_on_check_for_cycle()
	elif current == _engine.player_end_turn_state:
		_on_player_end_turn(token)
	elif current == _engine.enemy_start_turn_state:
		_tavi.say(TaviLines.SPELL_TUT_ENEMY_TURN, TaviHelper.Face.POINT, true)
	elif current == _engine.victory_state:
		_on_victory(token)


func _on_player_play_card(token: int) -> void:
	match _engine.player_turn_count:
		1:
			if not _intro_done:
				_intro_done = true
				await _tavi.say_and_wait(TaviLines.SPELL_TUT_INTRO, TaviHelper.Face.WAVE, true)

				if token != _token:
					return

			_allow_card(P1, TaviLines.SPELL_TUT_PLAY_FIRST)
		2:
			_allow_card(P2, TaviLines.SPELL_TUT_CLOSE_FIRST_CYCLE)
		3:
			_allow_card(P3, TaviLines.SPELL_TUT_PLAY_THIRD)
		_:
			if _engine.has_player_played_spell_this_turn():
				_allow_card(P4, TaviLines.SPELL_TUT_CLOSE_SECOND_CYCLE)
				return

			_tavi.point_at_control(_points_target, TaviHelper.ArrowSide.LEFT)
			await _tavi.say_and_wait(TaviLines.SPELL_TUT_NOT_ENOUGH, TaviHelper.Face.WORRIED, true)

			if token != _token:
				return

			_tavi.clear_arrows()
			_allow_card(SPELL, TaviLines.SPELL_TUT_PLAY_SPELL)


func _on_select_target() -> void:
	for card: UnitCard in _engine.board_controller.get_all_cards():
		if is_instance_valid(card) and not card.is_enemy_card:
			_start_glow(card)
			_tavi.point_at_world(card, CARD_ARROW_OFFSET, Vector2.DOWN)
			break

	_tavi.say(TaviLines.SPELL_TUT_PICK_TARGET, TaviHelper.Face.POINT, true)


func _on_check_for_cycle() -> void:
	if _engine.active_side != GameDecisionEngine.Side.PLAYER or _engine.pending_destroy_ids.is_empty():
		return

	_tavi.say(TaviLines.SPELL_TUT_RESOLVE, TaviHelper.Face.PRESENT, true)
	_tavi.point_at_control(_engine.controll_turn_button, TaviHelper.ArrowSide.RIGHT)


func _on_player_end_turn(token: int) -> void:
	if _engine.score_terminal_state() != null:
		return  # the last cycle: victory comes next

	if _engine.player_turn_count == 2 and not _spell_explained:
		_spell_explained = true

		if not await _explain_spell(token):
			return

	var text: String = TaviLines.SPELL_TUT_END_TURN_FIRST if _engine.player_turn_count == 1 else TaviLines.SPELL_TUT_END_TURN
	_tavi.say(text, TaviHelper.Face.POINT, true)
	_tavi.point_at_control(_engine.controll_turn_button, TaviHelper.ArrowSide.RIGHT)


## After the first cycle: mana, the drawn spell and its cost. End Turn waits until it is done.
func _explain_spell(token: int) -> bool:
	_engine.disable_turn_button()

	_pop_label(_engine.player_mana_inform_label)
	_tavi.point_at_control(_mana_target, TaviHelper.ArrowSide.LEFT)
	await _tavi.say_and_wait(TaviLines.SPELL_TUT_MANA, TaviHelper.Face.PRESENT, true)

	if token != _token:
		return false

	_tavi.clear_arrows()
	var spell: Card = _find_in_hand(SPELL)

	if spell != null:
		_start_glow(spell)
		_tavi.point_at_world(spell, CARD_ARROW_OFFSET, Vector2.DOWN)

	await _tavi.say_and_wait(TaviLines.SPELL_TUT_SPELL_CARD, TaviHelper.Face.PRESENT, true)

	if token != _token:
		return false

	_stop_glow()

	# Two arrows together: the spell's mana cost and the player's mana.
	if spell != null:
		_tavi.point_at_world(spell, SPELL_COST_ARROW_OFFSET, Vector2.DOWN)

	_tavi.point_at_control(_mana_target, TaviHelper.ArrowSide.LEFT)
	_pop_label(_engine.player_mana_inform_label)
	await _tavi.say_and_wait(TaviLines.SPELL_TUT_SPELL_COST, TaviHelper.Face.POINT, true)

	if token != _token:
		return false

	_tavi.clear_arrows()
	_engine.enable_end_turn_button()
	return true


func _on_victory(token: int) -> void:
	await _tavi.say_and_wait(TaviLines.SPELL_TUT_VICTORY, TaviHelper.Face.WAVE, true)

	if token != _token:
		return

	_tavi.hide_tavi()


## Only this card can be dragged; it glows and Tavi points at it.
func _allow_card(card_id: int, text: String) -> void:
	var card: Card = _find_in_hand(card_id)
	_tavi.say(text, TaviHelper.Face.POINT, true)

	if card == null:
		push_warning("SpellTutorial: card %d is not in the player's hand." % card_id)
		_engine.card_dragger.set_tutorial_lock(false)  # never get stuck
		return

	_engine.card_dragger.set_tutorial_lock(true, card)
	_start_glow(card)
	_tavi.point_at_world(card, CARD_ARROW_OFFSET, Vector2.DOWN)


func _find_in_hand(card_id: int) -> Card:
	for card: Card in _engine.player_hand.cards_in_hand:
		if is_instance_valid(card) and card.card_id == card_id:
			return card

	return null

#endregion


#region /// effects

## Pop-up: the label quickly grows, flashes and goes back.
func _pop_label(label: Control) -> void:
	if label == null:
		return

	label.pivot_offset = label.size * 0.5
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.7, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", Color(2.2, 2.2, 1.2), 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(label, "modulate", Color.WHITE, 0.22)
	tween.tween_property(label, "modulate", Color(2.2, 2.2, 1.2), 0.1)
	tween.tween_property(label, "modulate", Color.WHITE, 0.2)


func _start_glow(card: CanvasItem) -> void:
	_stop_glow()

	if not is_instance_valid(card):
		return

	_glow_card = card
	_glow_original_modulate = card.modulate
	_glow_tween = create_tween().set_loops()
	_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_method(_apply_glow, GLOW_MIN, GLOW_MAX, GLOW_DURATION)
	_glow_tween.tween_method(_apply_glow, GLOW_MAX, GLOW_MIN, GLOW_DURATION)


func _apply_glow(intensity: float) -> void:
	if not is_instance_valid(_glow_card):
		return

	var multiplier: float = pow(2.0, intensity)
	_glow_card.modulate = Color(
		_glow_original_modulate.r * multiplier,
		_glow_original_modulate.g * multiplier,
		_glow_original_modulate.b * multiplier,
		_glow_original_modulate.a
	)


func _stop_glow() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_tween = null

	if is_instance_valid(_glow_card):
		_glow_card.modulate = _glow_original_modulate

	_glow_card = null

#endregion
