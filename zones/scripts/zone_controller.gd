class_name ZoneController
extends Node

const MAIN_LEVEL: PackedScene = preload("uid://bfbe0ek8mejsn")
const STAMINA_ICON_PATH: String = "res://00_global/hud/assets/stamina_icon.png"
const MONEY_ICON_PATH: String = "res://00_global/hud/assets/money_icon.png"

@export var level_selectors: Array[LevelSelector] = []
## Only the tutorial zone (zone A) shows the first-zone tutorial and the
## "you lost the first level, try again" Tavi. Leave it off for every other zone.
@export var is_tutorial_zone: bool = false
## This zone's letter ("A", "B"...). Used for the one-time "welcome to the new zone" Tavi.
@export var zone_id: String = ""
## Unlocked once EVERY level of this zone is defeated (e.g. ["B01", "B02"]).
@export var levels_unlocked_on_zone_clear: Array[String] = []
## Zones unlocked once EVERY level of this zone is defeated (e.g. ["B"]). Shows the zone-complete screen.
@export var zones_unlocked_on_zone_clear: Array[String] = []

@onready var play_button: Button = %PlayButton
@onready var zone_menu_buttons: HBoxContainer = %ZoneMenuButtons
@onready var stamina_cost_label: RichTextLabel = %StaminaCostLabel
@onready var enemy_texture: TextureRect = %EnemyTextureRect
@onready var enemy_name_label: RichTextLabel = %EnemyNameRichTextLabel
@onready var reward_info_label: RichTextLabel = %RewardInfoRichTextLabel
@onready var h_box_container: HBoxContainer = %HBoxContainer
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var spell_card_examlpe: SpellCardExample = %SpellCardExamlpe
@onready var unit_card_example: UnitCardExample = %UnitCardExample

#region /// is card unlocked
@onready var texture_progress_bar_1: TextureProgressBar = %TextureProgressBar1
@onready var looked_card_sprite_2d_1: Sprite2D = %LookedCardSprite2D1
@onready var un_looked_card_sprite_2d_1: Sprite2D = %UnLookedCardSprite2D1
@onready var texture_progress_bar_2: TextureProgressBar = %TextureProgressBar2
@onready var looked_card_sprite_2d_2: Sprite2D = %LookedCardSprite2D2
@onready var un_looked_card_sprite_2d_2: Sprite2D = %UnLookedCardSprite2D2
@onready var texture_progress_bar_3: TextureProgressBar = %TextureProgressBar3
@onready var looked_card_sprite_2d_3: Sprite2D = %LookedCardSprite2D3
@onready var un_looked_card_sprite_2d_3: Sprite2D = %UnLookedCardSprite2D3
@onready var texture_progress_bar_4: TextureProgressBar = %TextureProgressBar4
@onready var looked_card_sprite_2d_4: Sprite2D = %LookedCardSprite2D4
@onready var un_looked_card_sprite_2d_4: Sprite2D = %UnLookedCardSprite2D4
@onready var texture_progress_bar_5: TextureProgressBar = %TextureProgressBar5
@onready var looked_card_sprite_2d_5: Sprite2D = %LookedCardSprite2D5
@onready var un_looked_card_sprite_2d_5: Sprite2D = %UnLookedCardSprite2D5
#endregion

var card_reward_progress_bars: Array[TextureProgressBar] = []
var looked_card_sprites: Array[Sprite2D] = []
var un_looked_card_sprites: Array[Sprite2D] = []
var card_reward_ids: Array[int] = []

var selected_level_selector: LevelSelector = null

## Only exists while the first zone tutorial is running.
var _tavi: TaviHelper = null
## True when Tavi is back because the first level was lost (not the first visit).
var _tavi_is_retry: bool = false
## True when Tavi only invites the player to open the newly unlocked Collection.
var _tavi_collection_prompt: bool = false
var _tavi_collection_text: String = TaviLines.ZONE_COLLECTION_UNLOCKED
## The collection prompt after the spell tutorial: opening the Collection completes it.
var _is_spell_collection_prompt: bool = false
var _is_leaving: bool = false


