@icon("res://resources/icons/setup.svg")
class_name LevelSetup extends Node

signal setup_finished


@export_category("Player Info")
@export var player_name: String = ""
@export var player_icon_texture: Texture2D
@export var is_player_start_first : bool = false

@export_category("Enemy Info")
@export var enemy_name: String = ""
@export var enemy_icon_texture: Texture2D

@export_category("Level Rules")
@export_range(1, 100, 1) var player_winning_score: int = 10
@export_range(1, 100, 1) var enemy_winning_score: int = 10
@export_file("*.tscn") var return_scene_path: String = ""

@export_category("Victory Rewards")
@export var level_id: String = ""
@export var levels_unlocked_on_victory: Array[String] = []
@export var money_reward_range: Vector2i = Vector2i(15, 20)
@export var card_rewards: Array[String] = []


@onready var level_controller: LevelController = %LevelController
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_name_label: RichTextLabel = %PlayerNameLabel
@onready var enemy_name_label: RichTextLabel = %EnemyNameLabel
@onready var player_icon_texture_rect: TextureRect = %PlayerIconTextureRect
@onready var enemy_icon_texture_rect: TextureRect = %EnemyIconTextureRect
@onready var game_decision_engine: GameDecisionEngine = %GameDecisionEngine


func setup_level() -> void:
	game_decision_engine.player_winning_score = player_winning_score
	game_decision_engine.enemy_winning_score = enemy_winning_score

	player_name_label.text = player_name
	enemy_name_label.text = enemy_name
	player_icon_texture_rect.texture = player_icon_texture
	enemy_icon_texture_rect.texture = enemy_icon_texture

	game_decision_engine.update_game_info_labels()

	animation_player.play("fade_in")
	await animation_player.animation_finished

	animation_player.play("start_battle")
	await animation_player.animation_finished

	setup_finished.emit()
		
		
func play_ui_sound( audio: AudioStream, end_offset: float = 0.0 ) -> void:
	Audio.play_ui_audio(audio, end_offset)
