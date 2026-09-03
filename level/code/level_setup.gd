@icon("res://resources/icons/setup.svg")
class_name LevelSetup extends Node

const START_BATTLE_EFFECT = preload("uid://dcw0phtmgbf2g")

signal setup_finished

@export_category("Player Info")
@export var player_name: String

@export_category("Enemy Info")
@export var enemy_name: String

@onready var level_controller: LevelController = %LevelController
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_name_label: RichTextLabel = %PlayerNameLabel
@onready var enemy_name_label: RichTextLabel = %EnemyNameLabel


func _ready() -> void:
	_setup_level()


func _setup_level() -> void:
	#Audio.play_spatial_sound(START_BATTLE_EFFECT, Vector2(800, 450))
	player_name_label.text = player_name
	enemy_name_label.text = enemy_name

	animation_player.play("fade_in")
	await animation_player.animation_finished

	animation_player.play("start_battle")
	await animation_player.animation_finished

	setup_finished.emit()
