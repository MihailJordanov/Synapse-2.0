class_name TaviGuide
extends CanvasLayer

## "Play with Tavi" helper for main_level.
##
## Watches the GameDecisionEngine (state + control button) and never changes game logic.
## - First player turn and first enemy turn: Tavi explains every step.
## - Later: Tavi shows up only when the player is idle and has something to do.
## - Idle while Tavi is around -> a random playable card starts to pulse.
## - Whenever the control button must be pressed -> an arrow points at it and it pulses.

enum Need { NONE, PLAY_CARD, PRESS_BUTTON, SELECT_TARGET }

enum Face { WAVE, POINT, PRESENT, WORRIED, DETERMINED, SAD }

@export_category("Timing")
## Seconds without playing before Tavi helps (and before a card pulses in the first turn).
@export_range(1.0, 60.0, 0.5) var idle_seconds: float = 10.0
## After the first turn: how long an idle hint stays on screen.
@export_range(1.0, 20.0, 0.5) var idle_hint_duration: float = 5.0
## After the first turn: seconds after Tavi appears before a card starts to pulse.
@export_range(0.0, 20.0, 0.5) var pulse_delay_after_hint: float = 3.0

@export_category("Behaviour")
## Point at the control button every time it must be pressed (not only in the first turn).
@export var always_point_at_button: bool = true

@export_category("Card Pulse")
@export var card_pulse_min: float = -0.1
@export var card_pulse_max: float = 0.7
@export_range(0.1, 3.0, 0.05) var card_pulse_duration: float = 0.55

@export_category("Button Pulse")
@export var button_pulse_max: float = 0.55
@export_range(0.1, 3.0, 0.05) var button_pulse_duration: float = 0.6

const BUTTON_MESSAGES: Dictionary = {
	"End Turn": "Nicely done! Press [color=#ffe28a]End Turn[/color] to pass the turn.",
	"Resolve": "A cycle! Press [color=#ffe28a]Resolve[/color] to destroy the linked cards.",
	"Clear Board": "The board is full! Press [color=#ffe28a]Clear Board[/color].",
	"Skip Turn": "No moves left. Press [color=#ffe28a]Skip Turn[/color].",
}

@onready var tavi_root: Control = %TaviRoot
@onready var tavi_sprite: Sprite2D = %TaviSprite
@onready var speech_label: RichTextLabel = %SpeechLabel
@onready var arrow: Sprite2D = %ButtonArrow

var _fsm: GameDecisionEngine = null
var _enabled: bool = false

var _need: Need = Need.NONE
var _need_button_text: String = ""
var _idle_time: float = 0.0
var _idle_hint_shown: bool = false

var _guided_player_turn: bool = false
var _guided_enemy_turn: bool = false
var _enemy_wait_message: String = ""

var _tavi_visible: bool = false
var _tavi_tween: Tween = null
var _tavi_hide_timer: float = -1.0
var _tavi_rest_position: Vector2

var _pulsing_card: Card = null
var _pulsing_card_modulate: Color = Color.WHITE
var _card_tween: Tween = null

var _button: Button = null
var _button_original_modulate: Color = Color.WHITE
var _button_time: float = 0.0
var _arrow_tween: Tween = null
var _arrow_base_position: Vector2


## Called by LevelController. Only stores references, safe before _ready().
func setup(fsm: GameDecisionEngine, is_enabled: bool) -> void:
	_fsm = fsm
	_enabled = is_enabled

	if is_node_ready():
		_apply_enabled()


func _ready() -> void:
	_tavi_rest_position = tavi_root.position
	tavi_root.hide()
	arrow.hide()
	_apply_enabled()


func _apply_enabled() -> void:
	var active: bool = _enabled and _fsm != null
	visible = active
	set_process(active)

	if active and not _fsm.state_changed.is_connected(_on_state_changed):
		_fsm.state_changed.connect(_on_state_changed)


## Called by LevelController on pause/resume. Clears every effect, so nothing stays frozen.
func set_paused(is_paused: bool) -> void:
	if not _enabled:
		return

	visible = not is_paused

	if is_paused:
		_stop_button_hint()
		_stop_card_pulse()
		_need = Need.NONE  # re-evaluated (and hints restarted) on resume


func _exit_tree() -> void:
	_stop_card_pulse()
	_stop_button_hint()


#region /// main loop

func _process(delta: float) -> void:
	if _button == null:
		_button = _fsm.controll_turn_button
		_button_original_modulate = _button.self_modulate

	_update_tavi_timer(delta)

	if _fsm.card_dragger != null and _fsm.card_dragger.card_being_dragged != null:
		_register_activity()
		return

	var need: Need = _compute_need()
	var button_text: String = _button.text if need == Need.PRESS_BUTTON else ""

	if need != _need or button_text != _need_button_text:
		_set_need(need, button_text)

	if _need == Need.NONE:
		return

	_idle_time += delta

	if _need == Need.PRESS_BUTTON:
		_update_button_pulse(delta)

	_update_idle_hints()