func _ready() -> void:
	# Remember this screen, so the next launch opens it again.
	PlayerDataManager.set_last_location(scene_file_path if not scene_file_path.is_empty() else owner.scene_file_path)
	card_reward_progress_bars = [
		texture_progress_bar_1,
		texture_progress_bar_2,
		texture_progress_bar_3,
		texture_progress_bar_4,
		texture_progress_bar_5
	]

	looked_card_sprites = [
		looked_card_sprite_2d_1,
		looked_card_sprite_2d_2,
		looked_card_sprite_2d_3,
		looked_card_sprite_2d_4,
		looked_card_sprite_2d_5
	]

	un_looked_card_sprites = [
		un_looked_card_sprite_2d_1,
		un_looked_card_sprite_2d_2,
		un_looked_card_sprite_2d_3,
		un_looked_card_sprite_2d_4,
		un_looked_card_sprite_2d_5
	]

	card_reward_ids.resize(card_reward_progress_bars.size())
	card_reward_ids.fill(0)

	# Every LevelSelector in the scene is used, even if it was not added to the exported list.
	# (The list keeps its order first; the first entry is the tutorial's "first level".)
	for node in find_children("*", "Node2D", true, false):
		if node is LevelSelector and not level_selectors.has(node):
			level_selectors.append(node as LevelSelector)

	_update_level_visibility()

	for level_selector in level_selectors:
		level_selector.level_selected.connect(_on_level_selected)
		level_selector.level_deselected.connect(_on_level_deselected)

	for index in range(card_reward_progress_bars.size()):
		var progress_bar: TextureProgressBar = card_reward_progress_bars[index]
		progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		progress_bar.gui_input.connect(_on_card_reward_gui_input.bind(index))
		progress_bar.mouse_exited.connect(_hide_card_preview)

	spell_card_examlpe.visible = false
	unit_card_example.visible = false

	_set_mouse_filter_recursive(spell_card_examlpe)
	_set_mouse_filter_recursive(unit_card_example)

	play_button.pressed.connect(_on_play_button_pressed)

	for child in zone_menu_buttons.get_children():
		var menu_button := child as MapMenuButton

		if menu_button != null:
			menu_button.pressed.connect(_on_zone_menu_button_pressed.bind(menu_button))

	play_button.visibility_changed.connect(_on_play_button_visibility_changed)
	StaminaManager.stamina_changed.connect(_on_stamina_changed)
	StaminaManager.refresh()
	_hide_all_card_rewards()

	animation_player.play("fade_in")

	# First visit, or the first level is still not beaten (lost it) -> Tavi helps.
	var is_first_visit: bool = is_tutorial_zone and not TutorialManager.is_completed(TutorialManager.FIRST_ZONE_TUTORIAL)
	_tavi_is_retry = is_tutorial_zone and not is_first_visit and _is_first_level_unbeaten()

	if is_first_visit or _tavi_is_retry:
		_tavi = TaviHelper.create(self)
		_tavi_show_pick_level()
	elif _should_show_zone_intro():
		_show_zone_intro()
	elif (
		PlayerDataManager.is_feature_unlocked(PlayerDataManager.FEATURE_COLLECTION)
		and not TutorialManager.is_completed(TutorialManager.COLLECTION_TUTORIAL)
	):
		_tavi_collection_prompt = true
		_tavi = TaviHelper.create(self)
		_tavi_show_collection_prompt()
	elif is_tutorial_zone and SpellTutorial.is_collection_prompt_pending():
		_tavi_collection_prompt = true
		_is_spell_collection_prompt = true
		_tavi_collection_text = TaviLines.ZONE_SPELLS_IN_COLLECTION
		_tavi = TaviHelper.create(self)
		_tavi_show_collection_prompt()


