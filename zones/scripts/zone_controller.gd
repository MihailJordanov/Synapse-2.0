class_name ZoneController
extends Node

const MAIN_LEVEL: PackedScene = preload("uid://bfbe0ek8mejsn")

@export var level_selectors: Array[LevelSelector] = []

@onready var play_button: Button = %PlayButton
@onready var enemy_texture: TextureRect = %EnemyTextureRect
@onready var enemy_name_label: RichTextLabel = %EnemyNameRichTextLabel
@onready var reward_info_label: RichTextLabel = %RewardInfoRichTextLabel
@onready var h_box_container: HBoxContainer = %HBoxContainer
@onready var animation_player: AnimationPlayer = %AnimationPlayer

#region /// is card unlocked
@onready var is_card_unlocked_texture_rect_1: TextureRect = %IsCardUnlockedTextureRect1
@onready var is_card_unlocked_texture_rect_2: TextureRect = %IsCardUnlockedTextureRect2
@onready var is_card_unlocked_texture_rect_3: TextureRect = %IsCardUnlockedTextureRect3
@onready var is_card_unlocked_texture_rect_4: TextureRect = %IsCardUnlockedTextureRect4
@onready var is_card_unlocked_texture_rect_5: TextureRect = %IsCardUnlockedTextureRect5

@onready var looked_card_sprite_2d_1: Sprite2D = %LookedCardSprite2D1
@onready var un_looked_card_sprite_2d_1: Sprite2D = %UnLookedCardSprite2D1
@onready var looked_card_sprite_2d_2: Sprite2D = %LookedCardSprite2D2
@onready var un_looked_card_sprite_2d_2: Sprite2D = %UnLookedCardSprite2D2
@onready var looked_card_sprite_2d_3: Sprite2D = %LookedCardSprite2D3
@onready var un_looked_card_sprite_2d_3: Sprite2D = %UnLookedCardSprite2D3
@onready var looked_card_sprite_2d_4: Sprite2D = %LookedCardSprite2D4
@onready var un_looked_card_sprite_2d_4: Sprite2D = %UnLookedCardSprite2D4
@onready var looked_card_sprite_2d_5: Sprite2D = %LookedCardSprite2D5
@onready var un_looked_card_sprite_2d_5: Sprite2D = %UnLookedCardSprite2D5
#endregion

var card_reward_texture_rects: Array[TextureRect] = []
var looked_card_sprites: Array[Sprite2D] = []
var un_looked_card_sprites: Array[Sprite2D] = []

var selected_level_selector: LevelSelector = null


func _ready() -> void:
	card_reward_texture_rects = [
		is_card_unlocked_texture_rect_1,
		is_card_unlocked_texture_rect_2,
		is_card_unlocked_texture_rect_3,
		is_card_unlocked_texture_rect_4,
		is_card_unlocked_texture_rect_5
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

	for level_selector in level_selectors:
		level_selector.level_selected.connect(_on_level_selected)
		level_selector.level_deselected.connect(_on_level_deselected)

	play_button.pressed.connect(_on_play_button_pressed)
	_hide_all_card_rewards()
	
	animation_player.play("fade_in")


func _on_level_selected(level_selector: LevelSelector) -> void:
	selected_level_selector = level_selector

	enemy_texture.texture = level_selector.enemy_texture
	_set_enemy_name(level_selector.enemy_name, level_selector.enemy_name_color)
	_set_reward_info(level_selector.money_reward_range)
	_set_card_rewards(level_selector.card_rewards)

	animation_player.play("unroll_scroll")


func _on_level_deselected(level_selector: LevelSelector) -> void:
	if selected_level_selector != level_selector:
		return

	selected_level_selector = null
	call_deferred("_roll_up_if_no_level_selected")


func _roll_up_if_no_level_selected() -> void:
	if selected_level_selector == null:
		animation_player.play("roll_up_scroll")


func _set_reward_info(money_range: Vector2i) -> void:
	reward_info_label.text = (
		"[color=#f6c453]Reward[/color]\n"
		+ "[color=#fff1c1]"
		+ str(money_range.x)
		+ " - "
		+ str(money_range.y)
		+ " sh.[/color]"
	)


func _set_card_rewards(card_rewards: Array[String]) -> void:
	_hide_all_card_rewards()

	var sorted_card_rewards: Array[String] = card_rewards.duplicate()
	sorted_card_rewards.sort_custom(_sort_card_rewards)

	var visible_rewards_count: int = mini(sorted_card_rewards.size(), card_reward_texture_rects.size())
	h_box_container.visible = visible_rewards_count > 0

	for index in range(visible_rewards_count):
		var card_id_string: String = sorted_card_rewards[index]
		var card_id: int = int(card_id_string)
		var is_unlocked: bool = CardManager.is_card_in_collection(card_id)

		var texture_rect: TextureRect = card_reward_texture_rects[index]
		var looked_sprite: Sprite2D = looked_card_sprites[index]
		var un_looked_sprite: Sprite2D = un_looked_card_sprites[index]

		texture_rect.visible = true

		if not is_unlocked:
			looked_sprite.visible = true
			un_looked_sprite.visible = false
			texture_rect.self_modulate = Color("#777777c9")
		elif card_id_string.begins_with("1"):
			looked_sprite.visible = false
			un_looked_sprite.visible = true
			texture_rect.self_modulate = Color("#f39e00")
		elif card_id_string.begins_with("2"):
			looked_sprite.visible = false
			un_looked_sprite.visible = true
			texture_rect.self_modulate = Color("#f39eff")


func _hide_all_card_rewards() -> void:
	h_box_container.visible = false

	for index in range(card_reward_texture_rects.size()):
		card_reward_texture_rects[index].visible = false
		looked_card_sprites[index].visible = false
		un_looked_card_sprites[index].visible = false


func _on_play_button_pressed() -> void:
	if selected_level_selector == null:
		return

	play_button.disabled = true

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
		get_tree().current_scene.scene_file_path
	)

	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_packed(MAIN_LEVEL)

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