func _compute_need() -> Need:
	var state: State = _fsm.current_state

	if state == null or state == _fsm.victory_state or state == _fsm.defeat_state:
		return Need.NONE

	if state == _fsm.select_card_on_board_state:
		return Need.SELECT_TARGET

	var can_play_card: bool = (
		state == _fsm.player_play_card_state
		and _fsm.card_dragger != null
		and _fsm.card_dragger.enabled
		and _fsm.has_any_playable_card(_fsm.player_hand, GameDecisionEngine.Side.PLAYER)
	)

	# Optional "Skip Turn" while cards are still playable -> suggest a card, not the button.
	if can_play_card:
		return Need.PLAY_CARD

	if _button.is_visible_in_tree() and not _button.disabled and not _button.text.is_empty():
		return Need.PRESS_BUTTON

	return Need.NONE


func _set_need(need: Need, button_text: String) -> void:
	_need = need
	_need_button_text = button_text
	_register_activity()
	_stop_button_hint()

	match need:
		Need.PLAY_CARD:
			if _guided_player_turn:
				_show_tavi("Your turn! Drag a card from your hand onto an empty slot on your side.", Face.POINT)
			elif not _guided_enemy_turn:
				_hide_tavi()

		Need.PRESS_BUTTON:
			var is_guided: bool = _guided_player_turn or _guided_enemy_turn

			if is_guided or always_point_at_button:
				_start_button_hint()

			if is_guided:
				_show_tavi(_get_button_message(button_text), Face.PRESENT)
			else:
				_hide_tavi()

		Need.NONE:
			# In guided turns Tavi stays and keeps the last message (no flicker between
			# the short in-between states). The turn change decides when Tavi leaves.
			if _guided_enemy_turn:
				_show_tavi(_enemy_wait_message, Face.WORRIED)
			elif not _guided_player_turn:
				_hide_tavi()


func _update_idle_hints() -> void:
	if _idle_time < idle_seconds:
		return

	var is_guided: bool = _guided_player_turn or _guided_enemy_turn

	if is_guided:
		# Tavi is already talking: after the idle time, show what to do.
		if _need == Need.PLAY_CARD and _pulsing_card == null:
			_start_random_card_pulse()
		return

	if not _idle_hint_shown:
		_idle_hint_shown = true

		match _need:
			Need.PLAY_CARD:
				_show_tavi("Psst! Try playing one of your cards.", Face.POINT, idle_hint_duration)
			Need.PRESS_BUTTON:
				_start_button_hint()
				_show_tavi(_get_button_message(_need_button_text), Face.WAVE, idle_hint_duration)
			Need.SELECT_TARGET:
				_show_tavi("Pick a card on the board for your spell.", Face.POINT, idle_hint_duration)

	if _need == Need.PLAY_CARD and _pulsing_card == null and _idle_time >= idle_seconds + pulse_delay_after_hint:
		_start_random_card_pulse()


func _register_activity() -> void:
	_idle_time = 0.0
	_idle_hint_shown = false
	_stop_card_pulse()


func _on_state_changed(_previous: State, current: State) -> void:
	_register_activity()

	if current == _fsm.player_start_turn_state:
		# state_changed fires before enter(), so the counter still holds the old value.
		_guided_player_turn = _fsm.player_turn_count == 0
		if _guided_enemy_turn:
			_guided_enemy_turn = false
			_hide_tavi()

	elif current == _fsm.enemy_start_turn_state:
		_guided_player_turn = false
		_guided_enemy_turn = _fsm.enemy_turn_count == 0

		if _guided_enemy_turn:
			if _fsm.player_turn_count == 0:
				_enemy_wait_message = "The bad guy goes first this time. Let's wait and watch!"
			else:
				_enemy_wait_message = "Now it's the enemy's turn. Wait and see what they do!"
			_show_tavi(_enemy_wait_message, Face.WORRIED)
		else:
			_hide_tavi()

	elif current == _fsm.select_card_on_board_state and _guided_player_turn:
		_show_tavi("Now pick a card on the board for your spell.", Face.POINT)

	elif current == _fsm.victory_state or current == _fsm.defeat_state:
		_guided_player_turn = false
		_guided_enemy_turn = false
		_hide_tavi()


func _get_button_message(button_text: String) -> String:
	if BUTTON_MESSAGES.has(button_text):
		return BUTTON_MESSAGES[button_text]

	return "Press [color=#ffe28a]%s[/color]!" % button_text