func _on_level_selected(level_selector: LevelSelector) -> void:
	selected_level_selector = level_selector

	enemy_texture.texture = level_selector.enemy_texture
	_set_enemy_name(level_selector.enemy_name, level_selector.enemy_name_color)
	_set_reward_info(level_selector.money_reward_range)
	_set_card_rewards(level_selector.card_rewards)
	_update_stamina_cost()

	animation_player.play("unroll_scroll")
	_tavi_on_level_selected(level_selector)


func _on_level_deselected(level_selector: LevelSelector) -> void:
	if selected_level_selector != level_selector:
		return

	selected_level_selector = null
	call_deferred("_roll_up_if_no_level_selected")
	_tavi_show_pick_level()


func _roll_up_if_no_level_selected() -> void:
	if selected_level_selector == null:
		animation_player.play("roll_up_scroll")


func _set_reward_info(money_range: Vector2i) -> void:
	var low: int = mini(money_range.x, money_range.y)
	var high: int = maxi(money_range.x, money_range.y)
	# A fixed reward (e.g. 20 - 20) is shown as a single number.
	var amount_text: String = str(low) if low == high else "%d - %d" % [low, high]

	reward_info_label.text = (
		"[color=#f6c453]Reward[/color]\n"
		+ "[color=#fff1c1]"
		+ amount_text
		+ "[/color] [img=32x32]" + MONEY_ICON_PATH + "[/img]"
	)


func _set_card_rewards(card_rewards: Array[String]) -> void:
	_hide_all_card_rewards()

	var sorted_card_rewards: Array[String] = card_rewards.duplicate()
	sorted_card_rewards.sort_custom(_sort_card_rewards)

	var visible_rewards_count: int = mini(sorted_card_rewards.size(), card_reward_progress_bars.size())
	h_box_container.visible = visible_rewards_count > 0

	for index in range(visible_rewards_count):
		var card_id_string: String = sorted_card_rewards[index]
		var card_id: int = int(card_id_string)
		card_reward_ids[index] = card_id
		var owned_count: int = CardManager.get_card_collection_count(card_id)
		var maximum_count: int = maxi(CardManager.get_max_card_copies_in_collection(card_id), 1)

		var progress_bar: TextureProgressBar = card_reward_progress_bars[index]
		var looked_sprite: Sprite2D = looked_card_sprites[index]
		var un_looked_sprite: Sprite2D = un_looked_card_sprites[index]

		progress_bar.visible = true
		progress_bar.min_value = 0.0
		progress_bar.max_value = float(maximum_count)
		progress_bar.value = float(mini(owned_count, maximum_count))
		progress_bar.tint_under = Color("#777777c9")
		progress_bar.tint_progress = _get_card_progress_color(card_id_string)

		if owned_count == 0:
			looked_sprite.visible = true
			un_looked_sprite.visible = false
		elif owned_count < maximum_count:
			looked_sprite.visible = false
			un_looked_sprite.visible = false
		else:
			looked_sprite.visible = false
			un_looked_sprite.visible = true


func _get_card_progress_color(card_id: String) -> Color:
	if card_id.begins_with("1"):
		return Color("#f39e00")

	if card_id.begins_with("2"):
		return Color("#f39eff")

	return Color.WHITE


func _hide_all_card_rewards() -> void:
	h_box_container.visible = false
	_hide_card_preview()

	for index in range(card_reward_progress_bars.size()):
		card_reward_progress_bars[index].visible = false
		card_reward_progress_bars[index].value = 0.0
		looked_card_sprites[index].visible = false
		un_looked_card_sprites[index].visible = false

		if index < card_reward_ids.size():
			card_reward_ids[index] = 0


