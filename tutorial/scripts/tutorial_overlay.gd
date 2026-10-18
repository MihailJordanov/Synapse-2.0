class_name TutorialOverlay
extends CanvasLayer

## Each panel is an independent Control and can be placed anywhere in the editor.
@export var state_animation_player: AnimationPlayer
@export_category("Button Glow")
@export_range(0.1, 3.0, 0.05) var button_glow_duration: float = 0.8
@export var button_glow_min: float = -0.2
@export var button_glow_max: float = 0.6

var _button_glow_time: float = 0.0
var _button_original_colors: Dictionary = {}

var first_animation_pass_finished: bool = true
var _animation_name: StringName = &""
var _animation_elapsed: float = 0.0
var _animation_length: float = 0.0
var _glowing_card: CanvasItem = null
var _card_original_modulate: Color = Color.WHITE
var _card_glow_tween: Tween = null

@onready var resolve_button: Button = %ResolveCycleButton
@onready var adventure_button: Button = %StartAdventureButton
@onready var skip_button: Button = %SkipTutorialButton
@onready var your_opponent_play_card_ok_button: Button = %YourOpponentPlayCardOkButton
@onready var matching_symbols_button: Button = %MatchingSymbolsButton
@onready var status_label: Label = %TutorialStatusLabel
@onready var enter_state_text: Label = %EnterStateText
@onready var enter_game_button: Button = %EnterGameButton


func _ready() -> void:
	if state_animation_player == null:
		state_animation_player = $TutorialAnimationPlayer
	_make_animation_libraries_local()
	state_animation_player.animation_finished.connect(_on_animation_finished)
	hide_all_panels()
	resolve_button.hide()
	adventure_button.hide()
	skip_button.hide()
	status_label.hide()
	_button_original_colors[resolve_button] = resolve_button.self_modulate
	_button_original_colors[adventure_button] = adventure_button.self_modulate


func _process(delta: float) -> void:
	_update_button_glow(delta)
	if first_animation_pass_finished or not is_instance_valid(state_animation_player):
		return
	if state_animation_player.current_animation != _animation_name:
		return
	if not state_animation_player.is_playing():
		return
	# animation_finished is NOT emitted for looping animations. Count their first pass.
	_animation_elapsed += delta * absf(state_animation_player.get_playing_speed())
	if _animation_elapsed >= _animation_length:
		first_animation_pass_finished = true


func begin_step(step: TutorialState, reset_animation_name: StringName) -> void:
	stop_card_glow()
	reset_state_animation(reset_animation_name)
	hide_all_panels()
	resolve_button.hide()
	adventure_button.hide()
	status_label.hide()
	var panel: Control = step.hint_panel
	if panel == null:
		panel = get_panel_for_state(step.name)
	if panel != null:
		panel.show()
	var requested_animation: StringName = step.animation_name
	if requested_animation == &"":
		requested_animation = StringName(step.name)
	play_state_animation(requested_animation, step.loop_animation)


func get_panel_for_state(state_name: StringName) -> Control:
	return get_node_or_null("UI/" + String(state_name) + "Panel") as Control


func hide_all_panels() -> void:
	for state_name: String in [
		"EnterState",
		"PlaceFirstCard",
		"WaitForEnemyCard",
		"ExplainConnection",
		"PlaceClosingCard",
		"WatchCycle",
		"FinishTutorial"
	]:
		var panel: Control = get_panel_for_state(StringName(state_name))
		if panel != null:
			panel.hide()


func play_state_animation(animation_name: StringName, loop: bool) -> void:
	first_animation_pass_finished = true
	_animation_name = &""
	_animation_elapsed = 0.0
	if not is_instance_valid(state_animation_player):
		return
	if not state_animation_player.has_animation(animation_name):
		push_warning("TutorialOverlay: missing state animation '%s'." % animation_name)
		return
	var animation: Animation = state_animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_animation_name = animation_name
	_animation_length = animation.length
	first_animation_pass_finished = _animation_length <= 0.0
	state_animation_player.play(animation_name, 0.0)
	state_animation_player.advance(0.0)


func reset_state_animation(animation_name: StringName) -> void:
	first_animation_pass_finished = true
	_animation_name = &""
	if not is_instance_valid(state_animation_player):
		return
	state_animation_player.clear_queue()
	state_animation_player.stop()
	if animation_name != &"" and state_animation_player.has_animation(animation_name):
		state_animation_player.play(animation_name, 0.0)
		state_animation_player.advance(0.0)
		state_animation_player.stop(true)


func start_card_glow(
	card: CanvasItem, intensity_min: float, intensity_max: float, duration: float
) -> void:
	stop_card_glow()
	if not is_instance_valid(card):
		return
	_glowing_card = card
	_card_original_modulate = card.modulate
	_apply_card_intensity(intensity_min)
	_card_glow_tween = create_tween().set_loops()
	_card_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_card_glow_tween.tween_method(
		_apply_card_intensity, intensity_min, intensity_max, maxf(duration, 0.01)
	)
	_card_glow_tween.tween_method(
		_apply_card_intensity, intensity_max, intensity_min, maxf(duration, 0.01)
	)


func _apply_card_intensity(intensity: float) -> void:
	if not is_instance_valid(_glowing_card):
		return
	var multiplier: float = pow(2.0, intensity)
	_glowing_card.modulate = Color(
		_card_original_modulate.r * multiplier,
		_card_original_modulate.g * multiplier,
		_card_original_modulate.b * multiplier,
		_card_original_modulate.a
	)


func stop_card_glow() -> void:
	if _card_glow_tween != null and _card_glow_tween.is_valid():
		_card_glow_tween.kill()
	_card_glow_tween = null
	if is_instance_valid(_glowing_card):
		_glowing_card.modulate = _card_original_modulate
	_glowing_card = null


func show_problem() -> void:
	status_label.text = "Tutorial unavailable."
	status_label.show()


func _make_animation_libraries_local() -> void:
	# Changing a loop flag must not modify resources used by another scene instance.
	for library_name: StringName in state_animation_player.get_animation_library_list():
		var original: AnimationLibrary = state_animation_player.get_animation_library(library_name)
		var local_library: AnimationLibrary = original.duplicate(true) as AnimationLibrary
		state_animation_player.remove_animation_library(library_name)
		state_animation_player.add_animation_library(library_name, local_library)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == _animation_name:
		first_animation_pass_finished = true


func _exit_tree() -> void:
	stop_card_glow()

func _update_button_glow(delta: float) -> void:
	_button_glow_time += delta

	# Един плавен преход нагоре и после обратно.
	var weight := (
		0.5 - 0.5 * cos(
			PI * _button_glow_time / maxf(button_glow_duration, 0.01)
		)
	)
	var intensity := lerpf(button_glow_min, button_glow_max, weight)
	var brightness := pow(2.0, intensity)

	for button: Button in [resolve_button, adventure_button]:
		if not _button_original_colors.has(button):
			continue

		var original: Color = _button_original_colors[button]

		if button.is_visible_in_tree() and not button.disabled:
			button.self_modulate = Color(
				original.r * brightness,
				original.g * brightness,
				original.b * brightness,
				original.a
			)
		else:
			button.self_modulate = original