#endregion


#region /// Tavi

## duration < 0 -> stays until hidden by the guide.
func _show_tavi(text: String, face: Face, duration: float = -1.0) -> void:
	speech_label.text = text
	tavi_sprite.frame = face
	_tavi_hide_timer = duration

	if _tavi_visible:
		return

	_tavi_visible = true
	_kill_tween(_tavi_tween)

	tavi_root.show()
	tavi_root.modulate.a = 0.0
	tavi_root.position = _tavi_rest_position + Vector2(-60.0, 0.0)

	_tavi_tween = create_tween().set_parallel()
	_tavi_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tavi_tween.tween_property(tavi_root, "position", _tavi_rest_position, 0.35)
	_tavi_tween.tween_property(tavi_root, "modulate:a", 1.0, 0.25)


func _hide_tavi() -> void:
	_tavi_hide_timer = -1.0

	if not _tavi_visible:
		return

	_tavi_visible = false
	_kill_tween(_tavi_tween)

	_tavi_tween = create_tween().set_parallel()
	_tavi_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tavi_tween.tween_property(tavi_root, "position", _tavi_rest_position + Vector2(-60.0, 0.0), 0.25)
	_tavi_tween.tween_property(tavi_root, "modulate:a", 0.0, 0.25)
	_tavi_tween.chain().tween_callback(tavi_root.hide)


func _update_tavi_timer(delta: float) -> void:
	if _tavi_hide_timer < 0.0:
		return

	_tavi_hide_timer -= delta

	if _tavi_hide_timer <= 0.0:
		_hide_tavi()

#endregion


#region /// card pulse

func _start_random_card_pulse() -> void:
	var playable: Array[Card] = _fsm.get_playable_cards(_fsm.player_hand, GameDecisionEngine.Side.PLAYER)

	if playable.is_empty():
		return

	_stop_card_pulse()

	_pulsing_card = playable.pick_random()
	_pulsing_card_modulate = _pulsing_card.modulate

	_card_tween = create_tween().set_loops()
	_card_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_card_tween.tween_method(_apply_card_brightness, card_pulse_min, card_pulse_max, card_pulse_duration)
	_card_tween.tween_method(_apply_card_brightness, card_pulse_max, card_pulse_min, card_pulse_duration)


func _apply_card_brightness(intensity: float) -> void:
	if not is_instance_valid(_pulsing_card):
		_stop_card_pulse()
		return

	var multiplier: float = pow(2.0, intensity)
	_pulsing_card.modulate = Color(
		_pulsing_card_modulate.r * multiplier,
		_pulsing_card_modulate.g * multiplier,
		_pulsing_card_modulate.b * multiplier,
		_pulsing_card_modulate.a
	)


func _stop_card_pulse() -> void:
	_kill_tween(_card_tween)
	_card_tween = null

	if is_instance_valid(_pulsing_card):
		_pulsing_card.modulate = _pulsing_card_modulate

	_pulsing_card = null

#endregion


#region /// button hint

func _start_button_hint() -> void:
	if _button == null or arrow.visible:
		return

	# Screen-space rect, so it works no matter which canvas layer/camera the button uses.
	var xf: Transform2D = _button.get_global_transform_with_canvas()
	var rect := Rect2(xf.origin, _button.size * xf.get_scale())
	var arrow_half_width: float = arrow.texture.get_width() * arrow.scale.x * 0.5

	_arrow_base_position = Vector2(rect.end.x + arrow_half_width + 8.0, rect.get_center().y)
	arrow.position = _arrow_base_position
	arrow.show()

	_kill_tween(_arrow_tween)
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(arrow, "position:x", _arrow_base_position.x + 14.0, 0.4)
	_arrow_tween.tween_property(arrow, "position:x", _arrow_base_position.x, 0.4)

	_button_time = 0.0


func _update_button_pulse(delta: float) -> void:
	if not arrow.visible:
		return

	_button_time += delta
	var weight: float = 0.5 - 0.5 * cos(TAU * _button_time / (2.0 * maxf(button_pulse_duration, 0.01)))
	var brightness: float = pow(2.0, button_pulse_max * weight)

	_button.self_modulate = Color(
		_button_original_modulate.r * brightness,
		_button_original_modulate.g * brightness,
		_button_original_modulate.b * brightness,
		_button_original_modulate.a
	)


func _stop_button_hint() -> void:
	_kill_tween(_arrow_tween)
	_arrow_tween = null

	if arrow != null:
		arrow.hide()

	if _button != null and is_instance_valid(_button):
		_button.self_modulate = _button_original_modulate

#endregion


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