func _on_play_button_pressed() -> void:
	if selected_level_selector == null:
		return

	if not StaminaManager.try_spend(selected_level_selector.stamina_cost):
		AnalyticsManager.stamina_not_enough(selected_level_selector.level_id)
		Audio.ui_error()
		_update_stamina_cost()
		return

	play_button.disabled = true

	if _tavi != null:
		TutorialManager.complete(TutorialManager.FIRST_ZONE_TUTORIAL)
		_tavi.clear_arrows()
		_tavi.hide_tavi()

	LevelController.prepare_level(
		selected_level_selector.level_id,
		selected_level_selector.enemy_name,
		selected_level_selector.enemy_texture,
		selected_level_selector.legend,
		selected_level_selector.deck,
		selected_level_selector.player_winning_score,
		selected_level_selector.enemy_winning_score,
		selected_level_selector.levels_unlocked_on_victory,
		selected_level_selector.money_reward_range,
		selected_level_selector.card_rewards,
		get_tree().current_scene.scene_file_path,
		selected_level_selector.play_with_tavi,
		selected_level_selector.features_unlocked_on_victory,
		selected_level_selector.zones_unlocked_on_victory
	)
	LevelController.set_zone_clear_data(
		_get_zone_level_ids(),
		levels_unlocked_on_zone_clear,
		zones_unlocked_on_zone_clear
	)

	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_packed(MAIN_LEVEL)

func _get_zone_level_ids() -> Array[String]:
	var ids: Array[String] = []

	for level_selector in level_selectors:
		if level_selector != null and not level_selector.level_id.is_empty():
			ids.append(level_selector.level_id)

	return ids

#region /// level visibility

## A level is shown when it is unlocked, or when an unlocked level of this zone
## lists it in levels_unlocked_on_victory (a locked "next" level to aim for).
## Example: A01 unlocks A02, A02 unlocks A03+A04 -> at the start only A01 and A02 are shown.
func _update_level_visibility() -> void:
	var teased: Dictionary = {}

	for level_selector in level_selectors:
		if LevelManager.is_level_unlocked(level_selector.level_id):
			for next_id: String in level_selector.levels_unlocked_on_victory:
				teased[next_id.strip_edges().to_upper()] = true

	for level_selector in level_selectors:
		level_selector.visible = (
			LevelManager.is_level_unlocked(level_selector.level_id)
			or teased.has(level_selector.level_id.strip_edges().to_upper())
		)

#endregion


#region /// bottom panel buttons

func _on_zone_menu_button_pressed(menu_button: MapMenuButton) -> void:
	if _is_leaving or menu_button.target_scene_path.is_empty():
		return

	_is_leaving = true
	play_button.disabled = true
	# If this opens the collection, its Exit comes back to this zone.
	Collection.return_scene_path = get_tree().current_scene.scene_file_path

	if _is_spell_collection_prompt and menu_button.name == "CollectionButton":
		TutorialManager.complete(TutorialManager.SPELL_TUTORIAL)

	if _tavi != null:
		_tavi.clear_arrows()
		_tavi.hide_tavi()

	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(menu_button.target_scene_path)

#endregion


#region /// stamina

func _update_stamina_cost() -> void:
	if selected_level_selector == null:
		return

	var cost: int = selected_level_selector.stamina_cost
	var can_afford: bool = StaminaManager.can_afford(cost)
	var color: String = "#fff1c1" if can_afford else "#ff5555"

	stamina_cost_label.text = "[color=%s]%d[/color] [img=32x32]%s[/img]" % [color, cost, STAMINA_ICON_PATH]
	play_button.disabled = not can_afford


func _on_stamina_changed(_current: int, _maximum: int) -> void:
	_update_stamina_cost()


func _on_play_button_visibility_changed() -> void:
	stamina_cost_label.visible = play_button.visible

#endregion


func _sort_card_rewards(first_card_id: String, second_card_id: String) -> bool:
	var first_priority: int = _get_card_reward_priority(first_card_id)
	var second_priority: int = _get_card_reward_priority(second_card_id)

	if first_priority == second_priority:
		return first_card_id < second_card_id

	return first_priority < second_priority


func _get_card_reward_priority(card_id: String) -> int:
	var is_unlocked: bool = CardManager.is_card_in_collection(int(card_id))

	if not is_unlocked:
		return 2

	if card_id.begins_with("1"):
		return 0

	if card_id.begins_with("2"):
		return 1

	return 2
	
