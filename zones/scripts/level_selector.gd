class_name LevelSelector
extends Node2D


static var selected_level_selector: LevelSelector = null

signal level_selected(level_selector: LevelSelector)
signal level_deselected(level_selector: LevelSelector)

@export_category("Level Information")
@export var level_id: String = "A01"
@export var enemy_name: String = "New Level"
@export var enemy_name_color: Color = Color.WHITE
@export var enemy_texture: Texture2D
@export var legend: Legend
@export var deck: Deck

@export_category("Level Rules")
@export_range(1, 100, 1) var player_winning_score: int = 10
@export_range(1, 100, 1) var enemy_winning_score: int = 10

@export_category("Victory Rewards")
@export var levels_unlocked_on_victory: Array[String] = []
@export var money_reward_range: Vector2i = Vector2i(15, 20)
@export var card_rewards: Array[String] = []

@onready var level_selector_button: TextureButton = %LevelSelectorButton
@onready var enemy_image_texture_rect: TextureRect = %EnemyImageTextureRect
@onready var is_clear_texture: TextureRect = %IsClearTexture
@onready var shadow_panel: Panel = %ShadowPanel
@onready var exclamation_mark: Node2D = %ExclamationMark
@onready var animation_player: AnimationPlayer = %AnimationPlayer



func _ready() -> void:
	enemy_image_texture_rect.texture = enemy_texture
	shadow_panel.visible = false
	level_selector_button.pressed.connect(_on_level_selector_button_pressed)
	refresh_state()


func refresh_state() -> void:
	var is_unlocked: bool = LevelManager.is_level_unlocked(level_id)
	var is_defeated: bool = LevelManager.is_level_defeated(level_id)

	if not is_unlocked:
		_set_locked_state()
	elif not is_defeated:
		_set_unlocked_state()
	else:
		_set_defeated_state()


func _set_locked_state() -> void:
	level_selector_button.disabled = true
	level_selector_button.modulate = Color("#000000")
	exclamation_mark.visible = false
	is_clear_texture.visible = false
	animation_player.stop()

	if selected_level_selector == self:
		selected_level_selector = null

	shadow_panel.visible = true


func _set_unlocked_state() -> void:
	level_selector_button.disabled = false
	level_selector_button.modulate = Color("#ffffff")
	exclamation_mark.visible = true
	is_clear_texture.visible = false
	shadow_panel.visible = selected_level_selector == self
	animation_player.play("not_clear")


func _set_defeated_state() -> void:
	level_selector_button.disabled = false
	level_selector_button.modulate = Color("#ffffff")
	exclamation_mark.visible = false
	is_clear_texture.visible = true
	shadow_panel.visible = selected_level_selector == self
	animation_player.stop()


func _on_level_selector_button_pressed() -> void:
	_select_level()
	_on_level_selected()
	

func _unhandled_input(event: InputEvent) -> void:
	if selected_level_selector != self:
		return

	var is_pressed: bool = false

	if event is InputEventMouseButton:
		is_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		is_pressed = event.pressed

	if is_pressed:
		_deselect_level()


func _select_level() -> void:
	if selected_level_selector != null and is_instance_valid(selected_level_selector):
		if selected_level_selector != self:
			selected_level_selector._deselect_level()

	selected_level_selector = self
	shadow_panel.visible = true


func _on_level_selected() -> void:
	level_selected.emit(self)

func _deselect_level() -> void:
	if selected_level_selector == self:
		selected_level_selector = null

	shadow_panel.visible = not LevelManager.is_level_unlocked(level_id)
	level_deselected.emit(self)

func _exit_tree() -> void:
	if selected_level_selector == self:
		selected_level_selector = null