func _set_enemy_name(enemy_name: String, enemy_color: Color) -> void:
	enemy_name_label.clear()
	enemy_name_label.push_color(enemy_color)
	enemy_name_label.add_text(enemy_name)
	enemy_name_label.pop()

func _on_card_reward_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			_show_card_preview(index)
		else:
			_hide_card_preview()

	elif event is InputEventScreenTouch:
		if event.pressed:
			_show_card_preview(index)
		else:
			_hide_card_preview()


func _show_card_preview(index: int) -> void:
	_hide_card_preview()

	if index < 0 or index >= card_reward_ids.size():
		return

	var card_id: int = card_reward_ids[index]

	if card_id == 0:
		return

	if CardManager.get_card_collection_count(card_id) <= 0:
		return

	var card_id_string: String = str(card_id)

	if card_id_string.begins_with("1"):
		unit_card_example.card_id = card_id
		unit_card_example.visible = true

	elif card_id_string.begins_with("2"):
		spell_card_examlpe.card_id = card_id
		spell_card_examlpe.visible = true


func _hide_card_preview() -> void:
	unit_card_example.visible = false
	spell_card_examlpe.visible = false


func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_set_mouse_filter_recursive(child)


#region /// first zone tutorial (Tavi)

func _tavi_show_pick_level() -> void:
	if _tavi_collection_prompt:
		_tavi_show_collection_prompt()
		return

	if _tavi == null or level_selectors.is_empty():
		return

	var first_level: LevelSelector = level_selectors[0]

	_tavi.clear_arrows()
	_tavi.say(
		(TaviLines.ZONE_RETRY_PICK_LEVEL if _tavi_is_retry else TaviLines.ZONE_PICK_LEVEL) % first_level.enemy_name,
		TaviHelper.Face.DETERMINED if _tavi_is_retry else TaviHelper.Face.POINT
	)
	# Left of the level icon, pointing right (the red "!" is above it).
	_tavi.point_at_world(first_level, Vector2(-75.0, -5.0), Vector2.RIGHT)


func _tavi_on_level_selected(level_selector: LevelSelector) -> void:
	if _tavi == null:
		return

	if _tavi_collection_prompt:
		_tavi.hide_tavi()  # make room for the level scroll; back when it closes
		return

	_tavi.clear_arrows()
	_tavi.say(
		(TaviLines.ZONE_RETRY_LEVEL_SELECTED if _tavi_is_retry else TaviLines.ZONE_LEVEL_SELECTED) % level_selector.enemy_name,
		TaviHelper.Face.PRESENT
	)
	_tavi.point_at_control(play_button)


## After the Collection unlock: Tavi (top right, the bottom panel holds the buttons) points at it.
func _tavi_show_collection_prompt() -> void:
	var collection_button: Control = zone_menu_buttons.get_node_or_null("CollectionButton") as Control

	_tavi.clear_arrows()
	_tavi.set_layout(Vector2(590.0, 0.0))
	_tavi.say(_tavi_collection_text, TaviHelper.Face.WAVE)

	if collection_button != null:
		_tavi.point_at_control(collection_button, TaviHelper.ArrowSide.RIGHT)


## A newly unlocked zone (not the tutorial zone) is opened for the first time.
func _should_show_zone_intro() -> bool:
	return (
		not is_tutorial_zone
		and not zone_id.is_empty()
		and not TutorialManager.is_completed(TutorialManager.zone_intro_id(zone_id))
	)


## Tavi's last words of the new-zone tutorial; marked done right away, so it never repeats.
func _show_zone_intro() -> void:
	TutorialManager.complete(TutorialManager.zone_intro_id(zone_id))

	_tavi = TaviHelper.create(self)
	await get_tree().create_timer(0.5).timeout  # after the fade in
	await _tavi.say_and_wait(TaviLines.ZONE_ARRIVED, TaviHelper.Face.WAVE)
	_tavi.hide_tavi()


func _is_first_level_unbeaten() -> bool:
	if level_selectors.is_empty():
		return false

	return not LevelManager.is_level_defeated(level_selectors[0].level_id)

#endregion
